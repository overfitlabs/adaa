import json
import logging
from typing import List, Dict, Optional, Tuple, Set
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.models import WardrobeItem, SavedOutfit
from app.schemas import (
    OutfitGenerationRequest,
    OutfitGenerationResponse,
    RecommendedOutfit,
    WardrobeItemResponse,
)
from app.api.routes_wardrobe import _model_to_response

logger = logging.getLogger("wardrobelens.stylist_service")

# Standard category groups
TOP_CATEGORIES = {
    "tops", "t-shirts", "shirts", "sweaters", "hoodies", "blouses", "polo", "knitwear", "tank tops"
}
BOTTOM_CATEGORIES = {
    "bottoms", "trousers", "pants", "jeans", "shorts", "skirts", "sweatpants", "chinos", "leggings"
}
OUTERWEAR_CATEGORIES = {
    "outerwear", "jackets", "coats", "blazers", "cardigans", "overcoats", "vests", "windbreakers"
}
FOOTWEAR_CATEGORIES = {
    "footwear", "shoes", "sneakers", "boots", "loafers", "sandals", "heels", "flats", "oxfords"
}
ACCESSORY_CATEGORIES = {
    "accessories", "bags", "hats", "caps", "scarves", "belts", "sunglasses", "jewelry", "watches"
}
ONE_PIECE_CATEGORIES = {
    "dresses", "jumpsuits", "overalls", "rompers", "suits"
}

NEUTRAL_COLORS = {
    "black", "white", "grey", "gray", "navy", "beige", "cream", "tan", "khaki", "charcoal", "brown", "off-white"
}

COMPLEMENTARY_PAIRS = [
    ({"blue", "navy"}, {"brown", "tan", "beige", "orange"}),
    ({"green", "olive"}, {"cream", "tan", "beige", "brown", "white"}),
    ({"black"}, {"white", "grey", "red", "beige"}),
    ({"grey", "gray"}, {"navy", "burgundy", "pink", "black", "white"}),
    ({"burgundy", "maroon"}, {"navy", "grey", "black", "cream"}),
]


class StylistService:
    @staticmethod
    def categorize_items(items: List[WardrobeItem]) -> Dict[str, List[WardrobeItem]]:
        categorized: Dict[str, List[WardrobeItem]] = {
            "tops": [],
            "bottoms": [],
            "outerwear": [],
            "footwear": [],
            "accessories": [],
            "one_pieces": [],
            "other": [],
        }

        for item in items:
            cat = (item.category or "").lower().strip()
            if cat in TOP_CATEGORIES:
                categorized["tops"].append(item)
            elif cat in BOTTOM_CATEGORIES:
                categorized["bottoms"].append(item)
            elif cat in OUTERWEAR_CATEGORIES:
                categorized["outerwear"].append(item)
            elif cat in FOOTWEAR_CATEGORIES:
                categorized["footwear"].append(item)
            elif cat in ACCESSORY_CATEGORIES:
                categorized["accessories"].append(item)
            elif cat in ONE_PIECE_CATEGORIES:
                categorized["one_pieces"].append(item)
            else:
                categorized["other"].append(item)

        return categorized

    @staticmethod
    def get_user_preferences(user_id: Optional[str], db: Session) -> Dict[str, any]:
        if not user_id:
            return {}

        prefs = {
            "styles": [],
            "fit": None,
            "tops_size": None,
            "bottoms_size": None,
            "shoe_size": None,
        }

        try:
            # Query profiles table safely
            row = db.execute(
                text("SELECT preferred_styles, preferred_fit, tops_size, bottoms_size, shoe_size FROM profiles WHERE id = :uid"),
                {"uid": user_id},
            ).mappings().first()

            if row:
                raw_styles = row.get("preferred_styles")
                if raw_styles:
                    try:
                        parsed = json.loads(raw_styles)
                        if isinstance(parsed, list):
                            prefs["styles"] = [str(s).strip() for s in parsed if s]
                    except Exception:
                        prefs["styles"] = [s.strip() for s in str(raw_styles).split(",") if s.strip()]

                prefs["fit"] = row.get("preferred_fit")
                prefs["tops_size"] = row.get("tops_size")
                prefs["bottoms_size"] = row.get("bottoms_size")
                prefs["shoe_size"] = row.get("shoe_size")
        except Exception as e:
            logger.debug("Profile preferences fetch note: %s", str(e))

        return prefs

    @staticmethod
    def calculate_color_score(colors: List[str]) -> Tuple[float, str]:
        cleaned = [c.lower().strip() for c in colors if c]
        if not cleaned:
            return 0.85, "Neutral palette"

        # Check for monochrome
        if len(set(cleaned)) == 1:
            return 0.96, f"Refined monochromatic {cleaned[0].capitalize()} harmony"

        # Check for all neutrals
        if all(c in NEUTRAL_COLORS for c in cleaned):
            return 0.93, "Timeless neutral tone balancing"

        # Check for complementary matches
        c_set = set(cleaned)
        for pair_a, pair_b in COMPLEMENTARY_PAIRS:
            if (c_set & pair_a) and (c_set & pair_b):
                return 0.92, "Harmonious complementary color contrast"

        # Default coordinated palette
        return 0.87, "Coordinated tonal palette"

    @staticmethod
    def generate_styling_explanation(
        occasion: str,
        vibe: str,
        items: List[WardrobeItem],
        color_narrative: str,
    ) -> Tuple[str, List[str]]:
        top = next((i for i in items if (i.category or "").lower() in TOP_CATEGORIES), None)
        bottom = next((i for i in items if (i.category or "").lower() in BOTTOM_CATEGORIES), None)
        outer = next((i for i in items if (i.category or "").lower() in OUTERWEAR_CATEGORIES), None)
        foot = next((i for i in items if (i.category or "").lower() in FOOTWEAR_CATEGORIES), None)
        one_p = next((i for i in items if (i.category or "").lower() in ONE_PIECE_CATEGORIES), None)

        if one_p:
            explanation = (
                f"Anchored by your {one_p.name}, this look creates an effortless one-piece silhouette for {occasion}. "
                f"{color_narrative} delivers a cohesive {vibe.lower()} presence."
            )
        elif top and bottom:
            if outer:
                explanation = (
                    f"Layers the structured silhouette of your {outer.name} over the relaxed profile of your {top.name}, "
                    f"paired with {bottom.name} for balanced proportion. {color_narrative} seamlessly suits {occasion}."
                )
            else:
                explanation = (
                    f"Pairs your {top.name} with {bottom.name} to establish a clean, versatile {vibe.lower()} profile. "
                    f"{color_narrative} provides visual cohesion suited for {occasion}."
                )
        else:
            item_names = ", ".join(i.name for i in items[:2])
            explanation = (
                f"Unites {item_names} into a curated {vibe.lower()} ensemble tailored for {occasion}. "
                f"{color_narrative} ensures a confident, balanced look."
            )

        # Concrete styling tips
        tips = []
        if outer and top:
            tips.append(f"Keep the {outer.name} open or draped to emphasize the neckline of your {top.name}.")
        elif top and bottom:
            tips.append(f"Try a subtle french tuck with your {top.name} into the {bottom.name} to define waistline proportions.")

        if foot:
            tips.append(f"Complete the silhouette with your {foot.name} to anchor the {occasion.lower()} aesthetic.")
        else:
            tips.append(f"Opt for clean, low-profile footwear to keep focus on the clean garment lines.")

        if len(tips) < 2:
            tips.append("Add minimal accessories like a watch or slim pendant for a polished finish.")

        return explanation, tips

    @classmethod
    def generate_outfit_recommendations(
        cls,
        user_id: Optional[str],
        db: Session,
        request: OutfitGenerationRequest,
    ) -> OutfitGenerationResponse:
        occasion = (request.occasion or "Everyday").strip()
        vibe = (request.vibe or "Minimalist").strip()
        instructions = (request.instructions or "").lower().strip()
        exclude_item_ids = set(request.exclude_item_ids or [])
        refine_index = max(0, request.refine_index or 0)

        # 1. Fetch user's wardrobe items
        query = db.query(WardrobeItem)
        if user_id:
            query = query.filter(WardrobeItem.user_id == user_id)
        else:
            query = query.filter(WardrobeItem.user_id.is_(None))

        all_items = query.all()

        # Handle empty wardrobe
        if not all_items:
            return OutfitGenerationResponse(
                status="empty_wardrobe",
                message="Your wardrobe is currently empty. Add your favorite tops, bottoms, and shoes to start generating styled outfits.",
                occasion=occasion,
                vibe=vibe,
                applied_profile_preferences=[],
                missing_categories=["tops", "bottoms", "footwear"],
                outfits=[],
            )

        # 2. Categorize items
        cat_map = cls.categorize_items(all_items)
        tops = cat_map["tops"]
        bottoms = cat_map["bottoms"]
        outerwear = cat_map["outerwear"]
        footwear = cat_map["footwear"]
        accessories = cat_map["accessories"]
        one_pieces = cat_map["one_pieces"]

        # Check for minimum combination viability
        has_two_piece = len(tops) >= 1 and len(bottoms) >= 1
        has_one_piece = len(one_pieces) >= 1

        if not has_two_piece and not has_one_piece:
            missing = []
            if not tops and not one_pieces:
                missing.append("tops")
            if not bottoms and not one_pieces:
                missing.append("bottoms")
            if not footwear:
                missing.append("footwear")

            return OutfitGenerationResponse(
                status="insufficient_items",
                message="You need at least one top and one bottom (or a one-piece dress) to generate complete outfits.",
                occasion=occasion,
                vibe=vibe,
                applied_profile_preferences=[],
                missing_categories=missing,
                outfits=[],
            )

        # 3. Read profile preferences
        prefs = cls.get_user_preferences(user_id, db)
        applied_prefs = []
        if prefs.get("styles"):
            applied_prefs.append(f"Style: {', '.join(prefs['styles'])}")
        if prefs.get("fit"):
            applied_prefs.append(f"Fit: {prefs['fit']}")

        # 4. Fetch existing saved outfits for duplicate/saved tracking
        saved_query = db.query(SavedOutfit)
        if user_id:
            saved_query = saved_query.filter(SavedOutfit.user_id == user_id)
        else:
            saved_query = saved_query.filter(SavedOutfit.user_id.is_(None))
        existing_saved = saved_query.all()

        saved_outfit_map: Dict[frozenset, str] = {}
        for so in existing_saved:
            try:
                ids = json.loads(so.item_ids_json)
                saved_outfit_map[frozenset(ids)] = so.id
            except Exception:
                pass

        # 5. Build candidate combinations
        candidates = []

        # Helper to score an item against occasion, vibe, and instructions
        def score_item(item: WardrobeItem) -> float:
            score = 1.0
            name_lower = (item.name or "").lower()
            cat_lower = (item.category or "").lower()
            color_lower = (item.primary_color or "").lower()

            # Instruction matching
            if instructions:
                words = instructions.split()
                for w in words:
                    if len(w) > 2 and (w in name_lower or w in cat_lower or w in color_lower):
                        score += 0.25

            # Preference alignment
            for pref_style in prefs.get("styles", []):
                if pref_style.lower() in vibe.lower() or pref_style.lower() in name_lower:
                    score += 0.15

            if prefs.get("fit") and getattr(item, "fit", None):
                if str(prefs["fit"]).lower() in str(item.fit).lower():
                    score += 0.10

            return score

        # Generate combinations from tops + bottoms
        for t in tops:
            for b in bottoms:
                combo = [t, b]

                # Match outerwear if occasion or instructions suggest it
                chosen_outer = None
                if outerwear and occasion.lower() in {"smart casual", "formal", "work", "date night", "evening"} or "jacket" in instructions or "layer" in instructions:
                    # Pick best outerwear
                    sorted_outer = sorted(outerwear, key=score_item, reverse=True)
                    if sorted_outer:
                        chosen_outer = sorted_outer[0]
                        combo.append(chosen_outer)

                # Match footwear
                chosen_foot = None
                if footwear:
                    sorted_foot = sorted(footwear, key=score_item, reverse=True)
                    if sorted_foot:
                        chosen_foot = sorted_foot[0]
                        combo.append(chosen_foot)

                # Match accessory
                if accessories and len(accessories) > 0 and len(combo) < 4:
                    combo.append(accessories[0])

                # Evaluate compatibility
                colors = [i.primary_color for i in combo if getattr(i, "primary_color", None)]
                color_score, color_narrative = cls.calculate_color_score(colors)

                base_score = min(0.98, max(0.80, (color_score + (score_item(t) + score_item(b)) / 10.0)))
                candidates.append((combo, base_score, color_narrative))

        # Also support one-pieces
        for op in one_pieces:
            combo = [op]
            if outerwear:
                combo.append(outerwear[0])
            if footwear:
                combo.append(footwear[0])
            if accessories:
                combo.append(accessories[0])

            colors = [i.primary_color for i in combo if getattr(i, "primary_color", None)]
            color_score, color_narrative = cls.calculate_color_score(colors)
            base_score = min(0.98, max(0.82, (color_score + score_item(op) / 8.0)))
            candidates.append((combo, base_score, color_narrative))

        # Sort candidates by compatibility score descending
        candidates.sort(key=lambda c: c[1], reverse=True)

        # 6. Select distinct combinations (ensuring no identical core pairings)
        distinct_combos: List[Tuple[List[WardrobeItem], float, str]] = []
        seen_core_keys: Set[Tuple[str, ...]] = set()

        for combo, score, narrative in candidates:
            item_ids_sorted = tuple(sorted(i.id for i in combo))
            # Core key: primary top & bottom IDs
            core_ids = tuple(sorted(i.id for i in combo if (i.category or "").lower() in (TOP_CATEGORIES | BOTTOM_CATEGORIES | ONE_PIECE_CATEGORIES)))
            if core_ids in seen_core_keys:
                continue

            # Check if combo is in exclude_item_ids filter
            if exclude_item_ids and any(i.id in exclude_item_ids for i in combo):
                continue

            seen_core_keys.add(core_ids)
            distinct_combos.append((combo, score, narrative))

        # If exclusions left too few, fallback without exclusions to preserve usability
        if len(distinct_combos) == 0 and candidates:
            seen_core_keys.clear()
            for combo, score, narrative in candidates:
                core_ids = tuple(sorted(i.id for i in combo if (i.category or "").lower() in (TOP_CATEGORIES | BOTTOM_CATEGORIES | ONE_PIECE_CATEGORIES)))
                if core_ids not in seen_core_keys:
                    seen_core_keys.add(core_ids)
                    distinct_combos.append((combo, score, narrative))

        # 7. Apply refinement index to cycle alternative looks
        total_available = len(distinct_combos)
        take_count = min(3, total_available)
        start_offset = 0
        if total_available > 0 and refine_index > 0:
            start_offset = (refine_index * take_count) % total_available

        selected_combos = distinct_combos[start_offset:start_offset + take_count]
        # Wrap-around if end reached
        if len(selected_combos) < take_count and total_available >= take_count:
            selected_combos += distinct_combos[0:take_count - len(selected_combos)]

        # 8. Build RecommendedOutfit responses
        outfits: List[RecommendedOutfit] = []
        names_for_vibe = {
            "Minimalist": ["Essential Clean Silhouette", "Tonal Foundation Look", "Refined Understated Ensemble"],
            "Streetwear": ["Urban Utility Profile", "Relaxed Streetwear Stride", "Modern Layered Casual"],
            "Smart Casual": ["Sartorial High-Low Mix", "Contemporary Smart Casual", "Elevated Day-to-Night Look"],
            "Formal": ["Polished Formal Standard", "Tailored Elegance", "Classic Structured Attire"],
            "Date Night": ["Chic Evening Pairing", "Subtle Romantic Contrast", "Sleek Dinner Look"],
            "Casual": ["Effortless Off-Duty Look", "Relaxed Weekend Silhouette", "Comfort-First Casual"],
            "Vintage": ["Retro Heritage Palette", "Timeless Vintage Texture", "Classic Nostalgia Look"],
        }
        fallback_names = ["Curated Seasonal Look", "Coordinated Capsule Look", "Dynamic Style Pairing"]
        name_pool = names_for_vibe.get(vibe, fallback_names)

        for idx, (combo, score, narrative) in enumerate(selected_combos):
            outfit_id = f"rec-outfit-{idx + 1}"
            outfit_name = name_pool[idx % len(name_pool)]

            explanation, tips = cls.generate_styling_explanation(occasion, vibe, combo, narrative)
            item_ids = [i.id for i in combo]
            items_response = [_model_to_response(i) for i in combo]

            # Check if this exact combination of items is already saved
            combo_set = frozenset(item_ids)
            saved_id = saved_outfit_map.get(combo_set)

            outfits.append(
                RecommendedOutfit(
                    id=outfit_id,
                    name=outfit_name,
                    occasion=occasion,
                    vibe=vibe,
                    compatibility_score=round(score, 2),
                    explanation=explanation,
                    styling_tips=tips,
                    item_ids=item_ids,
                    items=items_response,
                    is_saved=saved_id is not None,
                    saved_outfit_id=saved_id,
                )
            )

        refine_notice = f" (Iteration {refine_index + 1})" if refine_index > 0 else ""
        return OutfitGenerationResponse(
            status="success",
            message=f"Generated {len(outfits)} tailored outfit options for {occasion} with {vibe} aesthetic{refine_notice}.",
            occasion=occasion,
            vibe=vibe,
            applied_profile_preferences=applied_prefs,
            missing_categories=[],
            outfits=outfits,
        )
