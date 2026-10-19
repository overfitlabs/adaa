import json
from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import OutfitAnalysisRecord
from app.schemas import OutfitAnalysisResponse, DetectedFashionItem, StyleAttributes
from app.services.storage_service import storage_service
from app.services.vision_provider import get_vision_provider

router = APIRouter(prefix="/api/analysis", tags=["Outfit Analysis"])


@router.post("/analyze-image", response_model=OutfitAnalysisResponse)
async def analyze_outfit_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    # 1. Validate & store inspiration image
    rel_path, abs_path = await storage_service.save_image(file, subfolder="inspirations")

    # 2. Run Vision AI analysis
    vision_provider = get_vision_provider()
    try:
        summary, vibe, items = await vision_provider.analyze_outfit_image(abs_path)
    except Exception as e:
        # Clean up stored image on failure
        storage_service.delete_file(rel_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Outfit analysis failed: {str(e)}",
        )

    # 3. Persist analysis to database
    items_serialized = json.dumps([item.model_dump() for item in items])
    record = OutfitAnalysisRecord(
        image_path=rel_path,
        summary=summary,
        vibe=vibe,
        items_json=items_serialized,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return OutfitAnalysisResponse(
        analysis_id=record.id,
        image_url=f"/storage/{rel_path}",
        summary=summary,
        vibe_or_style=vibe,
        items=items,
        detected_garment_count=len(items),
        created_at=record.created_at,
    )


@router.get("/{analysis_id}", response_model=OutfitAnalysisResponse)
def get_analysis(analysis_id: str, db: Session = Depends(get_db)):
    record = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == analysis_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Analysis record not found.")

    raw_items = json.loads(record.items_json)
    items = []
    for item in raw_items:
        attr = StyleAttributes(**item.get("attributes", {}))
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
            )
        )

    return OutfitAnalysisResponse(
        analysis_id=record.id,
        image_url=f"/storage/{record.image_path}",
        summary=record.summary or "Outfit breakdown",
        vibe_or_style=record.vibe or "Contemporary",
        items=items,
        detected_garment_count=len(items),
        created_at=record.created_at,
    )


@router.get("", response_model=List[OutfitAnalysisResponse])
def list_recent_analyses(limit: int = 10, db: Session = Depends(get_db)):
    records = (
        db.query(OutfitAnalysisRecord)
        .order_by(OutfitAnalysisRecord.created_at.desc())
        .limit(limit)
        .all()
    )
    results = []
    for r in records:
        raw_items = json.loads(r.items_json)
        items = []
        for item in raw_items:
            attr = StyleAttributes(**item.get("attributes", {}))
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
                )
            )
        results.append(
            OutfitAnalysisResponse(
                analysis_id=r.id,
                image_url=f"/storage/{r.image_path}",
                summary=r.summary or "",
                vibe_or_style=r.vibe or "",
                items=items,
                detected_garment_count=len(items),
                created_at=r.created_at,
            )
        )
    return results
