from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models import TryOnTaskRecord, WardrobeItem
from app.schemas import TryOnTaskResponse
from app.services.storage_service import storage_service
from app.services.tryon_provider import get_tryon_provider

router = APIRouter(prefix="/api/tryon", tags=["Virtual Try-On"])


@router.post("/tasks", response_model=TryOnTaskResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_tryon_task(
    user_image: UploadFile = File(..., description="Full or half-body photo of the user"),
    garment_image: Optional[UploadFile] = File(None, description="Garment or inspiration outfit photo"),
    wardrobe_item_id: Optional[str] = Form(None, description="Or select an item already in digital wardrobe"),
    garment_category: str = Form("upper body", description="Garment type: upper body, lower body, full body, dress, outer"),
    db: Session = Depends(get_db),
):
    # 1. Save user image
    user_rel, user_abs = await storage_service.save_image(user_image, subfolder="tryon")

    # 2. Determine garment image
    if garment_image:
        garment_rel, garment_abs = await storage_service.save_image(garment_image, subfolder="tryon")
    elif wardrobe_item_id:
        item = db.query(WardrobeItem).filter(WardrobeItem.id == wardrobe_item_id).first()
        if not item:
            raise HTTPException(status_code=404, detail="Selected wardrobe item not found.")
        garment_rel = item.image_path
        garment_abs = storage_service.get_absolute_path(garment_rel)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either a garment image file or a wardrobe_item_id must be provided.",
        )

    # 3. Call tryon provider
    provider = get_tryon_provider()
    try:
        task_info = await provider.create_tryon_task(
            user_image_path=user_abs,
            garment_image_path=garment_abs,
            garment_category=garment_category,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Try-On service initiation failed: {str(e)}",
        )

    # 4. Save record
    task_record = TryOnTaskRecord(
        provider=task_info.get("provider", "mock"),
        external_task_id=task_info.get("task_id"),
        status=task_info.get("status", "processing"),
        user_image_path=user_rel,
        garment_image_path=garment_rel,
    )
    db.add(task_record)
    db.commit()
    db.refresh(task_record)

    return TryOnTaskResponse(
        task_id=task_record.id,
        status=task_record.status,
        provider=task_record.provider,
        user_image_url=f"/storage/{task_record.user_image_path}",
        garment_image_url=f"/storage/{task_record.garment_image_path}",
        result_image_url=task_record.result_image_url,
        error_message=task_record.error_message,
        created_at=task_record.created_at,
        updated_at=task_record.updated_at,
    )


@router.get("/tasks/{task_id}", response_model=TryOnTaskResponse)
async def get_tryon_task_status(task_id: str, db: Session = Depends(get_db)):
    task = db.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == task_id).first()
    if not task:
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
            # Don't fail the request, report error status
            task.error_message = str(e)
            db.commit()

    return TryOnTaskResponse(
        task_id=task.id,
        status=task.status,
        provider=task.provider,
        user_image_url=f"/storage/{task.user_image_path}",
        garment_image_url=f"/storage/{task.garment_image_path}",
        result_image_url=task.result_image_url,
        error_message=task.error_message,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )
