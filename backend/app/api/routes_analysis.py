import json
import logging
import time
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import OutfitAnalysisRecord
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
