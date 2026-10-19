from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import WardrobeItem
from app.schemas import StyleRecommendation

router = APIRouter(prefix="/api/recommendations", tags=["Styling Recommendations"])


@router.get("", response_model=List[StyleRecommendation])
def get_recommendations(db: Session = Depends(get_db)):
    items = db.query(WardrobeItem).all()
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
            )
        ]

    # Organize items by category
    by_category = {}
    for i in items:
        by_category.setdefault(i.category, []).append(i)

    recommendations: List[StyleRecommendation] = []

    # 1. High-Low Layering (Outerwear + Casual Top + Bottom)
    jackets = by_category.get("jackets", [])
    tops = by_category.get("tops", []) + by_category.get("shirts", [])
    bottoms = by_category.get("trousers", []) + by_category.get("jeans", [])
    shoes = by_category.get("footwear", [])

    if jackets and tops and bottoms:
        rec_items = [jackets[0].id, tops[0].id, bottoms[0].id]
        if shoes:
            rec_items.append(shoes[0].id)
        recommendations.append(
            StyleRecommendation(
                title="Sartorial High-Low Mix",
                description=f"Balance the structure of your {jackets[0].name} by pairing it with your relaxed {tops[0].name} and {bottoms[0].name}.",
                occasion="Smart Casual / Dinner",
                suggested_item_ids=rec_items,
                styling_tips=[
                    "Leave the jacket unbuttoned to maintain an approachable silhouette.",
                    "Cuff trousers slightly above the ankle to showcase footwear.",
                ],
            )
        )

    # 2. Monochromatic or Tonal Harmony
    color_map = {}
    for i in items:
        col = i.primary_color.lower().strip()
        color_map.setdefault(col, []).append(i)

    for col, c_items in color_map.items():
        if len(c_items) >= 2:
            recommendations.append(
                StyleRecommendation(
                    title=f"Tonal {col.capitalize()} Expression",
                    description=f"A clean monochromatic set uniting your {c_items[0].name} and {c_items[1].name}.",
                    occasion="Modern Minimalist",
                    suggested_item_ids=[c_items[0].id, c_items[1].id],
                    styling_tips=[
                        "Varying fabrics (e.g. wool against cotton or leather) prevents single-shade looks from appearing flat.",
                        "Add a contrasting accessory like sunglasses or a bag for visual anchor.",
                    ],
                )
            )
            break

    # 3. Weekend Leisure
    if bottoms and tops:
        recommendations.append(
            StyleRecommendation(
                title="Effortless Weekend Silhouette",
                description=f"Keep it comfortable and understated with your {tops[-1].name} and {bottoms[-1].name}.",
                occasion="Casual Weekend",
                suggested_item_ids=[tops[-1].id, bottoms[-1].id],
                styling_tips=[
                    "French tuck the front of the top for flattering proportions.",
                    "Complete with subtle jewelry or a clean canvas tote.",
                ],
            )
        )

    return recommendations
