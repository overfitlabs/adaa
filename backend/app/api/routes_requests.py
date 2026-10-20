import logging
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.models import Community, CommunityListing, ItemRequest, WardrobeItem
from app.schemas import ItemRequestResponse, ItemRequestStatusUpdate
from app.api.routes_communities import _model_to_item_response, _resolve_member_profiles
from app.services import notification_service

logger = logging.getLogger("wardrobelens.routes_requests")

router = APIRouter(prefix="/api/requests", tags=["Borrowing Requests & Tracking"])


def _build_request_response(
    req: ItemRequest,
    comm_name: Optional[str],
    item: Optional[WardrobeItem],
    profiles_map: dict,
) -> ItemRequestResponse:
    requester_prof = profiles_map.get(req.requester_id, {})
    owner_prof = profiles_map.get(req.owner_id, {})

    return ItemRequestResponse(
        id=req.id,
        listing_id=req.listing_id,
        wardrobe_item_id=req.wardrobe_item_id,
        community_id=req.community_id,
        community_name=comm_name,
        requester_id=req.requester_id,
        requester_name=requester_prof.get("display_name") or f"Member ({req.requester_id[:6]})",
        requester_avatar_url=requester_prof.get("avatar_url"),
        owner_id=req.owner_id,
        owner_name=owner_prof.get("display_name") or f"Member ({req.owner_id[:6]})",
        owner_avatar_url=owner_prof.get("avatar_url"),
        status=req.status,
        message=req.message,
        start_date=req.start_date,
        end_date=req.end_date,
        responded_at=req.responded_at,
        completed_at=req.completed_at,
        created_at=req.created_at,
        updated_at=req.updated_at,
        item=_model_to_item_response(item) if item else None,
    )


@router.get("/incoming", response_model=List[ItemRequestResponse])
def get_incoming_requests(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by request status"),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve incoming borrow requests for items owned by the authenticated user.
    Ordered newest first.
    """
    q = db.query(ItemRequest).filter(ItemRequest.owner_id == current_user.id)
    if status_filter and status_filter.strip():
        q = q.filter(ItemRequest.status == status_filter.strip().lower())

    requests = q.order_by(ItemRequest.created_at.desc()).all()
    if not requests:
        return []

    user_ids = []
    for r in requests:
        user_ids.append(r.requester_id)
        user_ids.append(r.owner_id)
    profiles_map = _resolve_member_profiles(db, user_ids)

    # Batch load communities & items
    comm_ids = list({r.community_id for r in requests})
    comms = {c.id: c.name for c in db.query(Community).filter(Community.id.in_(comm_ids)).all()}

    item_ids = list({r.wardrobe_item_id for r in requests})
    items = {it.id: it for it in db.query(WardrobeItem).filter(WardrobeItem.id.in_(item_ids)).all()}

    return [
        _build_request_response(
            r,
            comm_name=comms.get(r.community_id),
            item=items.get(r.wardrobe_item_id),
            profiles_map=profiles_map,
        )
        for r in requests
    ]


@router.get("/outgoing", response_model=List[ItemRequestResponse])
def get_outgoing_requests(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by request status"),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve outgoing borrow requests submitted by the authenticated user.
    Ordered newest first.
    """
    q = db.query(ItemRequest).filter(ItemRequest.requester_id == current_user.id)
    if status_filter and status_filter.strip():
        q = q.filter(ItemRequest.status == status_filter.strip().lower())

    requests = q.order_by(ItemRequest.created_at.desc()).all()
    if not requests:
        return []

    user_ids = []
    for r in requests:
        user_ids.append(r.requester_id)
        user_ids.append(r.owner_id)
    profiles_map = _resolve_member_profiles(db, user_ids)

    comm_ids = list({r.community_id for r in requests})
    comms = {c.id: c.name for c in db.query(Community).filter(Community.id.in_(comm_ids)).all()}

    item_ids = list({r.wardrobe_item_id for r in requests})
    items = {it.id: it for it in db.query(WardrobeItem).filter(WardrobeItem.id.in_(item_ids)).all()}

    return [
        _build_request_response(
            r,
            comm_name=comms.get(r.community_id),
            item=items.get(r.wardrobe_item_id),
            profiles_map=profiles_map,
        )
        for r in requests
    ]


@router.patch("/{request_id}/status", response_model=ItemRequestResponse)
def update_request_status(
    request_id: str,
    body: ItemRequestStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Update request status according to strict lifecycle rules:
    - pending -> accepted: item owner only.
    - pending -> declined: item owner only.
    - pending -> cancelled: requesting user only.
    - accepted -> completed: item owner or requester.
    - No transitions out of declined, cancelled, or completed.
    """
    new_status = body.status.strip().lower()
    allowed_statuses = {"accepted", "declined", "cancelled", "completed"}
    if new_status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid status '{new_status}'. Must be one of: {', '.join(sorted(allowed_statuses))}",
        )

    # Concurrency safe row selection
    q = db.query(ItemRequest).filter(ItemRequest.id == request_id)
    if db.bind and db.bind.dialect.name == "postgresql":
        q = q.with_for_update()
    req = q.first()

    if not req:
        raise HTTPException(status_code=404, detail="Borrow request not found.")

    # Caller must be either owner or requester
    is_owner = req.owner_id == current_user.id
    is_requester = req.requester_id == current_user.id
    if not is_owner and not is_requester:
        # Avoid leaking whether another user's request exists
        raise HTTPException(status_code=404, detail="Borrow request not found.")

    # Check terminal state
    if req.status in ("declined", "cancelled", "completed"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot transition a request that is already in terminal state '{req.status}'.",
        )

    # Evaluate transition from pending
    if req.status == "pending":
        if new_status in ("accepted", "declined"):
            if not is_owner:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only the item owner can accept or decline a borrow request.",
                )
            req.status = new_status
            req.responded_at = datetime.utcnow()
        elif new_status == "cancelled":
            if not is_requester:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only the requester can cancel their pending borrow request.",
                )
            req.status = "cancelled"
            req.responded_at = datetime.utcnow()
        elif new_status == "completed":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A pending request must first be accepted before it can be marked completed.",
            )

    # Evaluate transition from accepted
    elif req.status == "accepted":
        if new_status == "completed":
            req.status = "completed"
            req.completed_at = datetime.utcnow()
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Cannot change an accepted request to '{new_status}'. Only 'completed' is permitted.",
            )

    req.updated_at = datetime.utcnow()

    profiles_map = _resolve_member_profiles(db, [req.requester_id, req.owner_id])
    comm = db.query(Community).filter(Community.id == req.community_id).first()
    item = db.query(WardrobeItem).filter(WardrobeItem.id == req.wardrobe_item_id).first()

    item_name = item.name if item else "closet piece"
    owner_name = profiles_map.get(req.owner_id, {}).get("display_name") or f"Member ({req.owner_id[:6]})"
    requester_name = profiles_map.get(req.requester_id, {}).get("display_name") or f"Member ({req.requester_id[:6]})"

    # Send notifications on status transitions
    if new_status == "accepted":
        notification_service.create_notification(
            db=db,
            user_id=req.requester_id,
            actor_id=current_user.id,
            actor_name=owner_name,
            event_type="borrow_request_accepted",
            title="Borrow request accepted",
            message=f'{owner_name} accepted your request for "{item_name}".',
            reference_id=req.id,
            reference_type="borrow_request",
            community_id=req.community_id,
        )
    elif new_status == "declined":
        notification_service.create_notification(
            db=db,
            user_id=req.requester_id,
            actor_id=current_user.id,
            actor_name=owner_name,
            event_type="borrow_request_declined",
            title="Borrow request declined",
            message=f'{owner_name} declined your request for "{item_name}".',
            reference_id=req.id,
            reference_type="borrow_request",
            community_id=req.community_id,
        )
    elif new_status == "cancelled":
        notification_service.create_notification(
            db=db,
            user_id=req.owner_id,
            actor_id=current_user.id,
            actor_name=requester_name,
            event_type="borrow_request_cancelled",
            title="Borrow request cancelled",
            message=f'{requester_name} cancelled their borrow request for "{item_name}".',
            reference_id=req.id,
            reference_type="borrow_request",
            community_id=req.community_id,
        )
    elif new_status == "completed":
        recipient_id = req.requester_id if current_user.id == req.owner_id else req.owner_id
        actor_name = owner_name if current_user.id == req.owner_id else requester_name
        notification_service.create_notification(
            db=db,
            user_id=recipient_id,
            actor_id=current_user.id,
            actor_name=actor_name,
            event_type="borrow_request_completed",
            title="Borrowing completed",
            message=f'Borrowing for "{item_name}" has been marked completed.',
            reference_id=req.id,
            reference_type="borrow_request",
            community_id=req.community_id,
        )

    db.commit()
    db.refresh(req)

    return _build_request_response(
        req,
        comm_name=comm.name if comm else None,
        item=item,
        profiles_map=profiles_map,
    )
