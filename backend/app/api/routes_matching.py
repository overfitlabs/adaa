from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.models import WardrobeItem
from app.schemas import (
    MatchRequest,
    OutfitMatchResponse,
    WardrobeItemResponse,
)
from app.api.routes_wardrobe import _model_to_response
from app.services.matching_engine import matching_engine

router = APIRouter(prefix="/api/matching", tags=["Outfit Matching"])


@router.post("/match-outfit", response_model=OutfitMatchResponse)
def match_outfit(
    request: MatchRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # 1. Fetch user's current wardrobe strictly scoped to authenticated user
    db_items = db.query(WardrobeItem).filter(WardrobeItem.user_id == current_user.id).all()
    wardrobe: list[WardrobeItemResponse] = [_model_to_response(item) for item in db_items]

    # 2. Match target items against wardrobe
    result = matching_engine.match_outfit_against_wardrobe(
        target_items=request.items,
        wardrobe=wardrobe,
        analysis_id=request.analysis_id,
    )
    return result

