import json
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import WardrobeItem
from app.schemas import (
    WardrobeItemResponse,
    WardrobeItemUpdate,
    DetectedFashionItem,
)
from app.services.storage_service import storage_service
from app.services.vision_provider import get_vision_provider

router = APIRouter(prefix="/api/wardrobe", tags=["Digital Wardrobe"])


def _model_to_response(item: WardrobeItem) -> WardrobeItemResponse:
    tags = json.loads(item.tags) if item.tags else []
    return WardrobeItemResponse(
        id=item.id,
        name=item.name,
        category=item.category,
        sub_category=item.sub_category,
        primary_color=item.primary_color,
        secondary_color=item.secondary_color,
        pattern=item.pattern,
        material=item.material,
        fit=item.fit,
        season=item.season,
        formality=item.formality,
        tags=tags,
        image_path=item.image_path,
        image_url=f"/storage/{item.image_path}",
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.post("/detect-item")
async def detect_wardrobe_item_from_photo(
    file: UploadFile = File(...),
):
    """
    Analyzes a photo of a single wardrobe garment to pre-fill metadata
    (category, colors, material, pattern, fit) before saving.
    """
    rel_path, abs_path = await storage_service.save_image(file, subfolder="wardrobe")
    vision = get_vision_provider()
    try:
        summary, vibe, items = await vision.analyze_outfit_image(abs_path)
        primary_item = items[0] if items else None
        return {
            "image_path": rel_path,
            "image_url": f"/storage/{rel_path}",
            "detected_item": primary_item,
        }
    except Exception as e:
        storage_service.delete_file(rel_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Detection failed: {str(e)}",
        )


@router.post("/items", response_model=WardrobeItemResponse, status_code=status.HTTP_201_CREATED)
async def create_wardrobe_item(
    name: str = Form(...),
    category: str = Form(...),
    primary_color: str = Form(...),
    sub_category: Optional[str] = Form(None),
    secondary_color: Optional[str] = Form(None),
    pattern: Optional[str] = Form(None),
    material: Optional[str] = Form(None),
    fit: Optional[str] = Form(None),
    season: Optional[str] = Form(None),
    formality: Optional[str] = Form(None),
    tags: Optional[str] = Form("[]"),  # JSON array string or comma separated
    image_path: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    final_image_path = image_path
    if file:
        rel_path, _ = await storage_service.save_image(file, subfolder="wardrobe")
        final_image_path = rel_path

    if not final_image_path:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either an image file or an existing image_path must be provided.",
        )

    # Parse tags
    parsed_tags = []
    if tags:
        try:
            parsed_tags = json.loads(tags)
            if not isinstance(parsed_tags, list):
                parsed_tags = [str(tags)]
        except Exception:
            parsed_tags = [t.strip() for t in tags.split(",") if t.strip()]

    item = WardrobeItem(
        name=name.strip(),
        category=category.strip().lower(),
        sub_category=sub_category.strip() if sub_category else None,
        primary_color=primary_color.strip(),
        secondary_color=secondary_color.strip() if secondary_color else None,
        pattern=pattern.strip() if pattern else None,
        material=material.strip() if material else None,
        fit=fit.strip() if fit else None,
        season=season.strip() if season else None,
        formality=formality.strip() if formality else None,
        tags=json.dumps(parsed_tags),
        image_path=final_image_path,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return _model_to_response(item)


@router.get("/items", response_model=List[WardrobeItemResponse])
def list_wardrobe_items(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    color: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(WardrobeItem)

    if category and category.lower() != "all":
        query = query.filter(WardrobeItem.category == category.lower().strip())

    if color:
        query = query.filter(
            (WardrobeItem.primary_color.ilike(f"%{color}%"))
            | (WardrobeItem.secondary_color.ilike(f"%{color}%"))
        )

    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (WardrobeItem.name.ilike(s))
            | (WardrobeItem.category.ilike(s))
            | (WardrobeItem.sub_category.ilike(s))
            | (WardrobeItem.material.ilike(s))
            | (WardrobeItem.tags.ilike(s))
        )

    items = query.order_by(WardrobeItem.created_at.desc()).all()
    return [_model_to_response(i) for i in items]


@router.get("/items/{item_id}", response_model=WardrobeItemResponse)
def get_wardrobe_item(item_id: str, db: Session = Depends(get_db)):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")
    return _model_to_response(item)


@router.put("/items/{item_id}", response_model=WardrobeItemResponse)
def update_wardrobe_item(
    item_id: str,
    update_data: WardrobeItemUpdate,
    db: Session = Depends(get_db),
):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    data = update_data.model_dump(exclude_unset=True)
    if "tags" in data and data["tags"] is not None:
        item.tags = json.dumps(data.pop("tags"))

    for key, value in data.items():
        if hasattr(item, key):
            setattr(item, key, value)

    db.commit()
    db.refresh(item)
    return _model_to_response(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wardrobe_item(item_id: str, db: Session = Depends(get_db)):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    # Remove image file from disk
    storage_service.delete_file(item.image_path)

    db.delete(item)
    db.commit()
    return None


@router.get("/categories")
def get_categories(db: Session = Depends(get_db)):
    all_categories = [
        "tops",
        "shirts",
        "trousers",
        "jeans",
        "jackets",
        "footwear",
        "bags",
        "watches",
        "jewelry",
        "hats",
        "sunglasses",
        "other",
    ]
    # Count items per category in user's wardrobe
    counts = {}
    items = db.query(WardrobeItem.category).all()
    for (cat,) in items:
        counts[cat] = counts.get(cat, 0) + 1

    return [
        {"category": cat, "count": counts.get(cat, 0)}
        for cat in all_categories
    ]
