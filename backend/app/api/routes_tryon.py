import logging
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import TryOnTaskRecord, WardrobeItem
from app.schemas import TryOnTaskResponse
from app.services.image_storage import image_storage_service
from app.services.tryon_provider import get_tryon_provider
from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser

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
        clean_user_path = task.user_image_path.lstrip("/")
        user_image_url = f"/storage/{clean_user_path}"

    if getattr(task, "storage_provider", "local") == "cloudinary" and getattr(task, "garment_image_public_id", None):
        garment_image_url = image_storage_service.generate_delivery_url(
            task.garment_image_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    else:
        clean_garment_path = task.garment_image_path.lstrip("/")
        garment_image_url = f"/storage/{clean_garment_path}"

    result_url = task.result_image_url
    if getattr(task, "result_image_public_id", None) and getattr(task, "storage_provider", "local") == "cloudinary":
        result_url = image_storage_service.generate_delivery_url(
            task.result_image_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )

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
            # Delete user image
            user_asset = task.user_image_public_id or task.user_image_path
            image_storage_service.delete(user_asset, storage_provider=task.storage_provider)

            # Delete garment image if it was uploaded for tryon (not a shared wardrobe item)
            if "wardrobe/" not in task.garment_image_path:
                garment_asset = task.garment_image_public_id or task.garment_image_path
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


@router.post("/tasks", response_model=TryOnTaskResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_tryon_task(
    user_image: UploadFile = File(..., description="Full or half-body photo of the user"),
    garment_image: Optional[UploadFile] = File(None, description="Garment or inspiration outfit photo"),
    wardrobe_item_id: Optional[str] = Form(None, description="Or select an item already in digital wardrobe"),
    garment_category: str = Form("upper body", description="Garment type: upper body, lower body, full body, dress, outer"),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    user_id = current_user.id if current_user else None

    # 1. Save user image
    user_meta = await image_storage_service.upload(
        user_image,
        user_id=user_id,
        subfolder="tryon",
    )

    # 2. Determine garment image
    garment_meta = None
    garment_rel = None
    garment_abs = None

    if garment_image:
        garment_meta = await image_storage_service.upload(
            garment_image,
            user_id=user_id,
            subfolder="tryon",
        )
        garment_rel = garment_meta.public_id
        garment_abs = image_storage_service.get_absolute_path(garment_rel)
    elif wardrobe_item_id:
        item = db.query(WardrobeItem).filter(WardrobeItem.id == wardrobe_item_id).first()
        if not item:
            image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
            raise HTTPException(status_code=404, detail="Selected wardrobe item not found.")

        # Ensure ownership of the wardrobe item
        if item.user_id is not None:
            if current_user is None or current_user.id != item.user_id:
                image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
                raise HTTPException(status_code=404, detail="Selected wardrobe item not found.")

        garment_rel = item.image_path
        garment_abs = image_storage_service.get_absolute_path(garment_rel)
    else:
        image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either a garment image file or a wardrobe_item_id must be provided.",
        )

    # 3. Call tryon provider
    provider = get_tryon_provider()
    user_abs = image_storage_service.get_absolute_path(user_meta.public_id)

    try:
        task_info = await provider.create_tryon_task(
            user_image_path=user_abs,
            garment_image_path=garment_abs,
            garment_category=garment_category,
        )
    except Exception as e:
        image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
        if garment_meta:
            image_storage_service.delete(garment_meta.public_id, storage_provider=garment_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Try-On service initiation failed: {str(e)}",
        )

    # 4. Save record with 7-day retention expiry
    expires_at = datetime.utcnow() + timedelta(days=settings.TRYON_RETENTION_DAYS)
    task_record = TryOnTaskRecord(
        user_id=user_id,
        provider=task_info.get("provider", "mock"),
        external_task_id=task_info.get("task_id"),
        status=task_info.get("status", "processing"),
        user_image_path=user_meta.public_id,
        garment_image_path=garment_rel,
        storage_provider=user_meta.storage_provider,
        user_image_public_id=user_meta.public_id if user_meta.storage_provider == "cloudinary" else None,
        garment_image_public_id=garment_meta.public_id if garment_meta and garment_meta.storage_provider == "cloudinary" else None,
        expires_at=expires_at,
    )

    try:
        db.add(task_record)
        db.commit()
        db.refresh(task_record)
    except Exception as e:
        db.rollback()
        image_storage_service.delete(user_meta.public_id, storage_provider=user_meta.storage_provider)
        if garment_meta:
            image_storage_service.delete(garment_meta.public_id, storage_provider=garment_meta.storage_provider)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error saving try-on task: {str(e)}",
        )

    return _task_to_response(task_record)


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
            task.status = status_info.get("status", task.status)
            if status_info.get("result_url"):
                task.result_image_url = status_info["result_url"]
            if status_info.get("error"):
                task.error_message = status_info["error"]
            db.commit()
            db.refresh(task)
        except Exception as e:
            task.error_message = str(e)
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
    image_storage_service.delete(user_asset, storage_provider=task.storage_provider)

    if "wardrobe/" not in task.garment_image_path:
        garment_asset = task.garment_image_public_id or task.garment_image_path
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
