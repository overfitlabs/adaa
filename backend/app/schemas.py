from datetime import datetime
from typing import List, Optional, Any
from pydantic import BaseModel, Field, ConfigDict, model_validator


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
    box_2d: Optional[List[int]] = Field(
        None, description="Bounding box [ymin, xmin, ymax, xmax] normalized to 0-1000"
    )
    extracted_image_path: Optional[str] = Field(
        None, description="Stored path or public_id of the isolated garment image"
    )
    extracted_image_url: Optional[str] = Field(
        None, description="Delivery URL to the isolated garment image"
    )


class OutfitAnalysisResponse(BaseModel):
    analysis_id: str
    image_url: str
    summary: str
    vibe_or_style: Optional[str] = None
    items: List[DetectedFashionItem] = Field(default_factory=list)
    detected_garment_count: int = 0
    created_at: datetime
    user_id: Optional[str] = None
    status: str = "completed"
    error: Optional[str] = None


class ScanStatusResponse(BaseModel):
    scan_id: str
    status: str  # "pending", "processing", "completed", "failed"
    result: Optional[OutfitAnalysisResponse] = None
    error: Optional[str] = None
    created_at: Optional[datetime] = None


class MediaFlowsWebhookPayload(BaseModel):
    model_config = ConfigDict(extra="allow")

    scan_id: Optional[str] = None
    public_id: Optional[str] = None
    gemini_output: Optional[Any] = None
    status: Optional[str] = None
    error: Optional[str] = None


class MediaFlowsUrlResponse(BaseModel):
    url: str
    image_url: str
    signed_url: str
    public_id: str
    scan_id: str
    expires_in: int = 300


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
    brand: Optional[str] = None
    size: Optional[str] = None
    condition: Optional[str] = None
    notes: Optional[str] = None
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
    brand: Optional[str] = None
    size: Optional[str] = None
    condition: Optional[str] = None
    notes: Optional[str] = None
    tags: Optional[List[str]] = None


class WardrobeItemResponse(WardrobeItemBase):
    id: str
    user_id: Optional[str] = None
    image_path: str
    image_url: str
    storage_provider: Optional[str] = "local"
    is_community_shared: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BulkWardrobeItemCreateItem(WardrobeItemBase):
    client_id: Optional[str] = Field(None, description="Client-side ID for deduplication and tracking")
    image_path: Optional[str] = Field(None, description="Extracted garment image path or public_id")
    extracted_image_url: Optional[str] = Field(None, description="Delivery URL to extracted garment image")


class BulkWardrobeItemsRequest(BaseModel):
    items: List[BulkWardrobeItemCreateItem] = Field(..., min_length=1, max_length=50)
    source_analysis_id: Optional[str] = Field(None, description="Optional source inspiration analysis ID")


class BulkWardrobeItemResult(BaseModel):
    client_id: Optional[str] = None
    success: bool
    item: Optional[WardrobeItemResponse] = None
    error: Optional[str] = None


class BulkWardrobeItemsResponse(BaseModel):
    saved_count: int
    failed_count: int
    results: List[BulkWardrobeItemResult]



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
    expires_at: Optional[datetime] = None
    can_retry: bool = False
    is_friend_tryon: bool = False
    used_saved_model: bool = False
    inspiration_analysis_id: Optional[str] = None


class TryOnHistoryResponse(BaseModel):
    items: List[TryOnTaskResponse]
    next_cursor: Optional[str] = None
    has_more: bool = False
    total_count: int = 0


class UserTryOnModelResponse(BaseModel):
    has_model: bool
    model_id: Optional[str] = None
    image_url: Optional[str] = None
    storage_provider: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


# Recommendation Models
class StyleRecommendation(BaseModel):
    title: str
    description: str
    occasion: str
    suggested_item_ids: List[str]
    styling_tips: List[str]
    items: Optional[List[WardrobeItemResponse]] = None


# AI Stylist & Outfit Generation Schemas
class OutfitGenerationRequest(BaseModel):
    occasion: Optional[str] = Field("Everyday", description="Occasion (e.g. Everyday, Smart Casual, Formal, Work, Casual Weekend, Date Night, Athletic, Party)")
    vibe: Optional[str] = Field(None, description="Style or vibe (e.g. Minimalist, Streetwear, Vintage, Classic, Monochromatic, Preppy, Casual)")
    instructions: Optional[str] = Field(None, description="Optional custom styling instructions")
    exclude_item_ids: Optional[List[str]] = Field(default_factory=list, description="Item IDs to exclude for refinement")
    refine_index: Optional[int] = Field(0, description="Refinement iteration index to cycle alternative combinations")


class RecommendedOutfit(BaseModel):
    id: str
    name: str
    occasion: str
    vibe: str
    compatibility_score: float = Field(..., ge=0.0, le=1.0)
    explanation: str
    styling_tips: List[str] = Field(default_factory=list)
    item_ids: List[str]
    items: List[WardrobeItemResponse]
    is_saved: bool = False
    saved_outfit_id: Optional[str] = None


class OutfitGenerationResponse(BaseModel):
    status: str = Field(..., description="'success', 'empty_wardrobe', or 'insufficient_items'")
    message: str
    occasion: str
    vibe: Optional[str] = None
    applied_profile_preferences: Optional[List[str]] = Field(default_factory=list)
    missing_categories: Optional[List[str]] = Field(default_factory=list)
    outfits: List[RecommendedOutfit] = Field(default_factory=list)


# Stylist Chat Models
class ChatMessage(BaseModel):
    role: str = Field(..., description="'user', 'assistant', or 'system'")
    content: str = Field(..., min_length=1, max_length=2000)


class StylistAction(BaseModel):
    action_type: str = Field(
        ...,
        description="'view_garment', 'open_outfit', 'start_tryon', 'open_scanner', or 'open_wardrobe'",
    )
    title: str = Field(..., description="Human-readable label for the action button")
    payload: Optional[dict] = Field(default_factory=dict, description="Action payload such as item_id, category, outfit_id")


class StylistChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="User message or transcribed voice input")
    history: List[ChatMessage] = Field(default_factory=list, description="Prior conversation turns for context")


class StylistChatResponse(BaseModel):
    reply: str
    domain_status: str = Field("allowed", description="'allowed', 'redirected', or 'clarification'")
    suggested_items: List[WardrobeItemResponse] = Field(default_factory=list)
    suggested_outfits: List[RecommendedOutfit] = Field(default_factory=list)
    suggested_acquisitions: List[str] = Field(default_factory=list)
    actions: List[StylistAction] = Field(default_factory=list)




# Community Schemas
class CommunityBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    description: Optional[str] = None
    is_private: bool = True


class CommunityCreate(CommunityBase):
    pass


class CommunityUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    description: Optional[str] = None
    is_private: Optional[bool] = None


class CommunityMembershipSummary(BaseModel):
    id: str
    role: str
    status: str
    requested_at: datetime
    decided_at: Optional[datetime] = None


class CommunityResponse(CommunityBase):
    id: str
    creator_id: str
    status: str
    created_at: datetime
    updated_at: datetime
    members_count: int = 0
    listings_count: int = 0
    my_membership: Optional[CommunityMembershipSummary] = None

    model_config = ConfigDict(from_attributes=True)


class CommunityMemberResponse(BaseModel):
    id: str
    community_id: str
    user_id: str
    role: str  # owner, admin, member
    status: str  # requested, approved, rejected, removed
    requested_at: datetime
    decided_at: Optional[datetime] = None
    decided_by_id: Optional[str] = None
    created_at: datetime
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class MemberRoleUpdate(BaseModel):
    role: str = Field(..., description="owner, admin, or member")


# Community Listing Schemas
class CommunityListingCreate(BaseModel):
    wardrobe_item_id: str
    notes: Optional[str] = None


class CommunityListingResponse(BaseModel):
    id: str
    community_id: str
    community_name: Optional[str] = None
    wardrobe_item_id: str
    owner_id: str
    owner_name: Optional[str] = None
    owner_avatar_url: Optional[str] = None
    owner_bio: Optional[str] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    item: Optional[WardrobeItemResponse] = None

    model_config = ConfigDict(from_attributes=True)


class SharedClosetItemResponse(BaseModel):
    listing_id: str
    community_id: str
    community_name: str
    owner_id: str
    owner_name: Optional[str] = None
    owner_avatar_url: Optional[str] = None
    owner_bio: Optional[str] = None
    status: str
    notes: Optional[str] = None
    created_at: datetime
    item: WardrobeItemResponse

    model_config = ConfigDict(from_attributes=True)


# Item-level Borrowing Request Schemas
class ItemRequestCreate(BaseModel):
    message: Optional[str] = Field(None, max_length=500, description="Optional note to the owner")
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None

    @model_validator(mode="after")
    def validate_dates(self) -> "ItemRequestCreate":
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValueError("Start date cannot be after end date.")
        return self


class ItemRequestStatusUpdate(BaseModel):
    status: str = Field(..., description="accepted, declined, cancelled, or completed")


class ItemRequestResponse(BaseModel):
    id: str
    listing_id: str
    wardrobe_item_id: str
    community_id: str
    community_name: Optional[str] = None
    requester_id: str
    requester_name: Optional[str] = None
    requester_avatar_url: Optional[str] = None
    owner_id: str
    owner_name: Optional[str] = None
    owner_avatar_url: Optional[str] = None
    status: str
    message: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    responded_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    item: Optional[WardrobeItemResponse] = None

    model_config = ConfigDict(from_attributes=True)


# User Profile Schemas
class FitPreferences(BaseModel):
    tops_size: Optional[str] = None
    bottoms_size: Optional[str] = None
    shoe_size: Optional[str] = None
    preferred_fit: Optional[str] = None  # slim, regular, relaxed, oversized

    model_config = ConfigDict(from_attributes=True)


class ProfilePrivacySettings(BaseModel):
    show_profile_photo: bool = True
    show_bio: bool = True
    show_age: bool = False
    show_phone: bool = False
    show_email: bool = False
    show_fit_preferences: bool = False
    show_preferred_styles: bool = True

    model_config = ConfigDict(from_attributes=True)


class ProfilePrivacyUpdate(BaseModel):
    show_profile_photo: Optional[bool] = None
    show_bio: Optional[bool] = None
    show_age: Optional[bool] = None
    show_phone: Optional[bool] = None
    show_email: Optional[bool] = None
    show_fit_preferences: Optional[bool] = None
    show_preferred_styles: Optional[bool] = None


class UserProfileUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=60, description="User public display name")
    bio: Optional[str] = Field(None, max_length=280, description="Short user bio")
    avatar_url: Optional[str] = Field(None, max_length=500, description="Avatar image URL")
    age: Optional[int] = Field(None, ge=13, le=120, description="User age in years")
    phone_number: Optional[str] = Field(None, max_length=40, description="Contact phone number")
    tops_size: Optional[str] = Field(None, max_length=30)
    bottoms_size: Optional[str] = Field(None, max_length=30)
    shoe_size: Optional[str] = Field(None, max_length=30)
    preferred_fit: Optional[str] = Field(None, max_length=30)
    fit_preferences: Optional[FitPreferences] = None
    preferred_styles: Optional[List[str]] = None
    privacy_settings: Optional[ProfilePrivacyUpdate] = None


class MyUserProfileResponse(BaseModel):
    id: str
    email: str
    display_name: str
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    age: Optional[int] = None
    phone_number: Optional[str] = None
    fit_preferences: Optional[FitPreferences] = None
    preferred_styles: List[str] = Field(default_factory=list)
    privacy_settings: ProfilePrivacySettings = Field(default_factory=ProfilePrivacySettings)
    shared_communities_count: int = 0
    shared_items_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class PublicUserProfileResponse(BaseModel):
    id: str
    display_name: str
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    age: Optional[int] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    fit_preferences: Optional[FitPreferences] = None
    preferred_styles: Optional[List[str]] = None
    shared_communities_count: int = 0
    shared_items_count: int = 0

    model_config = ConfigDict(from_attributes=True)


# Notification Models
class NotificationResponse(BaseModel):
    id: str
    user_id: str
    actor_id: Optional[str] = None
    actor_name: Optional[str] = None
    event_type: str
    title: str
    message: str
    reference_id: Optional[str] = None
    reference_type: Optional[str] = None
    community_id: Optional[str] = None
    is_read: bool = False
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class NotificationUnreadCountResponse(BaseModel):
    unread_count: int


class MarkAllNotificationsReadResponse(BaseModel):
    marked_count: int


