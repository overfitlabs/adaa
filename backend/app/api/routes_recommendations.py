from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.models import WardrobeItem
from app.schemas import (
    StyleRecommendation,
    OutfitGenerationRequest,
    OutfitGenerationResponse,
)
from app.services.stylist_service import StylistService
from app.api.routes_wardrobe import _model_to_response

router = APIRouter(prefix="/api/recommendations", tags=["Styling Recommendations"])


@router.get("", response_model=List[StyleRecommendation])
def get_recommendations(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = db.query(WardrobeItem).filter(WardrobeItem.user_id == current_user.id).all()
    if not items:
        return [
            StyleRecommendation(
                title="Build Your Capsule Foundation",
                description="Your wardrobe is currently empty. Start by uploading foundational pieces like a clean white tee, tailored trousers, and comfortable footwear.",
                occasion="Everyday",
                suggested_item_ids=[],
                styling_tips=[
                    "Aim for 3 versatile tops and 2 adaptable bottoms to unlock 6 initial outfit permutations.",
                    "Neutral tones (white, grey, black, navy) form the easiest foundation.",
                ],
                items=[],
            )
        ]

    # Organize items by category
    by_category = {}
    for i in items:
        by_category.setdefault(i.category, []).append(i)

    recommendations: List[StyleRecommendation] = []

    # 1. High-Low Layering (Outerwear + Casual Top + Bottom)
    jackets = by_category.get("jackets", []) + by_category.get("outerwear", [])
    tops = by_category.get("tops", []) + by_category.get("shirts", [])
    bottoms = by_category.get("trousers", []) + by_category.get("jeans", []) + by_category.get("bottoms", [])
    shoes = by_category.get("footwear", [])

    if jackets and tops and bottoms:
        rec_item_records = [jackets[0], tops[0], bottoms[0]]
        if shoes:
            rec_item_records.append(shoes[0])
        recommendations.append(
            StyleRecommendation(
                title="Sartorial High-Low Mix",
                description=f"Balance the structure of your {jackets[0].name} by pairing it with your relaxed {tops[0].name} and {bottoms[0].name}.",
                occasion="Smart Casual / Dinner",
                suggested_item_ids=[i.id for i in rec_item_records],
                styling_tips=[
                    "Leave the jacket unbuttoned to maintain an approachable silhouette.",
                    "Cuff trousers slightly above the ankle to showcase footwear.",
                ],
                items=[_model_to_response(i) for i in rec_item_records],
            )
        )

    # 2. Monochromatic or Tonal Harmony
    color_map = {}
    for i in items:
        col = (i.primary_color or "neutral").lower().strip()
        color_map.setdefault(col, []).append(i)

    for col, c_items in color_map.items():
        if len(c_items) >= 2:
            rec_items = [c_items[0], c_items[1]]
            recommendations.append(
                StyleRecommendation(
                    title=f"Tonal {col.capitalize()} Expression",
                    description=f"A clean monochromatic set uniting your {c_items[0].name} and {c_items[1].name}.",
                    occasion="Modern Minimalist",
                    suggested_item_ids=[i.id for i in rec_items],
                    styling_tips=[
                        "Varying fabrics (e.g. wool against cotton or leather) prevents single-shade looks from appearing flat.",
                        "Add a contrasting accessory like sunglasses or a bag for visual anchor.",
                    ],
                    items=[_model_to_response(i) for i in rec_items],
                )
            )
            break

    # 3. Weekend Leisure
    if bottoms and tops:
        rec_items = [tops[-1], bottoms[-1]]
        recommendations.append(
            StyleRecommendation(
                title="Effortless Weekend Silhouette",
                description=f"Keep it comfortable and understated with your {tops[-1].name} and {bottoms[-1].name}.",
                occasion="Casual Weekend",
                suggested_item_ids=[i.id for i in rec_items],
                styling_tips=[
                    "French tuck the front of the top for flattering proportions.",
                    "Complete with subtle jewelry or a clean canvas tote.",
                ],
                items=[_model_to_response(i) for i in rec_items],
            )
        )

    return recommendations


@router.post("/generate", response_model=OutfitGenerationResponse)
def generate_outfits(
    request: OutfitGenerationRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Generate multiple tailored outfit combinations from the authenticated user's own wardrobe.
    Supports occasion, style/vibe, and optional instructions.
    Leverages profile preferences when available.
    """
    return StylistService.generate_outfit_recommendations(
        user_id=current_user.id,
        db=db,
        request=request,
    )


@router.get("/generate", response_model=OutfitGenerationResponse)
def generate_outfits_get(
    occasion: Optional[str] = Query("Everyday", description="Target occasion"),
    vibe: Optional[str] = Query(None, description="Aesthetic style or vibe"),
    instructions: Optional[str] = Query(None, description="Optional custom styling instructions"),
    refine_index: Optional[int] = Query(0, description="Refinement iteration index"),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    GET variant of outfit generation supporting simple query parameters.
    """
    req = OutfitGenerationRequest(
        occasion=occasion,
        vibe=vibe,
        instructions=instructions,
        refine_index=refine_index,
    )
    return StylistService.generate_outfit_recommendations(
        user_id=current_user.id,
        db=db,
        request=req,
    )
