import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import SavedOutfit, WardrobeItem
from app.schemas import (
    SavedOutfitCreate,
    SavedOutfitResponse,
    WardrobeItemResponse,
)
from app.api.routes_wardrobe import _model_to_response
from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser

router = APIRouter(prefix="/api/outfits", tags=["Saved Outfits & Looks"])


def _outfit_to_response(outfit: SavedOutfit, db: Session) -> SavedOutfitResponse:
    item_ids = json.loads(outfit.item_ids_json) if outfit.item_ids_json else []
    # Resolve items
    wardrobe_records = db.query(WardrobeItem).filter(WardrobeItem.id.in_(item_ids)).all()
    items: List[WardrobeItemResponse] = [_model_to_response(w) for w in wardrobe_records]

    return SavedOutfitResponse(
        id=outfit.id,
        name=outfit.name,
        occasion=outfit.occasion,
        notes=outfit.notes,
        image_path=outfit.image_path,
        item_ids=item_ids,
        items=items,
        inspiration_analysis_id=outfit.inspiration_analysis_id,
        created_at=outfit.created_at,
        updated_at=outfit.updated_at,
    )


@router.post("", response_model=SavedOutfitResponse, status_code=status.HTTP_201_CREATED)
def create_saved_outfit(
    data: SavedOutfitCreate,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    outfit = SavedOutfit(
        user_id=current_user.id if current_user else None,
        name=data.name.strip(),
        occasion=data.occasion.strip() if data.occasion else None,
        notes=data.notes.strip() if data.notes else None,
        item_ids_json=json.dumps(data.item_ids),
        inspiration_analysis_id=data.inspiration_analysis_id,
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    return _outfit_to_response(outfit, db)


@router.get("", response_model=List[SavedOutfitResponse])
def list_saved_outfits(
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    query = db.query(SavedOutfit)
    if current_user:
        query = query.filter(SavedOutfit.user_id == current_user.id)
    else:
        query = query.filter(SavedOutfit.user_id.is_(None))

    outfits = query.order_by(SavedOutfit.created_at.desc()).all()
    return [_outfit_to_response(o, db) for o in outfits]


@router.get("/{outfit_id}", response_model=SavedOutfitResponse)
def get_saved_outfit(
    outfit_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found.")

    if outfit.user_id is not None:
        if current_user is None or current_user.id != outfit.user_id:
            raise HTTPException(status_code=404, detail="Saved outfit not found.")

    return _outfit_to_response(outfit, db)


@router.delete("/{outfit_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_saved_outfit(
    outfit_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    outfit = db.query(SavedOutfit).filter(SavedOutfit.id == outfit_id).first()
    if not outfit:
        raise HTTPException(status_code=404, detail="Saved outfit not found.")

    if outfit.user_id is not None:
        if current_user is None or current_user.id != outfit.user_id:
            raise HTTPException(status_code=404, detail="Saved outfit not found.")
    else:
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot delete unowned legacy outfits.")

    db.delete(outfit)
    db.commit()
    return None
