import json
import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.models import CommunityListing, CommunityMembership
from app.schemas import (
    FitPreferences,
    MyUserProfileResponse,
    ProfilePrivacySettings,
    ProfilePrivacyUpdate,
    PublicUserProfileResponse,
    UserProfileUpdate,
)
from app.services.image_storage import image_storage_service

logger = logging.getLogger("wardrobelens.routes_users")

router = APIRouter(prefix="/api/users", tags=["User Profiles"])


def _ensure_profiles_table(db: Session):
    """Ensures fallback profiles table exists with full schema in SQLite test environments."""
    if db.bind and db.bind.dialect.name == "sqlite":
        db.execute(text("""
            CREATE TABLE IF NOT EXISTS profiles (
                id VARCHAR(36) PRIMARY KEY,
                email TEXT,
                full_name TEXT,
                avatar_url TEXT,
                bio TEXT,
                age INTEGER,
                phone_number TEXT,
                tops_size VARCHAR(30),
                bottoms_size VARCHAR(30),
                shoe_size VARCHAR(30),
                preferred_fit VARCHAR(30),
                preferred_styles TEXT DEFAULT '[]',
                show_profile_photo BOOLEAN NOT NULL DEFAULT 1,
                show_bio BOOLEAN NOT NULL DEFAULT 1,
                show_age BOOLEAN NOT NULL DEFAULT 0,
                show_phone BOOLEAN NOT NULL DEFAULT 0,
                show_email BOOLEAN NOT NULL DEFAULT 0,
                show_fit_preferences BOOLEAN NOT NULL DEFAULT 0,
                show_preferred_styles BOOLEAN NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        columns_to_check = [
            ("age", "INTEGER"),
            ("phone_number", "TEXT"),
            ("tops_size", "VARCHAR(30)"),
            ("bottoms_size", "VARCHAR(30)"),
            ("shoe_size", "VARCHAR(30)"),
            ("preferred_fit", "VARCHAR(30)"),
            ("preferred_styles", "TEXT DEFAULT '[]'"),
            ("show_profile_photo", "BOOLEAN NOT NULL DEFAULT 1"),
            ("show_bio", "BOOLEAN NOT NULL DEFAULT 1"),
            ("show_age", "BOOLEAN NOT NULL DEFAULT 0"),
            ("show_phone", "BOOLEAN NOT NULL DEFAULT 0"),
            ("show_email", "BOOLEAN NOT NULL DEFAULT 0"),
            ("show_fit_preferences", "BOOLEAN NOT NULL DEFAULT 0"),
            ("show_preferred_styles", "BOOLEAN NOT NULL DEFAULT 1"),
        ]
        for col_name, col_type in columns_to_check:
            try:
                db.execute(text(f"ALTER TABLE profiles ADD COLUMN {col_name} {col_type}"))
            except Exception:
                pass
        db.commit()


def _fetch_profile(db: Session, user_id: str) -> Optional[dict]:
    _ensure_profiles_table(db)
    q = text("""
        SELECT id, email, full_name, avatar_url, bio, age, phone_number,
               tops_size, bottoms_size, shoe_size, preferred_fit, preferred_styles,
               show_profile_photo, show_bio, show_age, show_phone, show_email,
               show_fit_preferences, show_preferred_styles
        FROM profiles WHERE id = :uid
    """)
    row = db.execute(q, {"uid": user_id}).mappings().first()
    return dict(row) if row else None


def _get_or_create_profile_dict(db: Session, user: AuthenticatedUser) -> dict:
    prof = _fetch_profile(db, user.id)
    if not prof:
        insert_q = text("""
            INSERT INTO profiles (
                id, email, full_name, show_profile_photo, show_bio,
                show_age, show_phone, show_email, show_fit_preferences, show_preferred_styles
            ) VALUES (
                :uid, :email, :fn, 1, 1, 0, 0, 0, 0, 1
            )
        """)
        db.execute(insert_q, {
            "uid": user.id,
            "email": user.email,
            "fn": user.email.split("@")[0] if user.email else "Member",
        })
        db.commit()
        prof = _fetch_profile(db, user.id)
    return prof or {}


def _build_my_profile_response(prof: dict, comm_count: int, items_count: int) -> MyUserProfileResponse:
    fit_prefs = None
    if prof.get("tops_size") or prof.get("bottoms_size") or prof.get("shoe_size") or prof.get("preferred_fit"):
        fit_prefs = FitPreferences(
            tops_size=prof.get("tops_size"),
            bottoms_size=prof.get("bottoms_size"),
            shoe_size=prof.get("shoe_size"),
            preferred_fit=prof.get("preferred_fit"),
        )

    preferred_styles_list: List[str] = []
    raw_styles = prof.get("preferred_styles")
    if raw_styles:
        try:
            parsed = json.loads(raw_styles) if isinstance(raw_styles, str) else raw_styles
            if isinstance(parsed, list):
                preferred_styles_list = [str(s) for s in parsed]
        except Exception:
            preferred_styles_list = []

    privacy = ProfilePrivacySettings(
        show_profile_photo=bool(prof.get("show_profile_photo", True)),
        show_bio=bool(prof.get("show_bio", True)),
        show_age=bool(prof.get("show_age", False)),
        show_phone=bool(prof.get("show_phone", False)),
        show_email=bool(prof.get("show_email", False)),
        show_fit_preferences=bool(prof.get("show_fit_preferences", False)),
        show_preferred_styles=bool(prof.get("show_preferred_styles", True)),
    )

    email = prof.get("email") or ""
    display_name = prof.get("full_name") or (email.split("@")[0] if email else "Member")

    return MyUserProfileResponse(
        id=str(prof.get("id")),
        email=email,
        display_name=display_name,
        avatar_url=prof.get("avatar_url"),
        bio=prof.get("bio"),
        age=prof.get("age"),
        phone_number=prof.get("phone_number"),
        fit_preferences=fit_prefs,
        preferred_styles=preferred_styles_list,
        privacy_settings=privacy,
        shared_communities_count=comm_count,
        shared_items_count=items_count,
    )


@router.get("/me", response_model=MyUserProfileResponse)
def get_my_profile(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve full authenticated user profile, fit preferences, and current privacy settings.
    The owner can always see and edit their complete profile.
    """
    prof = _get_or_create_profile_dict(db, current_user)

    comm_count = (
        db.query(func.count(CommunityMembership.community_id))
        .filter(
            CommunityMembership.user_id == current_user.id,
            CommunityMembership.status == "approved",
        )
        .scalar()
        or 0
    )

    items_count = (
        db.query(func.count(CommunityListing.id))
        .filter(
            CommunityListing.owner_id == current_user.id,
            CommunityListing.status == "active",
        )
        .scalar()
        or 0
    )

    return _build_my_profile_response(prof, comm_count, items_count)


@router.patch("/me/profile", response_model=MyUserProfileResponse)
def update_my_profile(
    body: UserProfileUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Self-service profile and sizing preferences update for authenticated user.
    Never accepts a target user ID in the payload.
    Treats Supabase Auth email as the immutable account email (does not silently change credentials).
    """
    _get_or_create_profile_dict(db, current_user)
    updates = {}

    if body.display_name is not None:
        trimmed = body.display_name.strip()
        if trimmed:
            updates["full_name"] = trimmed
    if body.bio is not None:
        updates["bio"] = body.bio.strip() if body.bio.strip() else None
    if body.avatar_url is not None:
        updates["avatar_url"] = body.avatar_url.strip() if body.avatar_url.strip() else None
    if body.age is not None:
        updates["age"] = body.age
    if body.phone_number is not None:
        updates["phone_number"] = body.phone_number.strip() if body.phone_number.strip() else None
    if body.tops_size is not None:
        updates["tops_size"] = body.tops_size.strip() if body.tops_size.strip() else None
    if body.bottoms_size is not None:
        updates["bottoms_size"] = body.bottoms_size.strip() if body.bottoms_size.strip() else None
    if body.shoe_size is not None:
        updates["shoe_size"] = body.shoe_size.strip() if body.shoe_size.strip() else None
    if body.preferred_fit is not None:
        updates["preferred_fit"] = body.preferred_fit.strip() if body.preferred_fit.strip() else None
    if body.preferred_styles is not None:
        updates["preferred_styles"] = json.dumps(body.preferred_styles)

    if body.privacy_settings is not None:
        ps = body.privacy_settings
        if ps.show_profile_photo is not None:
            updates["show_profile_photo"] = 1 if ps.show_profile_photo else 0
        if ps.show_bio is not None:
            updates["show_bio"] = 1 if ps.show_bio else 0
        if ps.show_age is not None:
            updates["show_age"] = 1 if ps.show_age else 0
        if ps.show_phone is not None:
            updates["show_phone"] = 1 if ps.show_phone else 0
        if ps.show_email is not None:
            updates["show_email"] = 1 if ps.show_email else 0
        if ps.show_fit_preferences is not None:
            updates["show_fit_preferences"] = 1 if ps.show_fit_preferences else 0
        if ps.show_preferred_styles is not None:
            updates["show_preferred_styles"] = 1 if ps.show_preferred_styles else 0

    if updates:
        try:
            set_clauses = [f"{k} = :{k}" for k in updates.keys()]
            set_clauses.append("updated_at = CURRENT_TIMESTAMP")
            q = text(f"UPDATE profiles SET {', '.join(set_clauses)} WHERE id = :uid")
            params = dict(updates)
            params["uid"] = current_user.id
            db.execute(q, params)
            db.commit()
        except Exception as e:
            db.rollback()
            logger.error("Failed to update profile: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile.",
            )

    prof = _fetch_profile(db, current_user.id) or {}
    comm_count = (
        db.query(func.count(CommunityMembership.community_id))
        .filter(
            CommunityMembership.user_id == current_user.id,
            CommunityMembership.status == "approved",
        )
        .scalar()
        or 0
    )
    items_count = (
        db.query(func.count(CommunityListing.id))
        .filter(
            CommunityListing.owner_id == current_user.id,
            CommunityListing.status == "active",
        )
        .scalar()
        or 0
    )

    return _build_my_profile_response(prof, comm_count, items_count)


@router.get("/me/privacy", response_model=ProfilePrivacySettings)
def get_my_privacy_settings(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve field-level privacy settings for current user."""
    prof = _get_or_create_profile_dict(db, current_user)
    return ProfilePrivacySettings(
        show_profile_photo=bool(prof.get("show_profile_photo", True)),
        show_bio=bool(prof.get("show_bio", True)),
        show_age=bool(prof.get("show_age", False)),
        show_phone=bool(prof.get("show_phone", False)),
        show_email=bool(prof.get("show_email", False)),
        show_fit_preferences=bool(prof.get("show_fit_preferences", False)),
        show_preferred_styles=bool(prof.get("show_preferred_styles", True)),
    )


@router.patch("/me/privacy", response_model=ProfilePrivacySettings)
def update_my_privacy_settings(
    body: ProfilePrivacyUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update field-level privacy settings for current user."""
    _get_or_create_profile_dict(db, current_user)
    updates = {}

    if body.show_profile_photo is not None:
        updates["show_profile_photo"] = 1 if body.show_profile_photo else 0
    if body.show_bio is not None:
        updates["show_bio"] = 1 if body.show_bio else 0
    if body.show_age is not None:
        updates["show_age"] = 1 if body.show_age else 0
    if body.show_phone is not None:
        updates["show_phone"] = 1 if body.show_phone else 0
    if body.show_email is not None:
        updates["show_email"] = 1 if body.show_email else 0
    if body.show_fit_preferences is not None:
        updates["show_fit_preferences"] = 1 if body.show_fit_preferences else 0
    if body.show_preferred_styles is not None:
        updates["show_preferred_styles"] = 1 if body.show_preferred_styles else 0

    if updates:
        try:
            set_clauses = [f"{k} = :{k}" for k in updates.keys()]
            set_clauses.append("updated_at = CURRENT_TIMESTAMP")
            q = text(f"UPDATE profiles SET {', '.join(set_clauses)} WHERE id = :uid")
            params = dict(updates)
            params["uid"] = current_user.id
            db.execute(q, params)
            db.commit()
        except Exception as e:
            db.rollback()
            logger.error("Failed to update privacy settings: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update privacy settings.",
            )

    prof = _fetch_profile(db, current_user.id) or {}
    return ProfilePrivacySettings(
        show_profile_photo=bool(prof.get("show_profile_photo", True)),
        show_bio=bool(prof.get("show_bio", True)),
        show_age=bool(prof.get("show_age", False)),
        show_phone=bool(prof.get("show_phone", False)),
        show_email=bool(prof.get("show_email", False)),
        show_fit_preferences=bool(prof.get("show_fit_preferences", False)),
        show_preferred_styles=bool(prof.get("show_preferred_styles", True)),
    )


@router.post("/me/avatar")
async def upload_profile_avatar(
    file: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Secure profile photo upload:
    - Validates file type and size.
    - Strips EXIF metadata to protect location privacy.
    - Stores using authenticated storage with signed delivery URL.
    - Updates avatar_url on user's profile.
    """
    raw_bytes = await file.read()
    clean_bytes, ext, w, h = image_storage_service.validate_and_sanitize_image(file, raw_bytes)

    meta = await image_storage_service.upload(
        user_id=current_user.id,
        subfolder="profiles",
        pre_sanitized=(clean_bytes, ext, w, h),
    )

    if meta.storage_provider == "cloudinary":
        delivery_url = image_storage_service.generate_delivery_url(
            meta.public_id,
            storage_provider="cloudinary",
        )
    else:
        delivery_url = f"/storage/{meta.public_id}"

    _get_or_create_profile_dict(db, current_user)
    db.execute(
        text("UPDATE profiles SET avatar_url = :av, updated_at = CURRENT_TIMESTAMP WHERE id = :uid"),
        {"av": delivery_url, "uid": current_user.id},
    )
    db.commit()

    return {"avatar_url": delivery_url}


@router.get("/{user_id}/public-profile", response_model=PublicUserProfileResponse, response_model_exclude_none=True)
def get_user_public_profile(
    user_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve a safe community-facing public profile for a peer.
    Strict privacy enforcement:
    1. Caller and target user must share at least one approved community (or viewer is self).
       Returns 404 if no shared approved community exists (prevents user enumeration).
    2. Field-level privacy is strictly enforced on the server:
       - Profile photo, bio, age, phone, email, fit preferences, and styles are withheld unless
         expressly made visible by the owner.
       - Private fields evaluate to None and are excluded from JSON response.
       - Display name remains visible for community coordination.
    """
    is_self = user_id == current_user.id
    if not is_self:
        # Check that caller and target user share at least one approved community
        shared_approved_comm_count = (
            db.query(func.count(CommunityMembership.community_id))
            .filter(
                CommunityMembership.user_id == current_user.id,
                CommunityMembership.status == "approved",
                CommunityMembership.community_id.in_(
                    db.query(CommunityMembership.community_id).filter(
                        CommunityMembership.user_id == user_id,
                        CommunityMembership.status == "approved",
                    )
                ),
            )
            .scalar()
            or 0
        )
        if shared_approved_comm_count == 0:
            raise HTTPException(status_code=404, detail="User profile not found.")

    prof = _fetch_profile(db, user_id)
    display_name = (prof.get("full_name") if prof else None) or f"Member ({user_id[:6]})"

    # Count approved communities the target user belongs to
    comm_count = (
        db.query(func.count(CommunityMembership.community_id))
        .filter(
            CommunityMembership.user_id == user_id,
            CommunityMembership.status == "approved",
        )
        .scalar()
        or 0
    )

    # Count active pieces shared by target user in approved communities where caller is also approved
    shared_comm_subquery = (
        db.query(CommunityMembership.community_id)
        .filter(
            CommunityMembership.user_id == current_user.id,
            CommunityMembership.status == "approved",
        )
    )
    items_count = (
        db.query(func.count(CommunityListing.id))
        .filter(
            CommunityListing.owner_id == user_id,
            CommunityListing.status == "active",
            CommunityListing.community_id.in_(shared_comm_subquery),
        )
        .scalar()
        or 0
    )

    if not prof:
        return PublicUserProfileResponse(
            id=user_id,
            display_name=display_name,
            shared_communities_count=comm_count,
            shared_items_count=items_count,
        )

    # Evaluate field-level privacy
    can_view_photo = is_self or bool(prof.get("show_profile_photo", True))
    can_view_bio = is_self or bool(prof.get("show_bio", True))
    can_view_age = is_self or bool(prof.get("show_age", False))
    can_view_phone = is_self or bool(prof.get("show_phone", False))
    can_view_email = is_self or bool(prof.get("show_email", False))
    can_view_fit = is_self or bool(prof.get("show_fit_preferences", False))
    can_view_styles = is_self or bool(prof.get("show_preferred_styles", True))

    avatar_url = prof.get("avatar_url") if can_view_photo else None
    bio = prof.get("bio") if can_view_bio else None
    age = prof.get("age") if can_view_age else None
    phone_number = prof.get("phone_number") if can_view_phone else None
    email = prof.get("email") if can_view_email else None

    fit_prefs = None
    if can_view_fit and (
        prof.get("tops_size") or prof.get("bottoms_size") or prof.get("shoe_size") or prof.get("preferred_fit")
    ):
        fit_prefs = FitPreferences(
            tops_size=prof.get("tops_size"),
            bottoms_size=prof.get("bottoms_size"),
            shoe_size=prof.get("shoe_size"),
            preferred_fit=prof.get("preferred_fit"),
        )

    preferred_styles_list: Optional[List[str]] = None
    raw_styles = prof.get("preferred_styles")
    if can_view_styles and raw_styles:
        try:
            parsed = json.loads(raw_styles) if isinstance(raw_styles, str) else raw_styles
            if isinstance(parsed, list) and parsed:
                preferred_styles_list = [str(s) for s in parsed]
        except Exception:
            preferred_styles_list = None

    return PublicUserProfileResponse(
        id=user_id,
        display_name=display_name,
        avatar_url=avatar_url,
        bio=bio,
        age=age,
        phone_number=phone_number,
        email=email,
        fit_preferences=fit_prefs,
        preferred_styles=preferred_styles_list,
        shared_communities_count=comm_count,
        shared_items_count=items_count,
    )
