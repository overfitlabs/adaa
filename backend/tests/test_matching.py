from datetime import datetime
from app.schemas import DetectedFashionItem, StyleAttributes, WardrobeItemResponse
from app.services.matching_engine import matching_engine


def make_wardrobe_item(
    id: str,
    name: str,
    category: str,
    primary_color: str,
    sub_category: str = None,
    material: str = None,
    fit: str = None,
    formality: str = None,
) -> WardrobeItemResponse:
    return WardrobeItemResponse(
        id=id,
        name=name,
        category=category,
        sub_category=sub_category,
        primary_color=primary_color,
        material=material,
        fit=fit,
        formality=formality,
        image_path="wardrobe/dummy.jpg",
        image_url="/storage/wardrobe/dummy.jpg",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        tags=[],
    )


def test_matching_engine_exact_match():
    target = DetectedFashionItem(
        id="target-1",
        category="jackets",
        sub_category="Blazer",
        name="Navy Wool Tailored Blazer",
        primary_color="Navy",
        attributes=StyleAttributes(
            material="wool", fit="tailored", formality="smart-casual", pattern="solid"
        ),
        confidence=0.95,
    )

    wardrobe = [
        make_wardrobe_item(
            id="w-1",
            name="Navy Wool Tailored Blazer",
            category="jackets",
            sub_category="Blazer",
            primary_color="Navy",
            material="wool",
            fit="tailored",
            formality="smart-casual",
        ),
        make_wardrobe_item(
            id="w-2",
            name="Black Leather Jacket",
            category="jackets",
            sub_category="Biker Jacket",
            primary_color="Black",
            material="leather",
        ),
    ]

    result = matching_engine.match_outfit_against_wardrobe([target], wardrobe)
    assert result.total_outfit_items == 1
    assert result.matched_count == 1
    assert result.missing_count == 0
    assert result.completeness_percentage == 100.0

    match_res = result.item_matches[0]
    assert match_res.status == "exact_match"
    assert match_res.best_match.wardrobe_item.id == "w-1"
    assert match_res.best_match.overall_score >= 0.85
    assert len(match_res.alternatives) == 1
    assert match_res.alternatives[0].wardrobe_item.id == "w-2"


def test_matching_engine_missing_item():
    target = DetectedFashionItem(
        id="target-shoes",
        category="footwear",
        sub_category="Loafers",
        name="Burgundy Leather Loafers",
        primary_color="Burgundy",
        confidence=0.9,
    )

    # Wardrobe has no footwear
    wardrobe = [
        make_wardrobe_item(
            id="w-1",
            name="Navy Blazer",
            category="jackets",
            primary_color="Navy",
        )
    ]

    result = matching_engine.match_outfit_against_wardrobe([target], wardrobe)
    assert result.total_outfit_items == 1
    assert result.matched_count == 0
    assert result.missing_count == 1
    assert result.completeness_percentage == 0.0

    match_res = result.item_matches[0]
    assert match_res.status == "missing"
    assert match_res.best_match is None
    assert len(result.missing_items) == 1
