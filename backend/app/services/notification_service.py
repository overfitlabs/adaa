import logging
from datetime import datetime
from typing import List, Optional
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Notification

logger = logging.getLogger("wardrobelens.notification_service")


def create_notification(
    db: Session,
    user_id: str,
    event_type: str,
    title: str,
    message: str,
    actor_id: Optional[str] = None,
    actor_name: Optional[str] = None,
    reference_id: Optional[str] = None,
    reference_type: Optional[str] = None,
    community_id: Optional[str] = None,
) -> Optional[Notification]:
    """
    Safely and idempotently creates an in-app notification for a recipient.
    - Prevents self-notifications (actor == recipient).
    - Checks for existing notification for the same (user_id, event_type, reference_id, reference_type)
      to enforce deduplication.
    - Handles database integrity conflicts gracefully.
    """
    # Do not notify a user of their own actions
    if actor_id and actor_id == user_id:
        return None

    # Idempotent deduplication check
    if reference_id and reference_type:
        existing = (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id,
                Notification.event_type == event_type,
                Notification.reference_id == reference_id,
                Notification.reference_type == reference_type,
            )
            .first()
        )
        if existing:
            logger.debug(
                "Skipping duplicate notification for user %s event %s ref %s",
                user_id,
                event_type,
                reference_id,
            )
            return existing

    notification = Notification(
        user_id=user_id,
        actor_id=actor_id,
        actor_name=actor_name,
        event_type=event_type,
        title=title,
        message=message,
        reference_id=reference_id,
        reference_type=reference_type,
        community_id=community_id,
        is_read=False,
        created_at=datetime.utcnow(),
    )

    try:
        db.add(notification)
        db.flush()
        return notification
    except IntegrityError:
        db.rollback()
        logger.warning(
            "IntegrityError caught creating notification (%s, %s, %s). Returning existing.",
            user_id,
            event_type,
            reference_id,
        )
        return (
            db.query(Notification)
            .filter(
                Notification.user_id == user_id,
                Notification.event_type == event_type,
                Notification.reference_id == reference_id,
                Notification.reference_type == reference_type,
            )
            .first()
        )
    except Exception as e:
        logger.error("Failed to create notification: %s", str(e))
        return None


def get_user_notifications(
    db: Session,
    user_id: str,
    unread_only: bool = False,
    limit: int = 50,
    offset: int = 0,
) -> List[Notification]:
    """
    Retrieve notifications strictly scoped to the recipient user_id, newest first.
    """
    q = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        q = q.filter(Notification.is_read.is_(False))
    return q.order_by(Notification.created_at.desc()).offset(offset).limit(limit).all()


def get_unread_count(db: Session, user_id: str) -> int:
    """
    Counts unread notifications strictly scoped to the recipient user_id.
    """
    return (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        .count()
    )


def mark_notification_as_read(
    db: Session,
    user_id: str,
    notification_id: str,
) -> Optional[Notification]:
    """
    Marks a single notification as read, strictly verifying ownership by user_id.
    Returns None if not found or unauthorized.
    """
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        .first()
    )
    if not notification:
        return None

    if not notification.is_read:
        notification.is_read = True
        notification.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(notification)

    return notification


def mark_all_as_read(db: Session, user_id: str) -> int:
    """
    Marks all unread notifications as read for the authenticated recipient.
    Returns the count of updated notifications.
    """
    count = (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        .update(
            {"is_read": True, "updated_at": datetime.utcnow()},
            synchronize_session="fetch",
        )
    )
    db.commit()
    return count
