import base64
import io
import json
import logging
import urllib.parse
from datetime import datetime, timedelta
from typing import Optional, Tuple
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from PIL import Image
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session
import httpx

from app.config import settings
from app.database import get_db
from app.models import TryOnTaskRecord, WardrobeItem, UserTryOnModel, OutfitAnalysisRecord
from app.schemas import TryOnTaskResponse, TryOnHistoryResponse, UserTryOnModelResponse
from app.services.image_storage import image_storage_service
from app.services.tryon_provider import (
    get_tryon_provider,
    normalize_garment_category,
    VALID_GARMENT_CATEGORIES,
)
from app.auth.supabase_auth import get_optional_current_user, get_current_user, AuthenticatedUser

logger = logging.getLogger("wardrobelens.routes_tryon")

router = APIRouter(prefix="/api/tryon", tags=["Virtual Try-On"])


def _task_to_response(task: TryOnTaskRecord) -> TryOnTaskResponse:
    if getattr(task, "storage_provider", "local") == "cloudinary" and getattr(task, "user_image_public_id", None):
        user_image_url = image_storage_service.generate_delivery_url(
            task.user_image_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    else:
        clean_user_path = (task.user_image_path or "").lstrip("/")
        user_image_url = f"/storage/{clean_user_path}"

    if getattr(task, "storage_provider", "local") == "cloudinary" and getattr(task, "garment_image_public_id", None):
        garment_image_url = image_storage_service.generate_delivery_url(
            task.garment_image_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    else:
        clean_garment_path = (task.garment_image_path or "").lstrip("/")
        garment_image_url = f"/storage/{clean_garment_path}"

    result_url = task.result_image_url
    if getattr(task, "result_image_public_id", None):
        if getattr(task, "storage_provider", "local") == "cloudinary":
            result_url = image_storage_service.generate_delivery_url(
                task.result_image_public_id,
                storage_provider="cloudinary",
                ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
            )
        else:
            clean_res_path = task.result_image_public_id.lstrip("/")
            result_url = f"/storage/{clean_res_path}"

    # Retries require non-expired task and valid input assets
    now = datetime.utcnow()
    is_not_expired = task.expires_at is None or task.expires_at > now
    has_user_input = bool(task.user_image_public_id or task.user_image_path)
    has_garment_input = bool(task.garment_image_public_id or task.garment_image_path)
    can_retry = is_not_expired and has_user_input and has_garment_input

    return TryOnTaskResponse(
        task_id=task.id,
        status=task.status,
        provider=task.provider,
        user_image_url=user_image_url,
        garment_image_url=garment_image_url,
        result_image_url=result_url,
        error_message=task.error_message,
        created_at=task.created_at,
        updated_at=task.updated_at,
        expires_at=task.expires_at,
        can_retry=can_retry,
        is_friend_tryon=bool(getattr(task, "is_friend_tryon", False)),
        used_saved_model=bool(getattr(task, "used_saved_model", False)),
        inspiration_analysis_id=getattr(task, "inspiration_analysis_id", None),
    )


def _model_to_response(model: Optional[UserTryOnModel]) -> UserTryOnModelResponse:
    if not model:
        return UserTryOnModelResponse(has_model=False)

    if model.storage_provider == "cloudinary" and model.cloudinary_public_id:
        img_url = image_storage_service.generate_delivery_url(
            model.cloudinary_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    else:
        clean_path = (model.image_path or "").lstrip("/")
        img_url = f"/storage/{clean_path}"

    return UserTryOnModelResponse(
        has_model=True,
        model_id=model.id,
        image_url=img_url,
        storage_provider=model.storage_provider,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _encode_cursor(created_at: datetime, task_id: str) -> str:
    payload = f"{created_at.isoformat()}|{task_id}"
    return base64.urlsafe_b64encode(payload.encode("utf-8")).decode("utf-8")


def _decode_cursor(cursor_str: str) -> Tuple[datetime, str]:
    try:
        decoded = base64.urlsafe_b64decode(cursor_str.encode("utf-8")).decode("utf-8")
        dt_str, task_id = decoded.split("|", 1)
        dt = datetime.fromisoformat(dt_str)
        return dt, task_id
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid pagination cursor format.",
        )


def cleanup_expired_tryon_tasks(db: Session) -> int:
    """
    Idempotent cleanup of try-on assets exceeding the retention threshold (7 days).
    Deletes both Cloudinary assets and local files for expired tasks.
    Does NOT touch legacy records lacking an expires_at timestamp.
    """
    now = datetime.utcnow()
    expired_tasks = db.query(TryOnTaskRecord).filter(
        TryOnTaskRecord.expires_at.is_not(None),
        TryOnTaskRecord.expires_at <= now,
    ).all()

    cleaned_count = 0
    for task in expired_tasks:
        try:
            # Delete user image unless it is a saved default model
            user_asset = task.user_image_public_id or task.user_image_path
            if user_asset and not getattr(task, "used_saved_model", False):
                is_default = (
                    db.query(UserTryOnModel)
                    .filter(
                        or_(
                            UserTryOnModel.cloudinary_public_id == user_asset,
                            UserTryOnModel.image_path == user_asset,
                        )
                    )
                    .first()
                    is not None
                )
                if not is_default:
                    image_storage_service.delete(user_asset, storage_provider=task.storage_provider)

            # Delete garment image if it was uploaded specifically for tryon (not a shared wardrobe item or inspiration)
            if task.garment_image_path and "wardrobe/" not in task.garment_image_path and "inspirations/" not in task.garment_image_path:
                is_analysis_asset = db.query(OutfitAnalysisRecord).filter(
                    or_(
                        OutfitAnalysisRecord.image_path == task.garment_image_path,
                        OutfitAnalysisRecord.cloudinary_public_id == task.garment_image_path,
                        OutfitAnalysisRecord.items_json.like(f"%{task.garment_image_path}%"),
                    )
                ).first() is not None
                if not is_analysis_asset:
                    garment_asset = task.garment_image_public_id or task.garment_image_path
                    if garment_asset:
                        image_storage_service.delete(garment_asset, storage_provider=task.storage_provider)

            if task.result_image_public_id:
                image_storage_service.delete(task.result_image_public_id, storage_provider=task.storage_provider)

            db.delete(task)
            cleaned_count += 1
        except Exception as e:
            logger.error("Failed to clean up expired try-on task %s: %s", task.id, str(e))

    db.commit()
    logger.info("Try-on retention cleanup: removed %d expired tasks", cleaned_count)
    return cleaned_count


@router.get("/model", response_model=UserTryOnModelResponse)
def get_user_tryon_model(
    db: Session = Depends(get_db),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Retrieve the current user's saved default try-on model.
    Returns has_model=False if no model is currently saved.
    """
    model = db.query(UserTryOnModel).filter(UserTryOnModel.user_id == current_user.id).first()
    return _model_to_response(model)


@router.post("/model", response_model=UserTryOnModelResponse, status_code=status.HTTP_201_CREATED)
async def save_or_update_tryon_model(
    image: UploadFile = File(..., description="Silhouette photo to use as default try-on model"),
    db: Session = Depends(get_db),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Save or replace the authenticated user's default try-on model.
    - Sanitizes and enforces >= 128x128 dimensions.
    - Stored privately under subfolder 'models'.
    - Safely replaces existing model without deleting active task assets.
    """
    raw = await image.read()
    clean_bytes, ext, w, h = image_storage_service.validate_and_sanitize_image(image, raw)
    if w < 128 or h < 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Model photo must be at least 128x128 pixels.",
        )

    existing = db.query(UserTryOnModel).filter(UserTryOnModel.user_id == current_user.id).first()
    old_asset = None
    old_provider = None
    if existing:
        old_asset = existing.cloudinary_public_id or existing.image_path
        old_provider = existing.storage_provider

    meta = await image_storage_service.upload(
        user_id=current_user.id,
        subfolder="models",
        pre_sanitized=(clean_bytes, ext, w, h),
    )

    if existing:
        existing.image_path = meta.public_id
        existing.storage_provider = meta.storage_provider
        existing.cloudinary_public_id = meta.public_id if meta.storage_provider == "cloudinary" else None
        existing.image_format = ext
        existing.updated_at = datetime.utcnow()
        model_record = existing
    else:
        model_record = UserTryOnModel(
            user_id=current_user.id,
            image_path=meta.public_id,
            storage_provider=meta.storage_provider,
            cloudinary_public_id=meta.public_id if meta.storage_provider == "cloudinary" else None,
            image_format=ext,
        )
        db.add(model_record)

    db.commit()
    db.refresh(model_record)

    # Safely delete previous asset ONLY if not referenced by any existing task
    if old_asset and old_asset != meta.public_id:
        existing_ref = db.query(TryOnTaskRecord).filter(
            or_(
                TryOnTaskRecord.user_image_public_id == old_asset,
                TryOnTaskRecord.user_image_path == old_asset,
            ),
        ).first()
        if not existing_ref:
            try:
                image_storage_service.delete(old_asset, storage_provider=old_provider or "local")
            except Exception as e:
                logger.warning("Could not delete old model asset %s: %s", old_asset, str(e))

    return _model_to_response(model_record)


@router.delete("/model", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_tryon_model(
    db: Session = Depends(get_db),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Permanently remove the user's saved default try-on model.
    """
    existing = db.query(UserTryOnModel).filter(UserTryOnModel.user_id == current_user.id).first()
    if not existing:
        return None

    asset_id = existing.cloudinary_public_id or existing.image_path
    provider = existing.storage_provider

    db.delete(existing)
    db.commit()

    if asset_id:
        existing_ref = db.query(TryOnTaskRecord).filter(
            or_(
                TryOnTaskRecord.user_image_public_id == asset_id,
                TryOnTaskRecord.user_image_path == asset_id,
            ),
        ).first()
        if not existing_ref:
            try:
                image_storage_service.delete(asset_id, storage_provider=provider)
            except Exception as e:
                logger.warning("Failed to delete removed model asset %s: %s", asset_id, str(e))

    return None


@router.post("/tasks", response_model=TryOnTaskResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_tryon_task(
    user_image: Optional[UploadFile] = File(None, description="Full or half-body photo of the user"),
    garment_image: Optional[UploadFile] = File(None, description="Garment or inspiration outfit photo"),
    wardrobe_item_id: Optional[str] = Form(None, description="Or select an item already in digital wardrobe"),
    garment_category: str = Form("upper body", description="Garment type: upper body, lower body, full body, dress, outer, shoes, auto"),
    use_saved_model: bool = Form(False, description="Use user's saved default try-on model"),
    is_friend_tryon: bool = Form(False, description="Flag indicating one-off try-on for a friend"),
    friend_consent_acknowledged: bool = Form(False, description="User acknowledges consent to use friend photo"),
    save_as_default_model: bool = Form(False, description="Optionally save uploaded user_image as default model"),
    inspiration_analysis_id: Optional[str] = Form(None, description="Existing outfit analysis record ID to reuse as inspiration"),
    inspiration_item_id: Optional[str] = Form(None, description="ID of a specific detected garment within the analysis"),
    inspiration_image_url: Optional[str] = Form(None, description="Direct URL of the inspiration image or crop"),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    user_id = current_user.id if current_user else None

    # Validate garment_category against known allowlist
    clean_cat = (garment_category or "").strip().lower()
    if clean_cat not in VALID_GARMENT_CATEGORIES and clean_cat not in ["top", "tops", "bottom", "bottoms", "outerwear", "jacket", "auto", ""]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid garment_category '{garment_category}'. Allowed: {sorted(list(VALID_GARMENT_CATEGORIES))}",
        )
    norm_category = normalize_garment_category(clean_cat) if clean_cat and clean_cat != "auto" else "upper_body"

    # 1. Resolve and prepare user image bytes
    used_model = False
    is_friend = bool(is_friend_tryon)

    if is_friend:
        if not user_image:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A person photo is required for a friend try-on.",
            )
        if not friend_consent_acknowledged:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Consent acknowledgement is required to perform a virtual fitting with a friend's photo.",
            )
        user_raw = await user_image.read()
        user_clean_bytes, user_ext, u_w, u_h = image_storage_service.validate_and_sanitize_image(user_image, user_raw)
        if u_w < 128 or u_h < 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Friend photo must be at least 128x128 pixels.",
            )
        user_meta = await image_storage_service.upload(
            user_id=user_id,
            subfolder="tryon",
            pre_sanitized=(user_clean_bytes, user_ext, u_w, u_h),
        )
    elif use_saved_model or user_image is None:
        if not current_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication is required to use a saved try-on model.",
            )
        saved_model = db.query(UserTryOnModel).filter(UserTryOnModel.user_id == current_user.id).first()
        if not saved_model:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No saved default try-on model found. Please upload a person photo.",
            )
        try:
            user_clean_bytes = await image_storage_service.get_image_bytes(
                saved_model.cloudinary_public_id or saved_model.image_path,
                storage_provider=saved_model.storage_provider,
            )
        except Exception as e:
            logger.error("Failed to load saved model bytes for user %s: %s", current_user.id, str(e))
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Saved default model photo could not be loaded.",
            )
        user_ext = saved_model.image_format or "jpg"
        from app.services.image_storage import ImageMetadata
        user_meta = ImageMetadata(
            public_id=saved_model.cloudinary_public_id or saved_model.image_path,
            storage_provider=saved_model.storage_provider,
            format=user_ext,
            bytes_size=len(user_clean_bytes),
        )
        used_model = True
    else:
        user_raw = await user_image.read()
        user_clean_bytes, user_ext, u_w, u_h = image_storage_service.validate_and_sanitize_image(user_image, user_raw)
        if u_w < 128 or u_h < 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User photo must be at least 128x128 pixels.",
            )
        user_meta = await image_storage_service.upload(
            user_id=user_id,
            subfolder="tryon",
            pre_sanitized=(user_clean_bytes, user_ext, u_w, u_h),
        )
        if save_as_default_model and current_user:
            try:
                m_meta = await image_storage_service.upload(
                    user_id=current_user.id,
                    subfolder="models",
                    pre_sanitized=(user_clean_bytes, user_ext, u_w, u_h),
                )
                existing_m = db.query(UserTryOnModel).filter(UserTryOnModel.user_id == current_user.id).first()
                if existing_m:
                    existing_m.image_path = m_meta.public_id
                    existing_m.storage_provider = m_meta.storage_provider
                    existing_m.cloudinary_public_id = m_meta.public_id if m_meta.storage_provider == "cloudinary" else None
                    existing_m.image_format = user_ext
                    existing_m.updated_at = datetime.utcnow()
                else:
                    new_m = UserTryOnModel(
                        user_id=current_user.id,
                        image_path=m_meta.public_id,
                        storage_provider=m_meta.storage_provider,
                        cloudinary_public_id=m_meta.public_id if m_meta.storage_provider == "cloudinary" else None,
                        image_format=user_ext,
                    )
                    db.add(new_m)
            except Exception as e:
                logger.warning("Could not automatically save default model: %s", str(e))

    # 2. Determine and prepare garment image
    garment_meta = None
    garment_rel = None
    garment_clean_bytes = None
    garment_item = None
    garment_pub_id = None

    if garment_image:
        garment_raw = await garment_image.read()
        garment_clean_bytes, garment_ext, g_w, g_h = image_storage_service.validate_and_sanitize_image(garment_image, garment_raw)
        if g_w < 128 or g_h < 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Garment image must be at least 128x128 pixels.",
            )
        garment_meta = await image_storage_service.upload(
            user_id=user_id,
            subfolder="tryon",
            pre_sanitized=(garment_clean_bytes, garment_ext, g_w, g_h),
        )
        garment_rel = garment_meta.public_id
        if garment_meta.storage_provider == "cloudinary":
            garment_pub_id = garment_meta.public_id
    elif wardrobe_item_id:
        garment_item = db.query(WardrobeItem).filter(WardrobeItem.id == wardrobe_item_id).first()
        if not garment_item:
            raise HTTPException(status_code=404, detail="Selected wardrobe item not found.")

        # Ensure ownership of the wardrobe item
        if garment_item.user_id is not None:
            if current_user is None or current_user.id != garment_item.user_id:
                raise HTTPException(status_code=404, detail="Selected wardrobe item not found.")

        garment_rel = garment_item.image_path
        if getattr(garment_item, "storage_provider", None) == "cloudinary":
            garment_pub_id = garment_item.cloudinary_public_id
        # Retrieve garment bytes safely from local disk or Cloudinary
        try:
            garment_clean_bytes = await image_storage_service.get_image_bytes(
                garment_item.cloudinary_public_id or garment_item.image_path,
                storage_provider=garment_item.storage_provider,
            )
        except Exception as e:
            logger.error("Failed to read garment bytes for item %s: %s", wardrobe_item_id, str(e))
            raise HTTPException(status_code=404, detail="Selected wardrobe item image could not be loaded.")
    elif inspiration_analysis_id:
        analysis = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == inspiration_analysis_id).first()
        if not analysis:
            raise HTTPException(status_code=404, detail="Attached inspiration analysis not found.")

        if analysis.user_id is not None:
            if current_user is None or current_user.id != analysis.user_id:
                raise HTTPException(status_code=404, detail="Attached inspiration analysis not found.")

        target_path = None
        target_category = None
        if inspiration_item_id:
            try:
                raw_items = json.loads(analysis.items_json) if analysis.items_json else []
                for it in raw_items:
                    if str(it.get("id")) == str(inspiration_item_id):
                        target_path = it.get("extracted_image_path")
                        target_category = it.get("category")
                        break
            except Exception as e:
                logger.warning("Could not parse items_json for analysis %s: %s", inspiration_analysis_id, e)

        # Fallback to analysis full image if no crop or piece not found
        if not target_path:
            target_path = analysis.cloudinary_public_id or analysis.image_path

        garment_rel = target_path
        if analysis.storage_provider == "cloudinary":
            garment_pub_id = target_path

        try:
            garment_clean_bytes = await image_storage_service.get_image_bytes(
                target_path,
                storage_provider=analysis.storage_provider,
            )
        except Exception as e:
            logger.error("Failed to load inspiration bytes for %s: %s", target_path, str(e))
            raise HTTPException(status_code=404, detail="Inspiration asset image could not be loaded.")

        if target_category and clean_cat in ("", "auto", "upper body"):
            norm_category = normalize_garment_category(target_category)
    elif inspiration_image_url:
        if inspiration_image_url.startswith("/storage/"):
            rel = inspiration_image_url.replace("/storage/", "").lstrip("/")
            garment_rel = rel
            garment_clean_bytes = await image_storage_service.get_image_bytes(rel, storage_provider="local")
        else:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.get(inspiration_image_url)
                resp.raise_for_status()
                garment_clean_bytes = resp.content
            # Re-verify image
            with Image.open(io.BytesIO(garment_clean_bytes)) as img:
                img.verify()
            g_meta = await image_storage_service.upload(
                user_id=user_id,
                subfolder="tryon",
                pre_sanitized=(garment_clean_bytes, "jpg", 256, 256),
            )
            garment_rel = g_meta.public_id
            garment_meta = g_meta
            if g_meta.storage_provider == "cloudinary":
                garment_pub_id = g_meta.public_id
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either a garment image file, a wardrobe_item_id, or an attached inspiration must be provided.",
        )

    # 3. Call tryon provider passing in-memory clean bytes
    provider = get_tryon_provider()
    user_fn = f"user_{user_meta.public_id.split('/')[-1]}.{user_ext}"
    garment_fn = f"garment_{garment_rel.split('/')[-1]}.jpg"

    try:
        task_info = await provider.create_tryon_task(
            user_image_bytes=user_clean_bytes,
            garment_image_bytes=garment_clean_bytes,
            user_filename=user_fn,
            garment_filename=garment_fn,
            garment_category=norm_category,
        )
    except Exception as e:
        logger.error("Try-on service provider failed: %s", str(e), exc_info=True)
        if not used_model:
            image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
        if garment_meta:
            image_storage_service.delete(garment_meta.public_id, storage_provider=garment_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Try-On service initiation failed. Please try again.",
        )

    # 4. Save record with 7-day retention expiry
    expires_at = datetime.utcnow() + timedelta(days=settings.TRYON_RETENTION_DAYS)
    if garment_meta and garment_meta.storage_provider == "cloudinary":
        garment_pub_id = garment_meta.public_id
    elif garment_item and getattr(garment_item, "storage_provider", None) == "cloudinary":
        garment_pub_id = garment_item.cloudinary_public_id

    task_record = TryOnTaskRecord(
        user_id=user_id,
        provider=task_info.get("provider", "mock"),
        external_task_id=task_info.get("task_id"),
        status=task_info.get("status", "processing"),
        user_image_path=user_meta.public_id,
        garment_image_path=garment_rel,
        storage_provider=user_meta.storage_provider,
        user_image_public_id=user_meta.public_id if user_meta.storage_provider == "cloudinary" else None,
        garment_image_public_id=garment_pub_id,
        is_friend_tryon=is_friend,
        used_saved_model=used_model,
        inspiration_analysis_id=inspiration_analysis_id,
        expires_at=expires_at,
    )

    try:
        db.add(task_record)
        db.commit()
        db.refresh(task_record)
    except Exception as e:
        db.rollback()
        if not used_model:
            image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
        if garment_meta:
            image_storage_service.delete(garment_meta.public_id, storage_provider=garment_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error saving try-on task: {str(e)}",
        )

    return _task_to_response(task_record)


@router.get("/history", response_model=TryOnHistoryResponse)
def get_tryon_history(
    limit: int = Query(20, ge=1, le=100, description="Page limit between 1 and 100"),
    cursor: Optional[str] = Query(None, description="Opaque cursor token for stable pagination"),
    status: Optional[str] = Query("success", description="Filter by status: 'success' (default), 'all', 'failed', 'processing'"),
    db: Session = Depends(get_db),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Authenticated, cursor-paginated virtual try-on history for the current user.
    - Identity derived exclusively from verified Supabase JWT (current_user.id).
    - Returns newest first with deterministic tie-breaking by (created_at DESC, id DESC).
    - Result image delivery URLs generated on-demand with expiring HMAC signatures.
    """
    query = db.query(TryOnTaskRecord).filter(TryOnTaskRecord.user_id == current_user.id)

    if status and status.lower() != "all":
        query = query.filter(TryOnTaskRecord.status == status.lower())

    total_count = query.count()

    if cursor:
        cursor_dt, cursor_id = _decode_cursor(cursor)
        query = query.filter(
            or_(
                TryOnTaskRecord.created_at < cursor_dt,
                and_(
                    TryOnTaskRecord.created_at == cursor_dt,
                    TryOnTaskRecord.id < cursor_id,
                ),
            )
        )

    records = (
        query.order_by(TryOnTaskRecord.created_at.desc(), TryOnTaskRecord.id.desc())
        .limit(limit + 1)
        .all()
    )

    has_more = len(records) > limit
    page_records = records[:limit] if has_more else records

    next_cursor = None
    if has_more and page_records:
        last_rec = page_records[-1]
        next_cursor = _encode_cursor(last_rec.created_at, last_rec.id)

    return TryOnHistoryResponse(
        items=[_task_to_response(r) for r in page_records],
        next_cursor=next_cursor,
        has_more=has_more,
        total_count=total_count,
    )


@router.get("/tasks/{task_id}", response_model=TryOnTaskResponse)
async def get_tryon_task_status(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    task = db.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Try-On task not found.")

    # Ownership check: User B cannot access User A's private try-on task
    if task.user_id is not None:
        if current_user is None or current_user.id != task.user_id:
            raise HTTPException(status_code=404, detail="Try-On task not found.")

    # If task is still in progress, poll provider
    if task.status in ["pending", "processing"]:
        provider = get_tryon_provider()
        try:
            status_info = await provider.get_task_status(task.external_task_id)
            new_status = status_info.get("status", task.status)
            task.status = new_status
            if status_info.get("error"):
                task.error_message = status_info["error"]

            if new_status == "success" and status_info.get("result_url") and not task.result_image_public_id:
                raw_url = status_info["result_url"]
                if raw_url.startswith("mock://"):
                    mock_img = Image.new("RGB", (200, 200), color=(180, 160, 140))
                    mock_buf = io.BytesIO()
                    mock_img.save(mock_buf, format="JPEG")
                    clean_res_bytes = mock_buf.getvalue()
                    res_w, res_h = 200, 200
                else:
                    # Server-side ingestion of result with SSRF protection
                    parsed_u = urllib.parse.urlparse(raw_url)
                    if parsed_u.scheme not in ("http", "https"):
                        raise ValueError(f"Invalid result URL scheme: {parsed_u.scheme}")

                    hostname = (parsed_u.hostname or "").lower()
                    if (
                        hostname in ("localhost", "127.0.0.1", "::1", "0.0.0.0")
                        or hostname.startswith("10.")
                        or hostname.startswith("192.168.")
                        or hostname.startswith("172.16.")
                        or hostname.startswith("172.17.")
                        or hostname.startswith("172.18.")
                        or hostname.startswith("172.19.")
                        or hostname.startswith("172.20.")
                        or hostname.startswith("172.21.")
                        or hostname.startswith("172.22.")
                        or hostname.startswith("172.23.")
                        or hostname.startswith("172.24.")
                        or hostname.startswith("172.25.")
                        or hostname.startswith("172.26.")
                        or hostname.startswith("172.27.")
                        or hostname.startswith("172.28.")
                        or hostname.startswith("172.29.")
                        or hostname.startswith("172.30.")
                        or hostname.startswith("172.31.")
                    ):
                        raise ValueError("SSRF protection: internal destinations blocked")

                    if task.provider == "mock" and "external-cdn.example.com" not in raw_url:
                        mock_img = Image.new("RGB", (200, 200), color=(180, 160, 140))
                        mock_buf = io.BytesIO()
                        mock_img.save(mock_buf, format="JPEG")
                        clean_res_bytes = mock_buf.getvalue()
                        res_w, res_h = 200, 200
                    else:
                        async with httpx.AsyncClient(timeout=30.0) as client:
                            resp = await client.get(raw_url)
                            resp.raise_for_status()
                            res_bytes = resp.content

                        if len(res_bytes) > settings.max_upload_size_bytes:
                            raise ValueError("Result image exceeds maximum size limit")

                        with Image.open(io.BytesIO(res_bytes)) as pil_img:
                            pil_img.verify()

                        with Image.open(io.BytesIO(res_bytes)) as pil_img:
                            res_w, res_h = pil_img.size
                            clean_rgb = pil_img.convert("RGB")
                            out_b = io.BytesIO()
                            clean_rgb.save(out_b, format="JPEG", quality=90)
                            clean_res_bytes = out_b.getvalue()

                res_meta = await image_storage_service.upload(
                    user_id=task.user_id,
                    subfolder="tryon",
                    pre_sanitized=(clean_res_bytes, "jpg", res_w, res_h),
                )
                task.result_image_public_id = res_meta.public_id
                task.result_image_url = None
                task.storage_provider = res_meta.storage_provider

            db.commit()
            db.refresh(task)
        except Exception as e:
            logger.error("Failed to poll or ingest try-on result for task %s: %s", task.id, str(e), exc_info=True)
            task.status = "failed"
            task.error_message = "Try-on processing encountered an error."
            db.commit()

    return _task_to_response(task)


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tryon_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    """
    Immediate user-requested deletion of try-on task and its associated body photos.
    """
    task = db.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Try-On task not found.")

    if task.user_id is not None:
        if current_user is None or current_user.id != task.user_id:
            raise HTTPException(status_code=404, detail="Try-On task not found.")
    else:
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot delete unowned legacy tasks.")

    user_asset = task.user_image_public_id or task.user_image_path
    if user_asset:
        is_saved_model = getattr(task, "used_saved_model", False)
        if not is_saved_model and current_user:
            m_exists = db.query(UserTryOnModel).filter(
                (UserTryOnModel.user_id == current_user.id) &
                ((UserTryOnModel.image_path == user_asset) | (UserTryOnModel.cloudinary_public_id == user_asset))
            ).first()
            if m_exists:
                is_saved_model = True
        if not is_saved_model:
            image_storage_service.delete(user_asset, storage_provider=task.storage_provider)

    if task.garment_image_path and "wardrobe/" not in task.garment_image_path:
        garment_asset = task.garment_image_public_id or task.garment_image_path
        if garment_asset:
            image_storage_service.delete(garment_asset, storage_provider=task.storage_provider)

    if task.result_image_public_id:
        image_storage_service.delete(task.result_image_public_id, storage_provider=task.storage_provider)

    db.delete(task)
    db.commit()
    return None


@router.post("/cleanup", status_code=status.HTTP_200_OK)
def trigger_tryon_cleanup(
    db: Session = Depends(get_db),
):
    """
    Trigger cleanup of try-on assets exceeding the 7-day retention period.
    """
    cleaned = cleanup_expired_tryon_tasks(db)
    return {"status": "ok", "cleaned_tasks_count": cleaned}
