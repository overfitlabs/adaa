import json
from typing import List, Tuple
from app.schemas import (
    DetectedFashionItem,
    WardrobeItemResponse,
    MatchCandidate,
    ItemMatchResult,
    OutfitMatchResponse,
)

# Synonyms and category compatibility
CATEGORY_GROUPS = {
    "tops": ["tops", "shirts", "t-shirts", "sweaters", "hoodies"],
    "shirts": ["shirts", "tops", "blouses", "button-downs"],
    "trousers": ["trousers", "pants", "chinos", "slacks"],
    "jeans": ["jeans", "denim", "trousers", "pants"],
    "jackets": ["jackets", "coats", "blazers", "cardigans", "outerwear"],
    "footwear": ["footwear", "shoes", "sneakers", "boots", "loafers", "heels"],
    "bags": ["bags", "totes", "backpacks", "crossbody", "handbags"],
    "watches": ["watches", "timepieces"],
    "jewelry": ["jewelry", "necklaces", "bracelets", "rings", "earrings"],
    "hats": ["hats", "caps", "beanies"],
    "sunglasses": ["sunglasses", "eyewear", "glasses"],
}

COLOR_HARMONY = {
    "navy": ["navy", "blue", "dark blue", "midnight blue", "indigo"],
    "blue": ["blue", "navy", "light blue", "sky blue", "indigo"],
    "black": ["black", "charcoal", "dark grey", "onyx"],
    "charcoal": ["charcoal", "dark grey", "grey", "black", "slate"],
    "grey": ["grey", "gray", "light grey", "charcoal", "silver"],
    "white": ["white", "off-white", "ivory", "cream"],
    "cream": ["cream", "beige", "ecru", "off-white", "white", "tan"],
    "beige": ["beige", "tan", "khaki", "cream", "sand", "camel"],
    "brown": ["brown", "tan", "chocolate", "caramel", "camel"],
    "green": ["green", "olive", "forest green", "sage", "emerald"],
    "olive": ["olive", "khaki", "sage", "army green", "green"],
}


class MatchingEngine:
    @staticmethod
    def calculate_category_score(target_cat: str, wardrobe_cat: str) -> Tuple[float, bool]:
        t_cat = target_cat.lower().strip()
        w_cat = wardrobe_cat.lower().strip()

        if t_cat == w_cat:
            return 1.0, True

        for _, members in CATEGORY_GROUPS.items():
            if t_cat in members and w_cat in members:
                return 0.85, True

        return 0.0, False

    @staticmethod
    def calculate_color_score(target_color: str, wardrobe_color: str) -> float:
        t_col = target_color.lower().strip()
        w_col = wardrobe_color.lower().strip()

        if t_col == w_col:
            return 1.0

        if t_col in COLOR_HARMONY.get(w_col, []) or w_col in COLOR_HARMONY.get(t_col, []):
            return 0.8

        # Partial substring match (e.g. 'light blue' and 'blue')
        if t_col in w_col or w_col in t_col:
            return 0.75

        return 0.1

    @staticmethod
    def calculate_attribute_score(target: DetectedFashionItem, wardrobe: WardrobeItemResponse) -> Tuple[float, List[str]]:
        reasons = []
        scores = []

        # Sub-category or item name keyword match
        if target.sub_category and wardrobe.sub_category:
            if target.sub_category.lower() in wardrobe.sub_category.lower() or wardrobe.sub_category.lower() in target.sub_category.lower():
                scores.append(1.0)
                reasons.append(f"Matching silhouette: {wardrobe.sub_category}")
            else:
                scores.append(0.5)

        # Pattern match
        t_pattern = (target.attributes.pattern or "").lower()
        w_pattern = (wardrobe.pattern or "").lower()
        if t_pattern and w_pattern:
            if t_pattern == w_pattern:
                scores.append(1.0)
                reasons.append(f"Matching {w_pattern} pattern")
            else:
                scores.append(0.3)

        # Material match
        t_mat = (target.attributes.material or "").lower()
        w_mat = (wardrobe.material or "").lower()
        if t_mat and w_mat:
            if t_mat == w_mat or t_mat in w_mat or w_mat in t_mat:
                scores.append(1.0)
                reasons.append(f"Matching fabric: {w_mat}")
            else:
                scores.append(0.4)

        # Formality match
        t_form = (target.attributes.formality or "").lower()
        w_form = (wardrobe.formality or "").lower()
        if t_form and w_form:
            if t_form == w_form:
                scores.append(1.0)
                reasons.append(f"Consistent {w_form} aesthetic")
            else:
                scores.append(0.5)

        # Fit match
        t_fit = (target.attributes.fit or "").lower()
        w_fit = (wardrobe.fit or "").lower()
        if t_fit and w_fit:
            if t_fit == w_fit:
                scores.append(1.0)
                reasons.append(f"Similar {w_fit} fit")
            else:
                scores.append(0.5)

        if not scores:
            return 0.5, reasons

        avg_score = sum(scores) / len(scores)
        return avg_score, reasons

    @classmethod
    def score_item(
        cls, target: DetectedFashionItem, wardrobe_item: WardrobeItemResponse
    ) -> MatchCandidate:
        cat_score, is_cat_compat = cls.calculate_category_score(
            target.category, wardrobe_item.category
        )
        if not is_cat_compat:
            return MatchCandidate(
                wardrobe_item=wardrobe_item,
                overall_score=0.0,
                category_match=False,
                color_score=0.0,
                attribute_score=0.0,
                is_exact_match=False,
                match_reasons=[],
            )

        color_score = cls.calculate_color_score(
            target.primary_color, wardrobe_item.primary_color
        )
        attr_score, reasons = cls.calculate_attribute_score(target, wardrobe_item)

        if cat_score >= 0.9:
            reasons.insert(0, f"Same garment type ({wardrobe_item.category})")
        if color_score >= 0.8:
            reasons.append(f"Cohesive {wardrobe_item.primary_color} shade")

        # Weighted calculation: Category 45%, Color 30%, Attributes 25%
        overall_score = round(
            (cat_score * 0.45) + (color_score * 0.30) + (attr_score * 0.25), 3
        )

        is_exact = bool(overall_score >= 0.85 and color_score >= 0.8 and cat_score >= 0.9)

        return MatchCandidate(
            wardrobe_item=wardrobe_item,
            overall_score=overall_score,
            category_match=is_cat_compat,
            color_score=color_score,
            attribute_score=attr_score,
            is_exact_match=is_exact,
            match_reasons=reasons,
        )

    @classmethod
    def match_outfit_against_wardrobe(
        cls,
        target_items: List[DetectedFashionItem],
        wardrobe: List[WardrobeItemResponse],
        analysis_id: str = None,
        exact_threshold: float = 0.85,
        approx_threshold: float = 0.45,
    ) -> OutfitMatchResponse:
        item_matches: List[ItemMatchResult] = []
        missing_items: List[DetectedFashionItem] = []
        matched_count = 0

        for target in target_items:
            # Score against all wardrobe items
            candidates: List[MatchCandidate] = []
            for w_item in wardrobe:
                candidate = cls.score_item(target, w_item)
                if candidate.category_match and candidate.overall_score >= approx_threshold:
                    candidates.append(candidate)

            # Sort descending by overall score
            candidates.sort(key=lambda c: c.overall_score, reverse=True)

            if not candidates:
                item_matches.append(
                    ItemMatchResult(
                        target_item=target,
                        status="missing",
                        best_match=None,
                        alternatives=[],
                    )
                )
                missing_items.append(target)
            else:
                best = candidates[0]
                status = "exact_match" if best.overall_score >= exact_threshold else "approximate_match"
                alternatives = candidates[1:4]  # Top 3 alternatives

                item_matches.append(
                    ItemMatchResult(
                        target_item=target,
                        status=status,
                        best_match=best,
                        alternatives=alternatives,
                    )
                )
                matched_count += 1

        total = len(target_items)
        missing_count = len(missing_items)
        completeness = round((matched_count / total * 100.0), 1) if total > 0 else 0.0

        return OutfitMatchResponse(
            analysis_id=analysis_id,
            total_outfit_items=total,
            matched_count=matched_count,
            missing_count=missing_count,
            completeness_percentage=completeness,
            item_matches=item_matches,
            missing_items=missing_items,
        )


matching_engine = MatchingEngine()
