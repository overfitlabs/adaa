import json
import logging
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.models import (
    Community,
    CommunityListing,
    CommunityMembership,
    WardrobeItem,
)
from app.schemas import (
    CommunityCreate,
    CommunityListingCreate,
    CommunityListingResponse,
    CommunityMemberResponse,
    CommunityMembershipSummary,
    CommunityResponse,
    MemberRoleUpdate,
    SharedClosetItemResponse,
    WardrobeItemResponse,
)
from app.services.image_storage import image_storage_service

logger = logging.getLogger("wardrobelens.routes_communities")

router = APIRouter(prefix="/api/communities", tags=["Communities & Shared Closets"])


def _model_to_item_response(item: WardrobeItem) -> WardrobeItemResponse:
    if getattr(item, "storage_provider", "local") == "cloudinary" and getattr(item, "cloudinary_public_id", None):
        delivery_url = image_storage_service.generate_delivery_url(
            item.cloudinary_public_id,
            storage_provider="cloudinary",
        )
    else:
        delivery_url = f"/storage/{item.image_path}"
    tags_list: List[str] = []
    if item.tags:
        try:
            tags_list = json.loads(item.tags)
        except Exception:
            tags_list = [t.strip() for t in item.tags.split(",") if t.strip()]

    return WardrobeItemResponse(
        id=item.id,
        user_id=item.user_id,
        name=item.name,
        category=item.category,
        sub_category=item.sub_category,
        primary_color=item.primary_color,
        secondary_color=item.secondary_color,
        pattern=item.pattern,
        material=item.material,
        fit=item.fit,
        season=item.season,
        formality=item.formality,
        brand=item.brand,
        size=item.size,
        condition=item.condition,
        notes=item.notes,
        tags=tags_list,
        image_path=item.image_path,
        image_url=delivery_url,
        storage_provider=item.storage_provider,
        is_community_shared=item.is_community_shared,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


def _get_membership(db: Session, community_id: str, user_id: str) -> Optional[CommunityMembership]:
    return (
        db.query(CommunityMembership)
        .filter(
            CommunityMembership.community_id == community_id,
            CommunityMembership.user_id == user_id,
        )
        .first()
    )


def _require_approved_member(db: Session, community_id: str, user_id: str) -> CommunityMembership:
    mem = _get_membership(db, community_id, user_id)
    if not mem or mem.status != "approved":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You must be an approved member of this community.",
        )
    return mem


def _require_admin_or_owner(db: Session, community_id: str, user_id: str) -> CommunityMembership:
    mem = _require_approved_member(db, community_id, user_id)
    if mem.role not in ("admin", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrative privileges required for this action.",
        )
    return mem


def _require_owner(db: Session, community_id: str, user_id: str) -> CommunityMembership:
    mem = _require_approved_member(db, community_id, user_id)
    if mem.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Owner privileges required for this action.",
        )
    return mem


# ============================================================================
# Community Discovery & Creation
# ============================================================================


@router.get("", response_model=List[CommunityResponse])
def discover_communities(
    query: Optional[str] = Query(None, description="Search community name or description"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Discover active communities with member and listing counts,
    including the caller's membership status in each community.
    """
    q = db.query(Community).filter(Community.status == "active")
    if query and query.strip():
        term = f"%{query.strip()}%"
        q = q.filter(or_(Community.name.ilike(term), Community.description.ilike(term)))

    communities = q.order_by(Community.created_at.desc()).offset(offset).limit(limit).all()

    # Pre-fetch memberships for current user
    user_memberships = {
        m.community_id: m
        for m in db.query(CommunityMembership)
        .filter(CommunityMembership.user_id == current_user.id)
        .all()
    }

    results = []
    for comm in communities:
        m_count = (
            db.query(func.count(CommunityMembership.id))
            .filter(
                CommunityMembership.community_id == comm.id,
                CommunityMembership.status == "approved",
            )
            .scalar()
            or 0
        )
        l_count = (
            db.query(func.count(CommunityListing.id))
            .filter(
                CommunityListing.community_id == comm.id,
                CommunityListing.status == "active",
            )
            .scalar()
            or 0
        )

        my_mem = user_memberships.get(comm.id)
        my_mem_summary = None
        if my_mem:
            my_mem_summary = CommunityMembershipSummary(
                id=my_mem.id,
                role=my_mem.role,
                status=my_mem.status,
                requested_at=my_mem.requested_at,
                decided_at=my_mem.decided_at,
            )

        results.append(
            CommunityResponse(
                id=comm.id,
                name=comm.name,
                description=comm.description,
                creator_id=comm.creator_id,
                status=comm.status,
                is_private=comm.is_private,
                created_at=comm.created_at,
                updated_at=comm.updated_at,
                members_count=m_count,
                listings_count=l_count,
                my_membership=my_mem_summary,
            )
        )

    return results


@router.post("", response_model=CommunityResponse, status_code=status.HTTP_201_CREATED)
def create_community(
    body: CommunityCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Create a new community. The creator is atomically made the owner
    with approved membership in a single transaction.
    """
    name_clean = body.name.strip()
    if not name_clean:
        raise HTTPException(status_code=400, detail="Community name cannot be empty.")

    new_comm = Community(
        name=name_clean,
        description=body.description.strip() if body.description else None,
        creator_id=current_user.id,
        is_private=body.is_private,
        status="active",
    )
    db.add(new_comm)
    db.flush()  # assign new_comm.id

    # Add owner membership
    owner_membership = CommunityMembership(
        community_id=new_comm.id,
        user_id=current_user.id,
        role="owner",
        status="approved",
        requested_at=datetime.utcnow(),
        decided_at=datetime.utcnow(),
        decided_by_id=current_user.id,
    )
    db.add(owner_membership)
    db.commit()
    db.refresh(new_comm)

    return CommunityResponse(
        id=new_comm.id,
        name=new_comm.name,
        description=new_comm.description,
        creator_id=new_comm.creator_id,
        status=new_comm.status,
        is_private=new_comm.is_private,
        created_at=new_comm.created_at,
        updated_at=new_comm.updated_at,
        members_count=1,
        listings_count=0,
        my_membership=CommunityMembershipSummary(
            id=owner_membership.id,
            role=owner_membership.role,
            status=owner_membership.status,
            requested_at=owner_membership.requested_at,
            decided_at=owner_membership.decided_at,
        ),
    )


@router.get("/my", response_model=List[CommunityResponse])
def get_my_communities(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    List all communities where the current user holds any membership
    (approved, requested, etc.).
    """
    memberships = (
        db.query(CommunityMembership)
        .filter(CommunityMembership.user_id == current_user.id)
        .all()
    )
    if not memberships:
        return []

    comm_ids = [m.community_id for m in memberships]
    communities = (
        db.query(Community)
        .filter(Community.id.in_(comm_ids), Community.status == "active")
        .all()
    )
    comm_map = {c.id: c for c in communities}

    results = []
    for m in memberships:
        comm = comm_map.get(m.community_id)
        if not comm:
            continue

        m_count = (
            db.query(func.count(CommunityMembership.id))
            .filter(
                CommunityMembership.community_id == comm.id,
                CommunityMembership.status == "approved",
            )
            .scalar()
            or 0
        )
        l_count = (
            db.query(func.count(CommunityListing.id))
            .filter(
                CommunityListing.community_id == comm.id,
                CommunityListing.status == "active",
            )
            .scalar()
            or 0
        )

        results.append(
            CommunityResponse(
                id=comm.id,
                name=comm.name,
                description=comm.description,
                creator_id=comm.creator_id,
                status=comm.status,
                is_private=comm.is_private,
                created_at=comm.created_at,
                updated_at=comm.updated_at,
                members_count=m_count,
                listings_count=l_count,
                my_membership=CommunityMembershipSummary(
                    id=m.id,
                    role=m.role,
                    status=m.status,
                    requested_at=m.requested_at,
                    decided_at=m.decided_at,
                ),
            )
        )

    # Sort approved communities first, then requested
    results.sort(key=lambda c: 0 if c.my_membership and c.my_membership.status == "approved" else 1)
    return results


# ============================================================================
# Cross-Community Shared Closet
# (Declared BEFORE /api/communities/{id} to prevent path conflict!)
# ============================================================================


@router.get("/shared-closet", response_model=List[SharedClosetItemResponse])
def browse_cross_community_shared_closet(
    category: Optional[str] = Query(None, description="Filter by garment category"),
    search: Optional[str] = Query(None, description="Search item name, brand, color, notes"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Browse and search shared clothing across ALL communities where the current
    user holds an approved membership in a single unified feed.
    """
    # 1. Get all community IDs where user is approved
    approved_comm_ids = [
        row[0]
        for row in db.query(CommunityMembership.community_id)
        .filter(
            CommunityMembership.user_id == current_user.id,
            CommunityMembership.status == "approved",
        )
        .all()
    ]

    if not approved_comm_ids:
        return []

    # 2. Query active listings in these approved communities joined with WardrobeItem & Community
    q = (
        db.query(CommunityListing, WardrobeItem, Community)
        .join(WardrobeItem, WardrobeItem.id == CommunityListing.wardrobe_item_id)
        .join(Community, Community.id == CommunityListing.community_id)
        .filter(
            CommunityListing.status == "active",
            CommunityListing.community_id.in_(approved_comm_ids),
        )
    )

    if category and category.strip() and category.lower() != "all":
        q = q.filter(WardrobeItem.category == category.strip().lower())

    if search and search.strip():
        term = f"%{search.strip()}%"
        q = q.filter(
            or_(
                WardrobeItem.name.ilike(term),
                WardrobeItem.brand.ilike(term),
                WardrobeItem.primary_color.ilike(term),
                WardrobeItem.material.ilike(term),
                WardrobeItem.notes.ilike(term),
                CommunityListing.notes.ilike(term),
                Community.name.ilike(term),
            )
        )

    rows = q.order_by(CommunityListing.created_at.desc()).offset(offset).limit(limit).all()

    results = []
    for listing, item, comm in rows:
        results.append(
            SharedClosetItemResponse(
                listing_id=listing.id,
                community_id=comm.id,
                community_name=comm.name,
                owner_id=listing.owner_id,
                status=listing.status,
                notes=listing.notes,
                created_at=listing.created_at,
                item=_model_to_item_response(item),
            )
        )

    return results


# ============================================================================
# Single Community Details & Members
# ============================================================================


@router.get("/{community_id}", response_model=CommunityResponse)
def get_community_detail(
    community_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve single community details with member count, listing count,
    and the caller's membership status.
    """
    comm = db.query(Community).filter(Community.id == community_id).first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found.")

    m_count = (
        db.query(func.count(CommunityMembership.id))
        .filter(
            CommunityMembership.community_id == comm.id,
            CommunityMembership.status == "approved",
        )
        .scalar()
        or 0
    )
    l_count = (
        db.query(func.count(CommunityListing.id))
        .filter(
            CommunityListing.community_id == comm.id,
            CommunityListing.status == "active",
        )
        .scalar()
        or 0
    )

    my_mem = _get_membership(db, comm.id, current_user.id)
    my_mem_summary = None
    if my_mem:
        my_mem_summary = CommunityMembershipSummary(
            id=my_mem.id,
            role=my_mem.role,
            status=my_mem.status,
            requested_at=my_mem.requested_at,
            decided_at=my_mem.decided_at,
        )

    return CommunityResponse(
        id=comm.id,
        name=comm.name,
        description=comm.description,
        creator_id=comm.creator_id,
        status=comm.status,
        is_private=comm.is_private,
        created_at=comm.created_at,
        updated_at=comm.updated_at,
        members_count=m_count,
        listings_count=l_count,
        my_membership=my_mem_summary,
    )


def _resolve_member_profiles(db: Session, user_ids: List[str]) -> dict:
    """
    Safely resolves display names and avatars from public.profiles.
    Never exposes email or sensitive private account details.
    Gracefully handles environments where profiles table is absent (e.g. SQLite test suites).
    """
    if not user_ids:
        return {}
    unique_ids = list(set(user_ids))
    profiles_map = {}
    try:
        from sqlalchemy import text
        placeholders = ", ".join([f":uid_{i}" for i in range(len(unique_ids))])
        params = {f"uid_{i}": uid for i, uid in enumerate(unique_ids)}
        query = text(f"SELECT id, full_name, avatar_url, bio FROM profiles WHERE id IN ({placeholders})")
        rows = db.execute(query, params).mappings().fetchall()
        for r in rows:
            profiles_map[str(r["id"])] = {
                "display_name": r.get("full_name"),
                "avatar_url": r.get("avatar_url"),
                "bio": r.get("bio"),
            }
    except Exception as e:
        logger.debug("Profiles table lookup skipped or not available: %s", str(e))
    return profiles_map


@router.get("/{community_id}/members", response_model=List[CommunityMemberResponse])
def get_community_members(
    community_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    List community members:
    - Approved members can view other approved members.
    - Admins and Owners can view all members including pending requests.
    - Enriches members with public profile identity (display_name, avatar_url, bio).
    """
    comm = db.query(Community).filter(Community.id == community_id).first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found.")

    caller_mem = _require_approved_member(db, community_id, current_user.id)

    q = db.query(CommunityMembership).filter(CommunityMembership.community_id == community_id)
    if caller_mem.role not in ("admin", "owner"):
        # Regular members only see approved members
        q = q.filter(CommunityMembership.status == "approved")

    # Order requested first (for admins to review), then owners, admins, members
    members = q.order_by(
        CommunityMembership.status == "requested",
        CommunityMembership.created_at.asc(),
    ).all()

    # Re-order in Python so requested is at the top
    members.sort(key=lambda m: 0 if m.status == "requested" else 1)

    user_ids = [m.user_id for m in members]
    profiles = _resolve_member_profiles(db, user_ids)

    return [
        CommunityMemberResponse(
            id=m.id,
            community_id=m.community_id,
            user_id=m.user_id,
            role=m.role,
            status=m.status,
            requested_at=m.requested_at,
            decided_at=m.decided_at,
            decided_by_id=m.decided_by_id,
            created_at=m.created_at,
            display_name=profiles.get(m.user_id, {}).get("display_name"),
            avatar_url=profiles.get(m.user_id, {}).get("avatar_url"),
            bio=profiles.get(m.user_id, {}).get("bio"),
        )
        for m in members
    ]


# ============================================================================
# Membership Management (Join, Approve, Reject, Leave, Remove, Role)
# ============================================================================


@router.post("/{community_id}/join", response_model=CommunityMemberResponse)
def request_to_join_community(
    community_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Request to join a community. Idempotent: returns existing membership
    if already approved or requested. Re-requests if previously rejected/removed.
    """
    comm = db.query(Community).filter(Community.id == community_id, Community.status == "active").first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found or inactive.")

    mem = _get_membership(db, community_id, current_user.id)
    if mem:
        if mem.status in ("approved", "requested"):
            return mem
        # If previously rejected or removed, reset to requested
        mem.status = "requested"
        mem.requested_at = datetime.utcnow()
        mem.decided_at = None
        mem.decided_by_id = None
        db.commit()
        db.refresh(mem)
        return mem

    # Create new membership request
    new_mem = CommunityMembership(
        community_id=community_id,
        user_id=current_user.id,
        role="member",
        status="requested",
        requested_at=datetime.utcnow(),
    )
    db.add(new_mem)
    db.commit()
    db.refresh(new_mem)
    return new_mem


@router.get("/{community_id}/membership", response_model=CommunityMemberResponse)
def get_my_membership_status(
    community_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get current user's membership in a specific community.
    """
    mem = _get_membership(db, community_id, current_user.id)
    if not mem:
        raise HTTPException(status_code=404, detail="No membership found for this community.")
    return mem


@router.post("/{community_id}/members/{target_user_id}/approve", response_model=CommunityMemberResponse)
def approve_join_request(
    community_id: str,
    target_user_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Approve a pending membership request. Authorized for community Admins and Owners.
    """
    _require_admin_or_owner(db, community_id, current_user.id)

    target_mem = _get_membership(db, community_id, target_user_id)
    if not target_mem or target_mem.status != "requested":
        raise HTTPException(
            status_code=404,
            detail="Pending membership request not found for this user.",
        )

    target_mem.status = "approved"
    target_mem.decided_at = datetime.utcnow()
    target_mem.decided_by_id = current_user.id
    db.commit()
    db.refresh(target_mem)
    return target_mem


@router.post("/{community_id}/members/{target_user_id}/reject", response_model=CommunityMemberResponse)
def reject_join_request(
    community_id: str,
    target_user_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Reject a pending membership request. Authorized for community Admins and Owners.
    """
    _require_admin_or_owner(db, community_id, current_user.id)

    target_mem = _get_membership(db, community_id, target_user_id)
    if not target_mem or target_mem.status != "requested":
        raise HTTPException(
            status_code=404,
            detail="Pending membership request not found for this user.",
        )

    target_mem.status = "rejected"
    target_mem.decided_at = datetime.utcnow()
    target_mem.decided_by_id = current_user.id
    db.commit()
    db.refresh(target_mem)
    return target_mem


@router.post("/{community_id}/leave")
def leave_community(
    community_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Current user leaves a community.
    - Last Owner Protection: Cannot leave if caller is the last owner.
    - Automatically deactivates caller's active listings in this community.
    """
    mem = _get_membership(db, community_id, current_user.id)
    if not mem or mem.status != "approved":
        raise HTTPException(status_code=400, detail="You are not an active member of this community.")

    # Check last owner protection
    if mem.role == "owner":
        approved_owners_count = (
            db.query(func.count(CommunityMembership.id))
            .filter(
                CommunityMembership.community_id == community_id,
                CommunityMembership.role == "owner",
                CommunityMembership.status == "approved",
            )
            .scalar()
            or 0
        )
        if approved_owners_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot leave as the last remaining owner. Please transfer ownership or assign another owner first.",
            )

    mem.status = "removed"
    mem.decided_at = datetime.utcnow()
    mem.decided_by_id = current_user.id

    # Deactivate active listings in this community
    db.query(CommunityListing).filter(
        CommunityListing.community_id == community_id,
        CommunityListing.owner_id == current_user.id,
        CommunityListing.status == "active",
    ).update({"status": "unlisted"})

    db.commit()
    return {"message": "You have left the community."}


@router.delete("/{community_id}/members/{target_user_id}")
def remove_community_member(
    community_id: str,
    target_user_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Remove a member from the community. Authorized for community Admins and Owners.
    - Admins cannot remove Owners or other Admins.
    - Cannot remove the last remaining owner.
    - Automatically deactivates target's listings in this community.
    """
    caller_mem = _require_admin_or_owner(db, community_id, current_user.id)

    target_mem = _get_membership(db, community_id, target_user_id)
    if not target_mem or target_mem.status != "approved":
        raise HTTPException(status_code=404, detail="Active member not found.")

    if caller_mem.role == "admin" and target_mem.role in ("owner", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Community administrators cannot remove other administrators or owners.",
        )

    # Last owner protection
    if target_mem.role == "owner":
        approved_owners_count = (
            db.query(func.count(CommunityMembership.id))
            .filter(
                CommunityMembership.community_id == community_id,
                CommunityMembership.role == "owner",
                CommunityMembership.status == "approved",
            )
            .scalar()
            or 0
        )
        if approved_owners_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove the last remaining owner of the community.",
            )

    target_mem.status = "removed"
    target_mem.decided_at = datetime.utcnow()
    target_mem.decided_by_id = current_user.id

    # Deactivate target's listings in this community
    db.query(CommunityListing).filter(
        CommunityListing.community_id == community_id,
        CommunityListing.owner_id == target_user_id,
        CommunityListing.status == "active",
    ).update({"status": "unlisted"})

    db.commit()
    return {"message": f"Member {target_user_id} has been removed from the community."}


@router.patch("/{community_id}/members/{target_user_id}/role", response_model=CommunityMemberResponse)
def update_member_role(
    community_id: str,
    target_user_id: str,
    body: MemberRoleUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Change a member's role (owner, admin, member). Only community Owners can change roles.
    - Last Owner Protection: Cannot demote the last owner.
    """
    _require_owner(db, community_id, current_user.id)

    new_role = body.role.strip().lower()
    if new_role not in ("owner", "admin", "member"):
        raise HTTPException(status_code=400, detail="Role must be one of: owner, admin, member.")

    target_mem = _get_membership(db, community_id, target_user_id)
    if not target_mem or target_mem.status != "approved":
        raise HTTPException(status_code=404, detail="Active member not found.")

    if target_mem.role == "owner" and new_role != "owner":
        approved_owners_count = (
            db.query(func.count(CommunityMembership.id))
            .filter(
                CommunityMembership.community_id == community_id,
                CommunityMembership.role == "owner",
                CommunityMembership.status == "approved",
            )
            .scalar()
            or 0
        )
        if approved_owners_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot demote the last remaining owner of the community.",
            )

    target_mem.role = new_role
    db.commit()
    db.refresh(target_mem)
    return target_mem


# ============================================================================
# Community Listings (Shared Closets)
# ============================================================================


@router.get("/{community_id}/listings", response_model=List[CommunityListingResponse])
def get_community_listings(
    community_id: str,
    category: Optional[str] = Query(None, description="Filter by garment category"),
    search: Optional[str] = Query(None, description="Search item name, brand, color, notes"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Browse active shared listings in a specific community.
    Strictly requires approved membership in that community!
    """
    comm = db.query(Community).filter(Community.id == community_id).first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found.")

    _require_approved_member(db, community_id, current_user.id)

    q = (
        db.query(CommunityListing, WardrobeItem)
        .join(WardrobeItem, WardrobeItem.id == CommunityListing.wardrobe_item_id)
        .filter(
            CommunityListing.community_id == community_id,
            CommunityListing.status == "active",
        )
    )

    if category and category.strip() and category.lower() != "all":
        q = q.filter(WardrobeItem.category == category.strip().lower())

    if search and search.strip():
        term = f"%{search.strip()}%"
        q = q.filter(
            or_(
                WardrobeItem.name.ilike(term),
                WardrobeItem.brand.ilike(term),
                WardrobeItem.primary_color.ilike(term),
                WardrobeItem.material.ilike(term),
                WardrobeItem.notes.ilike(term),
                CommunityListing.notes.ilike(term),
            )
        )

    rows = q.order_by(CommunityListing.created_at.desc()).offset(offset).limit(limit).all()

    return [
        CommunityListingResponse(
            id=listing.id,
            community_id=community_id,
            community_name=comm.name,
            wardrobe_item_id=listing.wardrobe_item_id,
            owner_id=listing.owner_id,
            status=listing.status,
            notes=listing.notes,
            created_at=listing.created_at,
            item=_model_to_item_response(item),
        )
        for listing, item in rows
    ]


@router.post("/{community_id}/listings", response_model=CommunityListingResponse, status_code=status.HTTP_201_CREATED)
def list_wardrobe_item_in_community(
    community_id: str,
    body: CommunityListingCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Explicitly list a personal wardrobe item in an approved community.
    Validates that:
    1. Caller is an approved member of the community.
    2. The wardrobe item exists and is owned by the caller.
    3. The item is not already actively listed in this community.
    """
    comm = db.query(Community).filter(Community.id == community_id, Community.status == "active").first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found or inactive.")

    _require_approved_member(db, community_id, current_user.id)

    item = db.query(WardrobeItem).filter(WardrobeItem.id == body.wardrobe_item_id).first()
    if not item or item.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Item not found in your personal wardrobe. You can only list your own clothing items.",
        )

    existing_listing = (
        db.query(CommunityListing)
        .filter(
            CommunityListing.community_id == community_id,
            CommunityListing.wardrobe_item_id == item.id,
        )
        .first()
    )

    if existing_listing:
        if existing_listing.status == "active":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This garment is already actively listed in this community.",
            )
        # Reactivate unlisted item
        existing_listing.status = "active"
        existing_listing.notes = body.notes.strip() if body.notes else existing_listing.notes
        existing_listing.updated_at = datetime.utcnow()
        item.is_community_shared = True
        db.commit()
        db.refresh(existing_listing)
        return CommunityListingResponse(
            id=existing_listing.id,
            community_id=community_id,
            community_name=comm.name,
            wardrobe_item_id=item.id,
            owner_id=existing_listing.owner_id,
            status=existing_listing.status,
            notes=existing_listing.notes,
            created_at=existing_listing.created_at,
            item=_model_to_item_response(item),
        )

    new_listing = CommunityListing(
        community_id=community_id,
        wardrobe_item_id=item.id,
        owner_id=current_user.id,
        status="active",
        notes=body.notes.strip() if body.notes else None,
    )
    item.is_community_shared = True
    db.add(new_listing)
    db.commit()
    db.refresh(new_listing)

    return CommunityListingResponse(
        id=new_listing.id,
        community_id=community_id,
        community_name=comm.name,
        wardrobe_item_id=item.id,
        owner_id=new_listing.owner_id,
        status=new_listing.status,
        notes=new_listing.notes,
        created_at=new_listing.created_at,
        item=_model_to_item_response(item),
    )


@router.delete("/{community_id}/listings/{listing_id}")
def unlist_shared_item(
    community_id: str,
    listing_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Remove an item from a community without deleting it from the user's
    personal wardrobe or other communities.
    - Owner can always unlist their own item.
    - Community Admins and Owners can unlist items for moderation.
    """
    listing = (
        db.query(CommunityListing)
        .filter(
            CommunityListing.id == listing_id,
            CommunityListing.community_id == community_id,
        )
        .first()
    )
    if not listing:
        raise HTTPException(status_code=404, detail="Shared listing not found in this community.")

    # Check permission: item owner OR community admin/owner
    if listing.owner_id != current_user.id:
        caller_mem = _get_membership(db, community_id, current_user.id)
        if not caller_mem or caller_mem.status != "approved" or caller_mem.role not in ("admin", "owner"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to unlist this item.",
            )

    item_id = listing.wardrobe_item_id

    # Delete listing record
    db.delete(listing)
    db.flush()

    # Check if item is listed in any other community
    other_listings_count = (
        db.query(func.count(CommunityListing.id))
        .filter(
            CommunityListing.wardrobe_item_id == item_id,
            CommunityListing.status == "active",
        )
        .scalar()
        or 0
    )
    if other_listings_count == 0:
        item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
        if item:
            item.is_community_shared = False

    db.commit()
    return {"message": "Garment successfully unlisted from community. Personal wardrobe item remains intact."}


@router.get("/{community_id}/listings/{listing_id}", response_model=CommunityListingResponse)
def get_listing_detail(
    community_id: str,
    listing_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve listing detail with item specifications. Requires approved membership.
    """
    comm = db.query(Community).filter(Community.id == community_id).first()
    if not comm:
        raise HTTPException(status_code=404, detail="Community not found.")

    _require_approved_member(db, community_id, current_user.id)

    listing = (
        db.query(CommunityListing)
        .filter(
            CommunityListing.id == listing_id,
            CommunityListing.community_id == community_id,
            CommunityListing.status == "active",
        )
        .first()
    )
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found.")

    item = db.query(WardrobeItem).filter(WardrobeItem.id == listing.wardrobe_item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    return CommunityListingResponse(
        id=listing.id,
        community_id=community_id,
        community_name=comm.name,
        wardrobe_item_id=listing.wardrobe_item_id,
        owner_id=listing.owner_id,
        status=listing.status,
        notes=listing.notes,
        created_at=listing.created_at,
        item=_model_to_item_response(item),
    )
