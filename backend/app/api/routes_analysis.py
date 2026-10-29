import hmac
import io
import json
import logging
import re
import time
import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import OutfitAnalysisRecord, WardrobeItem, SavedOutfit
from app.schemas import (
    OutfitAnalysisResponse,
    DetectedFashionItem,
    StyleAttributes,
    ScanStatusResponse,
    MediaFlowsWebhookPayload,
)
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
        status=getattr(record, "status", "completed"),
        error=getattr(record, "error_message", None),
    )


async def _extract_garment_crops(
    clean_bytes: bytes,
    items: List[DetectedFashionItem],
    user_id: Optional[str],
    original_public_id: str,
    original_storage_provider: str,
) -> None:
    """
    Extracts individual garment crops using Pillow bounding boxes and uploads them.
    Stored under subfolder='extracted' WITHOUT the 'adaa-scan-pending' tag to prevent recursive triggers.
    """
    try:
        from PIL import Image
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

            if crop_img is None or crop_img.width < 10 or crop_img.height < 10:
                crop_img = pil_source.copy()

            crop_buf = io.BytesIO()
            crop_img.save(crop_buf, format="JPEG", quality=90)
            crop_bytes = crop_buf.getvalue()

            try:
                # Untagged upload ensures recursive MediaFlows upload triggers are strictly prevented
                extracted_meta = await image_storage_service.upload(
                    user_id=user_id,
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
                item.extracted_image_path = original_public_id
                item.extracted_image_url = image_storage_service.generate_delivery_url(
                    original_public_id,
                    storage_provider=original_storage_provider,
                    ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
                )
    except Exception as extract_err:
        logger.warning("Multi-item extraction encountered an error; falling back to original image: %s", str(extract_err))
        for item in items:
            item.extracted_image_path = original_public_id
            item.extracted_image_url = image_storage_service.generate_delivery_url(
                original_public_id,
                storage_provider=original_storage_provider,
                ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
            )


def _fetch_image_bytes_for_record(record: OutfitAnalysisRecord) -> Optional[bytes]:
    try:
        clean_path = record.image_path.lstrip("/")
        local_path = settings.storage_path / clean_path
        if local_path.is_file():
            return local_path.read_bytes()

        if record.storage_provider == "cloudinary" and record.cloudinary_public_id:
            import urllib.request
            delivery_url = image_storage_service.generate_delivery_url(
                record.cloudinary_public_id,
                storage_provider="cloudinary",
                ttl_seconds=300,
            )
            req = urllib.request.Request(delivery_url, headers={"User-Agent": "ADAA-Backend/1.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                return resp.read()
    except Exception as e:
        logger.warning("Failed to fetch image bytes for analysis record %s: %s", record.id, str(e))
    return None


def _parse_and_validate_mediaflows_gemini(raw_output: Any) -> Tuple[str, str, List[DetectedFashionItem]]:
    if raw_output is None:
        raise ValueError("MediaFlows output is empty")

    parsed = None
    if isinstance(raw_output, dict):
        parsed = raw_output
    elif isinstance(raw_output, list):
        parsed = {"items": raw_output}
    elif isinstance(raw_output, str):
        cleaned_str = raw_output.strip()
        if len(cleaned_str) > 2_000_000:
            raise ValueError("MediaFlows output payload exceeds size limit (2MB)")
        if cleaned_str.startswith("```"):
            cleaned_str = re.sub(r"^```(?:json)?\s*", "", cleaned_str, flags=re.IGNORECASE)
            cleaned_str = re.sub(r"\s*```$", "", cleaned_str)
        try:
            parsed = json.loads(cleaned_str)
        except json.JSONDecodeError as err:
            raise ValueError(f"Malformed JSON in MediaFlows Gemini output: {str(err)}")
    else:
        raise ValueError(f"Unsupported MediaFlows output type: {type(raw_output).__name__}")

    if not isinstance(parsed, dict):
        raise ValueError("Expected JSON object from MediaFlows Gemini output")

    summary = str(parsed.get("summary") or "Curated outfit ensemble.")[:500]
    vibe = str(parsed.get("vibe") or "Contemporary")[:100]

    raw_items = parsed.get("items")
    if not isinstance(raw_items, list):
        raw_items = []

    validated_items: List[DetectedFashionItem] = []
    for item_data in raw_items[:30]:
        if not isinstance(item_data, dict):
            continue

        raw_box = item_data.get("box_2d")
        box_2d = None
        if isinstance(raw_box, (list, tuple)) and len(raw_box) == 4:
            try:
                coords = [int(v) for v in raw_box]
                ymin, xmin, ymax, xmax = coords
                if 0 <= ymin <= 1000 and 0 <= xmin <= 1000 and 0 <= ymax <= 1000 and 0 <= xmax <= 1000:
                    if ymax > ymin and xmax > xmin:
                        box_2d = [ymin, xmin, ymax, xmax]
            except (ValueError, TypeError):
                box_2d = None

        attr_dict = item_data.get("attributes")
        if not isinstance(attr_dict, dict):
            attr_dict = {}

        attributes = StyleAttributes(
            pattern=str(attr_dict.get("pattern"))[:50] if attr_dict.get("pattern") else None,
            material=str(attr_dict.get("material"))[:50] if attr_dict.get("material") else None,
            fit=str(attr_dict.get("fit"))[:50] if attr_dict.get("fit") else None,
            formality=str(attr_dict.get("formality"))[:50] if attr_dict.get("formality") else None,
            season=str(attr_dict.get("season"))[:50] if attr_dict.get("season") else None,
            neckline_or_collar=str(attr_dict.get("neckline_or_collar"))[:50] if attr_dict.get("neckline_or_collar") else None,
        )

        category = str(item_data.get("category") or "other").strip().lower()[:50]
        name = str(item_data.get("name") or "Fashion Item").strip()[:100]
        primary_color = str(item_data.get("primary_color") or "Neutral").strip()[:50]
        secondary_color = str(item_data.get("secondary_color")).strip()[:50] if item_data.get("secondary_color") else None

        try:
            confidence = float(item_data.get("confidence", 0.9))
            confidence = max(0.0, min(1.0, confidence))
        except (ValueError, TypeError):
            confidence = 0.9

        item = DetectedFashionItem(
            id=str(uuid.uuid4()),
            category=category,
            sub_category=str(item_data.get("sub_category"))[:80] if item_data.get("sub_category") else None,
            name=name,
            primary_color=primary_color,
            secondary_color=secondary_color,
            attributes=attributes,
            confidence=confidence,
            bounding_box_description=str(item_data.get("bounding_box_description"))[:150] if item_data.get("bounding_box_description") else None,
            box_2d=box_2d,
        )
        validated_items.append(item)

    return summary, vibe, validated_items


async def _process_mediaflows_gemini_result(
    record: OutfitAnalysisRecord,
    gemini_output: Any,
    db: Session,
) -> None:
    summary, vibe, items = _parse_and_validate_mediaflows_gemini(gemini_output)

    img_bytes = _fetch_image_bytes_for_record(record)
    if img_bytes is None:
        from PIL import Image
        buf = io.BytesIO()
        Image.new("RGB", (100, 100), color="white").save(buf, format="JPEG")
        img_bytes = buf.getvalue()

    await _extract_garment_crops(
        clean_bytes=img_bytes,
        items=items,
        user_id=record.user_id,
        original_public_id=record.image_path,
        original_storage_provider=record.storage_provider,
    )

    items_serialized = json.dumps([item.model_dump() for item in items])
    record.summary = summary
    record.vibe = vibe
    record.items_json = items_serialized
    record.status = "completed"
    record.error_message = None
    db.commit()
    db.refresh(record)


async def _execute_direct_gemini_fallback(record: OutfitAnalysisRecord, db: Session) -> None:
    img_bytes = _fetch_image_bytes_for_record(record)
    if img_bytes is None:
        raise RuntimeError("Unable to load source image for fallback analysis")

    temp_dir = settings.storage_path / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)
    ext = record.image_format or "jpg"
    temp_path = temp_dir / f"fallback_{uuid.uuid4().hex}.{ext}"
    with open(temp_path, "wb") as f:
        f.write(img_bytes)

    try:
        vision_provider = get_vision_provider()
        summary, vibe, items = await vision_provider.analyze_outfit_image(temp_path)
    finally:
        if temp_path.is_file():
            try:
                temp_path.unlink()
            except Exception:
                pass

    await _extract_garment_crops(
        clean_bytes=img_bytes,
        items=items,
        user_id=record.user_id,
        original_public_id=record.image_path,
        original_storage_provider=record.storage_provider,
    )

    items_serialized = json.dumps([item.model_dump() for item in items])
    record.summary = summary
    record.vibe = vibe
    record.items_json = items_serialized
    record.status = "completed"
    record.error_message = None
    db.commit()
    db.refresh(record)


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

    # =========================================================================
    # MediaFlows Pipeline (Enabled only when USE_MEDIAFLOWS is True)
    # =========================================================================
    if settings.USE_MEDIAFLOWS:
        scan_id = str(uuid.uuid4())
        try:
            uploaded_meta = await image_storage_service.upload(
                user_id=current_user.id if current_user else None,
                subfolder="inspirations",
                pre_sanitized=(clean_bytes, ext, width, height),
                tags=["adaa-scan-pending"],
                context={"scan_id": scan_id, "user_id": current_user.id if current_user else "anonymous"},
            )
        except HTTPException:
            raise
        except Exception as upload_err:
            logger.error("Failed to upload inspiration image for MediaFlows: %s", str(upload_err))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Inspiration image upload failed: {str(upload_err)}",
            )

        record = OutfitAnalysisRecord(
            id=scan_id,
            user_id=current_user.id if current_user else None,
            image_path=uploaded_meta.public_id,
            storage_provider=uploaded_meta.storage_provider,
            cloudinary_public_id=uploaded_meta.public_id if uploaded_meta.storage_provider == "cloudinary" else None,
            image_format=uploaded_meta.format,
            image_version=uploaded_meta.version,
            summary="Analyzing garments via Cloudinary MediaFlows...",
            vibe=None,
            items_json="[]",
            status="processing",
            error_message=None,
        )
        try:
            db.add(record)
            db.commit()
            db.refresh(record)
        except Exception as db_err:
            db.rollback()
            # Clean up uploaded asset to prevent orphaned assets on failure
            image_storage_service.delete(uploaded_meta.public_id, storage_provider=uploaded_meta.storage_provider)
            logger.error("Database error creating pending scan record: %s", str(db_err))
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Database error saving scan record: {str(db_err)}",
            )

        logger.info("MediaFlows scan initiated: scan_id=%s, public_id=%s", scan_id, uploaded_meta.public_id)
        return _record_to_response(record)

    # =========================================================================
    # Direct Synchronous Gemini Pipeline (Default path when USE_MEDIAFLOWS=False)
    # =========================================================================
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

    # Upload full outfit image to Image Storage
    uploaded_meta = await image_storage_service.upload(
        user_id=current_user.id if current_user else None,
        subfolder="inspirations",
        pre_sanitized=(clean_bytes, ext, width, height),
    )

    # Extract individual garment images using bounding box coordinates
    await _extract_garment_crops(
        clean_bytes=clean_bytes,
        items=items,
        user_id=current_user.id if current_user else None,
        original_public_id=uploaded_meta.public_id,
        original_storage_provider=uploaded_meta.storage_provider,
    )

    # Persist analysis to database
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
        status="completed",
        error_message=None,
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


@router.get("/scans/{scan_id}", response_model=ScanStatusResponse)
async def get_scan_status(
    scan_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    record = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == scan_id).first()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Scan record '{scan_id}' not found",
        )

    # Ownership check: if record is owned by a user, only that user may view it
    if record.user_id is not None:
        if current_user is None or current_user.id != record.user_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Scan record not found",
            )

    # Server-side timeout check and idempotent fallback handling
    if record.status in ("pending", "processing"):
        elapsed_seconds = (datetime.utcnow() - record.created_at).total_seconds()
        if elapsed_seconds > settings.MEDIAFLOWS_TIMEOUT_SECONDS:
            logger.warning(
                "Scan %s timed out after %.1fs (limit=%ds); executing server-side direct Gemini fallback",
                scan_id, elapsed_seconds, settings.MEDIAFLOWS_TIMEOUT_SECONDS
            )
            try:
                await _execute_direct_gemini_fallback(record, db)
            except Exception as fb_err:
                logger.error("Fallback for timed-out scan %s failed: %s", scan_id, str(fb_err))
                record.status = "failed"
                record.error_message = f"Scan timed out and fallback failed: {str(fb_err)}"
                db.commit()

    res_data = _record_to_response(record) if record.status == "completed" else None
    return ScanStatusResponse(
        scan_id=record.id,
        status=record.status,
        result=res_data,
        error=record.error_message,
        created_at=record.created_at,
    )


@router.post("/mediaflows-webhook")
async def mediaflows_webhook(
    payload: MediaFlowsWebhookPayload,
    db: Session = Depends(get_db),
    x_mediaflows_secret: Optional[str] = Header(None, alias="X-MediaFlows-Secret"),
    authorization: Optional[str] = Header(None),
):
    # 1. Constant-time secret comparison
    expected_secret = settings.MEDIAFLOWS_WEBHOOK_SECRET
    if not expected_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="MediaFlows webhook secret is not configured on the server",
        )

    incoming_secret = x_mediaflows_secret
    if not incoming_secret and authorization:
        parts = authorization.split(" ", 1)
        if len(parts) == 2 and parts[0].lower() == "bearer":
            incoming_secret = parts[1]
        else:
            incoming_secret = authorization

    if not incoming_secret or not hmac.compare_digest(incoming_secret.strip().encode("utf-8"), expected_secret.strip().encode("utf-8")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MediaFlows webhook secret",
        )

    # 2. Extract scan identifier
    scan_id = payload.scan_id
    if not scan_id and payload.public_id:
        record_by_pid = db.query(OutfitAnalysisRecord).filter(
            (OutfitAnalysisRecord.cloudinary_public_id == payload.public_id) |
            (OutfitAnalysisRecord.image_path == payload.public_id)
        ).first()
        if record_by_pid:
            scan_id = record_by_pid.id

    if not scan_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Webhook payload must include scan_id or recognized public_id",
        )

    # 3. Server-side scan lookup
    record = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == scan_id).first()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Scan record '{scan_id}' not found",
        )

    # 4. Idempotency guard: if scan is already completed, ignore duplicate / late callback
    if record.status == "completed":
        logger.info("Scan %s already completed; ignoring duplicate/late webhook callback", scan_id)
        return {
            "status": "completed",
            "message": "Scan already completed",
            "scan_id": scan_id,
        }

    # 5. Check if MediaFlows reported an error in the flow
    if payload.error or (payload.status and payload.status.lower() in ("failed", "error")):
        err_msg = payload.error or "MediaFlows execution failed"
        logger.warning("MediaFlows reported error for scan %s: %s; attempting fallback", scan_id, err_msg)
        try:
            await _execute_direct_gemini_fallback(record, db)
            return {
                "status": "completed",
                "message": "Recovered via direct Gemini fallback",
                "scan_id": scan_id,
            }
        except Exception as fb_err:
            record.status = "failed"
            record.error_message = f"{err_msg}; fallback also failed: {str(fb_err)}"
            db.commit()
            return {
                "status": "failed",
                "error": record.error_message,
                "scan_id": scan_id,
            }

    # 6. Process Gemini result
    gemini_out = payload.gemini_output
    if gemini_out is None and hasattr(payload, "model_extra") and payload.model_extra:
        for k in ("result", "response", "data", "text", "output"):
            if k in payload.model_extra:
                gemini_out = payload.model_extra[k]
                break

    try:
        await _process_mediaflows_gemini_result(record, gemini_out, db)
        return {
            "status": "completed",
            "message": "Scan processed successfully via MediaFlows",
            "scan_id": scan_id,
        }
    except Exception as parse_err:
        logger.warning(
            "Failed processing MediaFlows Gemini output for scan %s: %s; attempting fallback",
            scan_id, str(parse_err)
        )
        try:
            await _execute_direct_gemini_fallback(record, db)
            return {
                "status": "completed",
                "message": "Recovered via direct Gemini fallback",
                "scan_id": scan_id,
            }
        except Exception as fb_err:
            record.status = "failed"
            record.error_message = f"MediaFlows parsing error ({str(parse_err)}); fallback also failed: {str(fb_err)}"
            db.commit()
            return {
                "status": "failed",
                "error": record.error_message,
                "scan_id": scan_id,
            }


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

