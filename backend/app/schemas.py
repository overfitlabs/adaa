from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict


# Garment / Item Models
class StyleAttributes(BaseModel):
    pattern: Optional[str] = Field(None, description="e.g. solid, striped, floral, plaid, checkered")
    material: Optional[str] = Field(None, description="e.g. denim, cotton, wool, leather, linen, silk")
    fit: Optional[str] = Field(None, description="e.g. slim, relaxed, oversized, tailored, skinny, regular")
    formality: Optional[str] = Field(None, description="e.g. casual, smart-casual, formal, athleisure")
    season: Optional[str] = Field(None, description="e.g. summer, winter, fall, spring, all-season")
    neckline_or_collar: Optional[str] = Field(None, description="e.g. crew neck, v-neck, spread collar, hoodie")


class DetectedFashionItem(BaseModel):
    id: str = Field(..., description="Unique temporary or persisted ID for the detected item")
    category: str = Field(
        ...,
        description="Category: tops, shirts, trousers, jeans, jackets, footwear, bags, watches, jewelry, hats, sunglasses, other",
    )
    sub_category: Optional[str] = Field(None, description="e.g. bomber jacket, chelsea boots, tote bag")
    name: str = Field(..., description="Concise descriptive title, e.g. 'Oversized Navy Wool Blazer'")
    primary_color: str = Field(..., description="Main recognizable color")
    secondary_color: Optional[str] = Field(None, description="Accent or secondary color")
    attributes: StyleAttributes = Field(default_factory=StyleAttributes)
    confidence: float = Field(default=0.9, ge=0.0, le=1.0)
    bounding_box_description: Optional[str] = Field(
        None, description="Position description, e.g. 'Upper body outer layer'"
    )


class OutfitAnalysisResponse(BaseModel):
    analysis_id: str
    image_url: str
    summary: str
    vibe_or_style: str
    items: List[DetectedFashionItem]
    detected_garment_count: int
    created_at: datetime


# Wardrobe Models
class WardrobeItemBase(BaseModel):
    name: str
    category: str
    sub_category: Optional[str] = None
    primary_color: str
    secondary_color: Optional[str] = None
    pattern: Optional[str] = None
    material: Optional[str] = None
    fit: Optional[str] = None
    season: Optional[str] = None
    formality: Optional[str] = None
    tags: List[str] = Field(default_factory=list)


class WardrobeItemCreate(WardrobeItemBase):
    pass


class WardrobeItemUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    sub_category: Optional[str] = None
    primary_color: Optional[str] = None
    secondary_color: Optional[str] = None
    pattern: Optional[str] = None
    material: Optional[str] = None
    fit: Optional[str] = None
    season: Optional[str] = None
    formality: Optional[str] = None
    tags: Optional[List[str]] = None


class WardrobeItemResponse(WardrobeItemBase):
    id: str
    image_path: str
    image_url: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Matching Models
class MatchCandidate(BaseModel):
    wardrobe_item: WardrobeItemResponse
    overall_score: float = Field(..., ge=0.0, le=1.0, description="Match score from 0.0 to 1.0")
    category_match: bool
    color_score: float = Field(..., ge=0.0, le=1.0)
    attribute_score: float = Field(..., ge=0.0, le=1.0)
    is_exact_match: bool = Field(
        ..., description="True if category and color and major attributes strongly match (>=0.85)"
    )
    match_reasons: List[str] = Field(default_factory=list)


class ItemMatchResult(BaseModel):
    target_item: DetectedFashionItem
    status: str = Field(
        ..., description="'exact_match' | 'approximate_match' | 'missing'"
    )
    best_match: Optional[MatchCandidate] = None
    alternatives: List[MatchCandidate] = Field(default_factory=list)


class OutfitMatchResponse(BaseModel):
    analysis_id: Optional[str] = None
    total_outfit_items: int
    matched_count: int
    missing_count: int
    completeness_percentage: float
    item_matches: List[ItemMatchResult]
    missing_items: List[DetectedFashionItem]


class MatchRequest(BaseModel):
    items: List[DetectedFashionItem]
    analysis_id: Optional[str] = None


# Saved Outfits Models
class SavedOutfitCreate(BaseModel):
    name: str
    occasion: Optional[str] = None
    notes: Optional[str] = None
    item_ids: List[str]
    inspiration_analysis_id: Optional[str] = None


class SavedOutfitResponse(BaseModel):
    id: str
    name: str
    occasion: Optional[str] = None
    notes: Optional[str] = None
    image_path: Optional[str] = None
    item_ids: List[str]
    items: List[WardrobeItemResponse] = Field(default_factory=list)
    inspiration_analysis_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Virtual Try-On Models
class TryOnTaskCreate(BaseModel):
    user_image_path: Optional[str] = None
    garment_image_path: Optional[str] = None
    garment_category: Optional[str] = "upper body"  # upper body, lower body, full body, dress, outer


class TryOnTaskResponse(BaseModel):
    task_id: str
    status: str  # pending, processing, success, failed
    provider: str
    user_image_url: str
    garment_image_url: str
    result_image_url: Optional[str] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime


# Recommendation Models
class StyleRecommendation(BaseModel):
    title: str
    description: str
    occasion: str
    suggested_item_ids: List[str]
    styling_tips: List[str]
