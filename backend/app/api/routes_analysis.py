import json
import logging
import time
import uuid
from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import OutfitAnalysisRecord, WardrobeItem, SavedOutfit
from app.schemas import OutfitAnalysisResponse, DetectedFashionItem, StyleAttributes
from app.services.image_storage import image_storage_service
from app.services.vision_provider import get_vision_provider
from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser

logger = logging.getLogger("wardrobelens.routes_analysis")

router = APIRouter(prefix="/api/analysis", tags=["Outfit Analysis"])


def _record_to_response(record: OutfitAnalysisRecord) -> OutfitAnalysisResponse:
    if getattr(record, "storage_provider", "local") == "cloudinary" and getattr(record, "cloudinary_public_id", None):
        image_url = image_storage_service.generate_delivery_url(
            record.cloudinary_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    else:
        clean_path = record.image_path.lstrip("/")
        image_url = f"/storage/{clean_path}"

    raw_items = json.loads(record.items_json) if record.items_json else []
    items = []
    for item in raw_items:
        attr = StyleAttributes(**item.get("attributes", {}))
        ext_path = item.get("extracted_image_path")
        ext_url = item.get("extracted_image_url")
        if ext_path:
            ext_url = image_storage_service.generate_delivery_url(
                ext_path,
                storage_provider=record.storage_provider,
                ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
            )
        items.append(
            DetectedFashionItem(
                id=item["id"],
                category=item["category"],
                sub_category=item.get("sub_category"),
                name=item["name"],
                primary_color=item["primary_color"],
                secondary_color=item.get("secondary_color"),
                attributes=attr,
                confidence=item.get("confidence", 0.9),
                bounding_box_description=item.get("bounding_box_description"),
                box_2d=item.get("box_2d"),
                extracted_image_path=ext_path,
                extracted_image_url=ext_url,
            )
        )

    return OutfitAnalysisResponse(
        analysis_id=record.id,
        image_url=image_url,
        summary=record.summary or "Outfit breakdown",
        vibe_or_style=record.vibe or "Contemporary",
        items=items,
        detected_garment_count=len(items),
        created_at=record.created_at,
        user_id=record.user_id,
    )


@router.post("/analyze-image", response_model=OutfitAnalysisResponse)
async def analyze_outfit_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    start_time = time.time()
    filename = file.filename or "unknown"
    user_desc = current_user.id if current_user else "anonymous"
    logger.info("Received /api/analysis/analyze-image request (user=%s, filename=%s)", user_desc, filename)

    # 1. Read and sanitize image content (strips EXIF / GPS metadata)
    raw_bytes = await file.read()
    clean_bytes, ext, width, height = image_storage_service.validate_and_sanitize_image(file, raw_bytes)

    # 2. Staging for Gemini Vision analysis
    # Gemini takes PIL image directly; we pass local staging path without uploading to Cloudinary first
    temp_dir = settings.storage_path / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_path = temp_dir / f"gemini_stage_{uuid.uuid4().hex}.{ext}"

    with open(temp_path, "wb") as f:
        f.write(clean_bytes)

    try:
        vision_provider = get_vision_provider()
        summary, vibe, items = await vision_provider.analyze_outfit_image(temp_path)
    except TimeoutError as e:
        logger.error("Outfit analysis timed out: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=str(e),
        )
    except PermissionError as e:
        logger.error("Outfit analysis authentication error: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except RuntimeError as e:
        err_msg = str(e)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if ("503" in err_msg or "quota" in err_msg.lower()) else status.HTTP_500_INTERNAL_SERVER_ERROR
        logger.error("Outfit analysis runtime error (status=%d): %s", status_code, err_msg)
        raise HTTPException(
            status_code=status_code,
            detail=err_msg,
        )
    except Exception as e:
        logger.error("Outfit analysis unexpected failure: %s", str(e), exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Outfit analysis failed: {str(e)}",
        )
    finally:
        if temp_path.is_file():
            try:
                temp_path.unlink()
            except Exception:
                pass

    # 3. Upload full outfit image to Image Storage (Cloudinary authenticated or local fallback)
    uploaded_meta = await image_storage_service.upload(
        user_id=current_user.id if current_user else None,
        subfolder="inspirations",
        pre_sanitized=(clean_bytes, ext, width, height),
    )

    # 3.1 Extract individual garment images using bounding box coordinates
    try:
        from PIL import Image
        import io
        pil_source = Image.open(io.BytesIO(clean_bytes)).convert("RGB")
        src_w, src_h = pil_source.size

        for item in items:
            crop_img = None
            if item.box_2d and len(item.box_2d) == 4:
                ymin, xmin, ymax, xmax = item.box_2d
                ymin = max(0, min(1000, ymin))
                xmin = max(0, min(1000, xmin))
                ymax = max(0, min(1000, ymax))
                xmax = max(0, min(1000, xmax))

                if ymax > ymin and xmax > xmin:
                    top = int((ymin / 1000.0) * src_h)
                    left = int((xmin / 1000.0) * src_w)
                    bottom = int((ymax / 1000.0) * src_h)
                    right = int((xmax / 1000.0) * src_w)

                    pad_y = max(2, int((bottom - top) * 0.03))
                    pad_x = max(2, int((right - left) * 0.03))
                    crop_box = (
                        max(0, left - pad_x),
                        max(0, top - pad_y),
                        min(src_w, right + pad_x),
                        min(src_h, bottom + pad_y),
                    )
                    crop_img = pil_source.crop(crop_box)

            # Fallback if crop_img is None or invalid
            if crop_img is None or crop_img.width < 10 or crop_img.height < 10:
                crop_img = pil_source.copy()

            crop_buf = io.BytesIO()
            crop_img.save(crop_buf, format="JPEG", quality=90)
            crop_bytes = crop_buf.getvalue()

            try:
                extracted_meta = await image_storage_service.upload(
                    user_id=current_user.id if current_user else None,
                    subfolder="extracted",
                    pre_sanitized=(crop_bytes, "jpg", crop_img.width, crop_img.height),
                )
                item.extracted_image_path = extracted_meta.public_id
                item.extracted_image_url = image_storage_service.generate_delivery_url(
                    extracted_meta.public_id,
                    storage_provider=extracted_meta.storage_provider,
                    ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
                )
            except Exception as upload_err:
                logger.warning("Failed to store extracted item image for %s: %s", item.name, str(upload_err))
                item.extracted_image_path = uploaded_meta.public_id
                item.extracted_image_url = image_storage_service.generate_delivery_url(
                    uploaded_meta.public_id,
                    storage_provider=uploaded_meta.storage_provider,
                    ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
                )
    except Exception as extract_err:
        logger.warning("Multi-item extraction encountered an error; falling back to original image: %s", str(extract_err))
        for item in items:
            item.extracted_image_path = uploaded_meta.public_id
            item.extracted_image_url = image_storage_service.generate_delivery_url(
                uploaded_meta.public_id,
                storage_provider=uploaded_meta.storage_provider,
                ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
            )

    # 4. Persist analysis to database
    items_serialized = json.dumps([item.model_dump() for item in items])
    record = OutfitAnalysisRecord(
        user_id=current_user.id if current_user else None,
        image_path=uploaded_meta.public_id,
        storage_provider=uploaded_meta.storage_provider,
        cloudinary_public_id=uploaded_meta.public_id if uploaded_meta.storage_provider == "cloudinary" else None,
        image_format=uploaded_meta.format,
        image_version=uploaded_meta.version,
        summary=summary,
        vibe=vibe,
        items_json=items_serialized,
    )

    try:
        db.add(record)
        db.commit()
        db.refresh(record)
    except Exception as e:
        db.rollback()
        image_storage_service.delete(uploaded_meta.public_id, storage_provider=uploaded_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error saving analysis record: {str(e)}",
        )

    total_time = time.time() - start_time
    logger.info("Outfit analysis completed in %.2fs (record_id=%s, user_id=%s)", total_time, record.id, record.user_id)
    return _record_to_response(record)


@router.get("/{analysis_id}", response_model=OutfitAnalysisResponse)
def get_analysis(
    analysis_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    record = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == analysis_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Analysis record not found.")

    # Authorization guard: A user cannot access another user's private analysis record
    if record.user_id is not None:
        if current_user is None or current_user.id != record.user_id:
            raise HTTPException(status_code=404, detail="Analysis record not found.")

    return _record_to_response(record)


@router.get("", response_model=List[OutfitAnalysisResponse])
def list_recent_analyses(
    limit: int = 10,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    # Only return analyses owned by current_user, or unowned legacy analyses if anonymous
    query = db.query(OutfitAnalysisRecord)
    if current_user:
        query = query.filter(OutfitAnalysisRecord.user_id == current_user.id)
    else:
        query = query.filter(OutfitAnalysisRecord.user_id.is_(None))

    records = query.order_by(OutfitAnalysisRecord.created_at.desc()).limit(limit).all()
    return [_record_to_response(r) for r in records]


def delete_analysis_record_and_assets(
    db: Session,
    record: OutfitAnalysisRecord,
) -> bool:
    """
    Deletes the OutfitAnalysisRecord and all associated image assets (original photo and crops).
    CRITICAL: Preserves any crop assets that have been saved into a WardrobeItem or SavedOutfit.
    Returns True if deletion succeeded.
    Raises RuntimeError if image storage cleanup failed.
    """
    candidate_assets = set()
    if record.cloudinary_public_id:
        candidate_assets.add(record.cloudinary_public_id)
    if record.image_path:
        candidate_assets.add(record.image_path)

    try:
        raw_items = json.loads(record.items_json) if record.items_json else []
        for item in raw_items:
            ext_path = item.get("extracted_image_path")
            if ext_path:
                candidate_assets.add(ext_path)
    except Exception as e:
        logger.warning("Failed to parse items_json for analysis %s: %s", record.id, e)

    candidate_assets.discard("")
    candidate_assets.discard(None)
    candidate_assets.discard("wardrobe/placeholder.jpg")

    # Check which candidate assets are in use by WardrobeItem or SavedOutfit
    wardrobe_items = db.query(WardrobeItem).filter(
        (WardrobeItem.image_path.in_(candidate_assets)) |
        (WardrobeItem.cloudinary_public_id.in_(candidate_assets))
    ).all()
    protected_assets = set()
    for w_item in wardrobe_items:
        if w_item.image_path:
            protected_assets.add(w_item.image_path)
            protected_assets.add(w_item.image_path.lstrip("/"))
        if w_item.cloudinary_public_id:
            protected_assets.add(w_item.cloudinary_public_id)

    saved_outfits = db.query(SavedOutfit).filter(
        (SavedOutfit.image_path.in_(candidate_assets)) |
        (SavedOutfit.cloudinary_public_id.in_(candidate_assets))
    ).all()
    for s_outfit in saved_outfits:
        if s_outfit.image_path:
            protected_assets.add(s_outfit.image_path)
            protected_assets.add(s_outfit.image_path.lstrip("/"))
        if s_outfit.cloudinary_public_id:
            protected_assets.add(s_outfit.cloudinary_public_id)

    # Also protect if another analysis references the same asset
    other_records = db.query(OutfitAnalysisRecord).filter(
        OutfitAnalysisRecord.id != record.id,
        (OutfitAnalysisRecord.image_path.in_(candidate_assets)) |
        (OutfitAnalysisRecord.cloudinary_public_id.in_(candidate_assets))
    ).all()
    for o_rec in other_records:
        if o_rec.image_path:
            protected_assets.add(o_rec.image_path)
        if o_rec.cloudinary_public_id:
            protected_assets.add(o_rec.cloudinary_public_id)

    assets_to_delete = candidate_assets - protected_assets

    storage_provider = getattr(record, "storage_provider", "local")
    failed_assets = []
    for asset in assets_to_delete:
        success = image_storage_service.delete(asset, storage_provider=storage_provider)
        if not success:
            failed_assets.append(asset)

    if failed_assets:
        logger.error(
            "Failed to delete storage assets for analysis %s: %s",
            record.id,
            failed_assets,
        )
        raise RuntimeError(f"Storage asset deletion failed for {len(failed_assets)} asset(s).")

    db.delete(record)
    db.commit()
    logger.info("Successfully deleted analysis %s and %d asset(s)", record.id, len(assets_to_delete))
    return True


def cleanup_abandoned_analyses(db: Session, max_age_hours: int = 24) -> dict:
    """
    Cleans up abandoned outfit analyses older than max_age_hours.
    An analysis is abandoned if:
    1. created_at <= now - max_age_hours
    2. NOT linked to any SavedOutfit (via inspiration_analysis_id)
    Any cropped garments saved to WardrobeItem are protected.
    """
    cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)

    saved_inspiration_ids = [
        row[0] for row in db.query(SavedOutfit.inspiration_analysis_id)
        .filter(SavedOutfit.inspiration_analysis_id.isnot(None))
        .all()
    ]

    query = db.query(OutfitAnalysisRecord).filter(
        OutfitAnalysisRecord.created_at <= cutoff
    )
    if saved_inspiration_ids:
        query = query.filter(~OutfitAnalysisRecord.id.in_(saved_inspiration_ids))

    abandoned_records = query.all()
    cleaned_count = 0
    failed_count = 0

    for rec in abandoned_records:
        try:
            delete_analysis_record_and_assets(db, rec)
            cleaned_count += 1
        except Exception as e:
            db.rollback()
            logger.error("Failed to clean up abandoned analysis %s: %s", rec.id, e)
            failed_count += 1

    return {
        "status": "success",
        "abandoned_scans_cleaned": cleaned_count,
        "failed_scans": failed_count,
        "retention_cutoff": cutoff.isoformat(),
    }


@router.delete("/{analysis_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_analysis(
    analysis_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    record = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == analysis_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Analysis record not found.")

    # Authorization guard:
    # A user cannot access or delete another user's private analysis record.
    # Return 404 to avoid leaking existence of another user's record.
    if record.user_id is not None:
        if current_user is None or current_user.id != record.user_id:
            raise HTTPException(status_code=404, detail="Analysis record not found.")
    else:
        # Legacy unowned record cannot be deleted by authenticated users
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot delete unowned legacy analysis.")

    try:
        delete_analysis_record_and_assets(db, record)
    except RuntimeError as e:
        logger.error("Storage error during deletion of analysis %s: %s", analysis_id, str(e))
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to clean up storage assets for analysis. Please retry.",
        )
    except Exception as e:
        db.rollback()
        logger.error("Unexpected error deleting analysis %s: %s", analysis_id, str(e), exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete analysis record.",
        )

    return None


@router.post("/cleanup")
def trigger_analysis_cleanup(
    max_age_hours: int = 24,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
    x_operator_secret: Optional[str] = Header(None, alias="X-Operator-Secret"),
):
    """
    Operator cleanup endpoint to purge abandoned scans older than max_age_hours (default: 24h).
    Preserves all wardrobe items and saved outfit assets.
    Restricted: Ordinary users cannot trigger global scan cleanups.
    """
    is_admin = current_user and getattr(current_user, "role", None) in ("admin", "service_role")
    configured_secret = getattr(settings, "OPERATOR_SECRET", "")
    is_operator = bool(configured_secret and x_operator_secret == configured_secret)

    if not is_admin and not is_operator:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Operator authorization required for global cleanup.",
        )

    result = cleanup_abandoned_analyses(db, max_age_hours=max_age_hours)
    return result

