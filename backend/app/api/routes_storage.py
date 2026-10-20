import logging
import re
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import OutfitAnalysisRecord, WardrobeItem, TryOnTaskRecord, CommunityListing, CommunityMembership
from app.auth.supabase_auth import get_jwt_verifier, AuthenticatedUser

logger = logging.getLogger("wardrobelens.routes_storage")

router = APIRouter(prefix="/storage", tags=["Protected Media Storage"])

FILENAME_REGEX = re.compile(r"^[a-zA-Z0-9_\-\.]+$")


def _resolve_caller(request: Request) -> Optional[AuthenticatedUser]:
    """
    Extracts and strictly verifies bearer token from Authorization header.
    Query-string tokens are strictly forbidden to prevent token leakage in proxy logs.
    Returns:
      - AuthenticatedUser if valid token is provided.
      - None if NO Authorization header was provided at all (anonymous caller).
    Raises:
      - HTTPException(401) if token is provided but empty, expired, or invalid.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        return None

    parts = auth_header.split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        raw_token = parts[1].strip()
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization header format. Expected 'Bearer <token>'.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not raw_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty token provided.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    verifier = get_jwt_verifier()
    return verifier.verify_token(raw_token)


def _validate_safe_path(subfolder: str, filename: str) -> Path:
    """
    Validates filename format, prevents directory traversal,
    and returns resolved absolute Path strictly within subfolder.
    """
    filename_clean = filename.strip()
    if (
        not FILENAME_REGEX.match(filename_clean)
        or ".." in filename_clean
        or "/" in filename_clean
        or "\\" in filename_clean
    ):
        logger.warning("Rejected suspicious or path-traversal filename: %r", filename)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid filename or path traversal detected.",
        )

    ext = filename_clean.split(".")[-1].lower() if "." in filename_clean else ""
    if ext not in settings.allowed_extensions_list:
        logger.warning("Rejected unsupported image extension: %s", ext)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file extension .{ext}. Allowed: {settings.allowed_extensions_list}",
        )

    base_dir = (settings.storage_path / subfolder).resolve()
    target_path = (base_dir / filename_clean).resolve()

    try:
        is_safe = target_path.is_relative_to(base_dir)
    except AttributeError:
        is_safe = str(target_path).startswith(str(base_dir))

    if not is_safe:
        logger.error("Path traversal attempt detected outside %s: %s", subfolder, target_path)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Path traversal detected.",
        )

    if not target_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Image not found.",
        )

    return target_path


def _stream_image_response(target_path: Path, is_private: bool) -> FileResponse:
    ext = target_path.name.split(".")[-1].lower()
    media_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
    }
    content_type = media_types.get(ext, "application/octet-stream")
    cache_policy = "private, no-cache, no-store, must-revalidate" if is_private else "public, max-age=86400"

    return FileResponse(
        path=str(target_path),
        media_type=content_type,
        headers={
            "Cache-Control": cache_policy,
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.get("/inspirations/{filename}")
async def get_inspiration_image(
    filename: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Secure retrieval for inspiration photos.
    - Path traversal protected.
    - Authenticated records are strictly private to owner.
    - Unowned legacy records remain accessible.
    """
    target_path = _validate_safe_path("inspirations", filename)
    filename_clean = filename.strip()
    rel_path = f"inspirations/{filename_clean}"

    record = db.query(OutfitAnalysisRecord).filter(
        (OutfitAnalysisRecord.image_path == rel_path)
        | (OutfitAnalysisRecord.image_path == filename_clean)
        | (OutfitAnalysisRecord.cloudinary_public_id == rel_path)
    ).first()

    if not record:
        raise HTTPException(status_code=404, detail="Image not found.")

    current_user = _resolve_caller(request)

    if record.user_id is not None:
        if current_user is None or current_user.id != record.user_id:
            logger.info("Denied access to inspiration photo: owner=%s, caller=%s",
                        record.user_id, current_user.id if current_user else "anon")
            raise HTTPException(status_code=404, detail="Image not found.")

    return _stream_image_response(target_path, is_private=(record.user_id is not None))


@router.get("/wardrobe/{filename}")
async def get_wardrobe_image(
    filename: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Secure retrieval for personal wardrobe garment photos.
    - Replaces previous public static mount.
    - Authenticated items are strictly private to owner.
    - Unowned legacy items remain accessible.
    """
    target_path = _validate_safe_path("wardrobe", filename)
    filename_clean = filename.strip()
    rel_path = f"wardrobe/{filename_clean}"

    item = db.query(WardrobeItem).filter(
        (WardrobeItem.image_path == rel_path)
        | (WardrobeItem.image_path == filename_clean)
        | (WardrobeItem.cloudinary_public_id == rel_path)
    ).first()

    if not item:
        raise HTTPException(status_code=404, detail="Image not found.")

    current_user = _resolve_caller(request)

    if item.user_id is not None:
        if current_user is None:
            raise HTTPException(status_code=404, detail="Image not found.")
        if current_user.id != item.user_id:
            # Check if item is actively listed in any community where caller is an approved member
            has_community_access = db.query(CommunityListing).join(
                CommunityMembership,
                CommunityMembership.community_id == CommunityListing.community_id,
            ).filter(
                CommunityListing.wardrobe_item_id == item.id,
                CommunityListing.status == "active",
                CommunityMembership.user_id == current_user.id,
                CommunityMembership.status == "approved",
            ).first() is not None

            if not has_community_access:
                logger.info("Denied access to wardrobe photo: owner=%s, caller=%s",
                            item.user_id, current_user.id)
                raise HTTPException(status_code=404, detail="Image not found.")

    return _stream_image_response(target_path, is_private=(item.user_id is not None))


@router.get("/tryon/{filename}")
async def get_tryon_image(
    filename: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Secure retrieval for virtual try-on input body photos and generated composites.
    - Replaces previous public static mount.
    - Authenticated tasks are strictly private to owner.
    - Unowned legacy tasks remain accessible.
    """
    target_path = _validate_safe_path("tryon", filename)
    filename_clean = filename.strip()
    rel_path = f"tryon/{filename_clean}"

    task = db.query(TryOnTaskRecord).filter(
        (TryOnTaskRecord.user_image_path == rel_path)
        | (TryOnTaskRecord.garment_image_path == rel_path)
        | (TryOnTaskRecord.user_image_path == filename_clean)
        | (TryOnTaskRecord.garment_image_path == filename_clean)
    ).first()

    if not task:
        raise HTTPException(status_code=404, detail="Image not found.")

    current_user = _resolve_caller(request)

    if task.user_id is not None:
        if current_user is None or current_user.id != task.user_id:
            logger.info("Denied access to try-on photo: owner=%s, caller=%s",
                        task.user_id, current_user.id if current_user else "anon")
            raise HTTPException(status_code=404, detail="Image not found.")

    return _stream_image_response(target_path, is_private=True)


@router.get("/extracted/{filename}")
async def get_extracted_garment_image(
    filename: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Secure retrieval for isolated/cropped garment photos.
    - Path traversal protected.
    - Authenticated garments are strictly private to owner or approved community members.
    - Unowned legacy items or analysis records remain accessible.
    """
    target_path = _validate_safe_path("extracted", filename)
    filename_clean = filename.strip()
    rel_path = f"extracted/{filename_clean}"

    current_user = _resolve_caller(request)

    # 1. Check if saved as a WardrobeItem
    item = db.query(WardrobeItem).filter(
        (WardrobeItem.image_path == rel_path)
        | (WardrobeItem.image_path == filename_clean)
        | (WardrobeItem.cloudinary_public_id == rel_path)
    ).first()

    if item:
        if item.user_id is not None:
            if current_user is None:
                raise HTTPException(status_code=404, detail="Image not found.")
            if current_user.id != item.user_id:
                # Check active community listing membership
                has_community_access = db.query(CommunityListing).join(
                    CommunityMembership,
                    CommunityMembership.community_id == CommunityListing.community_id,
                ).filter(
                    CommunityListing.wardrobe_item_id == item.id,
                    CommunityListing.status == "active",
                    CommunityMembership.user_id == current_user.id,
                    CommunityMembership.status == "approved",
                ).first() is not None

                if not has_community_access:
                    logger.info("Denied access to extracted wardrobe photo: owner=%s, caller=%s",
                                item.user_id, current_user.id)
                    raise HTTPException(status_code=404, detail="Image not found.")

        return _stream_image_response(target_path, is_private=(item.user_id is not None))

    # 2. Check if part of an uncommitted OutfitAnalysisRecord
    analysis_record = db.query(OutfitAnalysisRecord).filter(
        OutfitAnalysisRecord.items_json.like(f"%{filename_clean}%")
    ).first()

    if not analysis_record:
        raise HTTPException(status_code=404, detail="Image not found.")

    if analysis_record.user_id is not None:
        if current_user is None or current_user.id != analysis_record.user_id:
            logger.info("Denied access to uncommitted extracted photo: owner=%s, caller=%s",
                        analysis_record.user_id, current_user.id if current_user else "anon")
            raise HTTPException(status_code=404, detail="Image not found.")

    return _stream_image_response(target_path, is_private=(analysis_record.user_id is not None))
