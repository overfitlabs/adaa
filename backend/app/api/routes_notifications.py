import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.database import get_db
from app.schemas import (
    MarkAllNotificationsReadResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.services import notification_service

logger = logging.getLogger("wardrobelens.routes_notifications")

router = APIRouter(prefix="/api/notifications", tags=["In-App Notifications & Activity Center"])


@router.get("", response_model=List[NotificationResponse])
def get_notifications(
    unread_only: bool = Query(False, description="Filter to only unread notifications"),
    limit: int = Query(50, ge=1, le=100, description="Max notifications to return"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Retrieve in-app notifications for the authenticated recipient.
    Strictly scoped to current_user.id. Ordered newest first.
    """
    notifications = notification_service.get_user_notifications(
        db=db,
        user_id=current_user.id,
        unread_only=unread_only,
        limit=limit,
        offset=offset,
    )
    return notifications


@router.get("/unread-count", response_model=NotificationUnreadCountResponse)
def get_unread_notification_count(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get the unread notification badge count for the authenticated recipient.
    """
    count = notification_service.get_unread_count(db=db, user_id=current_user.id)
    return NotificationUnreadCountResponse(unread_count=count)


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Mark a single notification as read.
    Enforces strict recipient ownership: cannot mark another user's notification as read.
    """
    updated = notification_service.mark_notification_as_read(
        db=db,
        user_id=current_user.id,
        notification_id=notification_id,
    )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )
    return updated


@router.post("/read-all", response_model=MarkAllNotificationsReadResponse)
def mark_all_notifications_read(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Mark all unread notifications for the authenticated user as read.
    """
    marked = notification_service.mark_all_as_read(db=db, user_id=current_user.id)
    return MarkAllNotificationsReadResponse(marked_count=marked)
