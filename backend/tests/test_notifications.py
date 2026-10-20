import pytest
from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.main import app
from app.models import (
    Community,
    CommunityListing,
    CommunityMembership,
    Notification,
    WardrobeItem,
)
from app.services import notification_service


def test_notifications_unauthenticated_blocked(client):
    """Verifies that all notification endpoints strictly require authentication."""
    app.dependency_overrides.pop(get_current_user, None)

    r1 = client.get("/api/notifications")
    assert r1.status_code == 401

    r2 = client.get("/api/notifications/unread-count")
    assert r2.status_code == 401

    r3 = client.patch("/api/notifications/any-id/read")
    assert r3.status_code == 401

    r4 = client.post("/api/notifications/read-all")
    assert r4.status_code == 401


def test_notification_recipient_isolation(client, db_session):
    """
    Ensures complete recipient isolation:
    1. User A cannot view User B's notifications.
    2. User A cannot mark User B's notification as read.
    3. User A's read-all does not affect User B's unread status.
    """
    user_a = AuthenticatedUser(id="user-iso-a", email="usera@example.com", role="authenticated")
    user_b = AuthenticatedUser(id="user-iso-b", email="userb@example.com", role="authenticated")

    # Seed notification for user A
    notif_a = notification_service.create_notification(
        db=db_session,
        user_id=user_a.id,
        event_type="test_event_a",
        title="Alert for A",
        message="Message for user A only",
        reference_id="ref-a",
        reference_type="test",
    )
    # Seed notification for user B
    notif_b = notification_service.create_notification(
        db=db_session,
        user_id=user_b.id,
        event_type="test_event_b",
        title="Alert for B",
        message="Message for user B only",
        reference_id="ref-b",
        reference_type="test",
    )
    db_session.commit()

    # User A views their inbox
    app.dependency_overrides[get_current_user] = lambda: user_a
    res_a = client.get("/api/notifications")
    assert res_a.status_code == 200
    ids_a = [n["id"] for n in res_a.json()]
    assert notif_a.id in ids_a
    assert notif_b.id not in ids_a

    # User B views their inbox
    app.dependency_overrides[get_current_user] = lambda: user_b
    res_b = client.get("/api/notifications")
    assert res_b.status_code == 200
    ids_b = [n["id"] for n in res_b.json()]
    assert notif_b.id in ids_b
    assert notif_a.id not in ids_b

    # User A attempts to mark User B's notification as read
    app.dependency_overrides[get_current_user] = lambda: user_a
    res_tamper = client.patch(f"/api/notifications/{notif_b.id}/read")
    assert res_tamper.status_code == 404

    # User B's notification is still unread
    app.dependency_overrides[get_current_user] = lambda: user_b
    res_unread_b = client.get("/api/notifications/unread-count")
    assert res_unread_b.status_code == 200
    assert res_unread_b.json()["unread_count"] == 1

    # User A marks all as read
    app.dependency_overrides[get_current_user] = lambda: user_a
    res_read_all_a = client.post("/api/notifications/read-all")
    assert res_read_all_a.status_code == 200
    assert res_read_all_a.json()["marked_count"] == 1

    # User B still has 1 unread notification
    app.dependency_overrides[get_current_user] = lambda: user_b
    res_unread_b_after = client.get("/api/notifications/unread-count")
    assert res_unread_b_after.json()["unread_count"] == 1

    app.dependency_overrides.pop(get_current_user, None)


def test_notification_read_state_and_badge_count(client, db_session):
    """Tests single mark-as-read, unread filtering, and read-all functionality."""
    user = AuthenticatedUser(id="user-badge-test", email="badge@example.com", role="authenticated")
    app.dependency_overrides[get_current_user] = lambda: user

    # Create 3 unread notifications
    n1 = notification_service.create_notification(
        db=db_session, user_id=user.id, event_type="e1", title="T1", message="M1", reference_id="r1", reference_type="t"
    )
    n2 = notification_service.create_notification(
        db=db_session, user_id=user.id, event_type="e2", title="T2", message="M2", reference_id="r2", reference_type="t"
    )
    n3 = notification_service.create_notification(
        db=db_session, user_id=user.id, event_type="e3", title="T3", message="M3", reference_id="r3", reference_type="t"
    )
    db_session.commit()

    # Initial unread count should be 3
    res_count = client.get("/api/notifications/unread-count")
    assert res_count.status_code == 200
    assert res_count.json()["unread_count"] == 3

    # Mark n1 as read
    res_mark = client.patch(f"/api/notifications/{n1.id}/read")
    assert res_mark.status_code == 200
    assert res_mark.json()["is_read"] is True

    # Count should now be 2
    res_count_2 = client.get("/api/notifications/unread-count")
    assert res_count_2.json()["unread_count"] == 2

    # Query unread_only=True
    res_unread = client.get("/api/notifications?unread_only=true")
    assert res_unread.status_code == 200
    unread_ids = [n["id"] for n in res_unread.json()]
    assert n1.id not in unread_ids
    assert n2.id in unread_ids
    assert n3.id in unread_ids

    # Mark all as read
    res_all = client.post("/api/notifications/read-all")
    assert res_all.status_code == 200
    assert res_all.json()["marked_count"] == 2

    # Unread count should now be 0
    res_count_0 = client.get("/api/notifications/unread-count")
    assert res_count_0.json()["unread_count"] == 0

    app.dependency_overrides.pop(get_current_user, None)


def test_notification_duplicate_prevention(db_session):
    """Verifies that duplicate notifications for the same event and reference are not created."""
    user_id = "user-dedup"
    event_type = "borrow_request_accepted"
    ref_id = "req-12345"
    ref_type = "borrow_request"

    # First creation
    first = notification_service.create_notification(
        db=db_session,
        user_id=user_id,
        event_type=event_type,
        title="Accepted",
        message="Owner accepted your request",
        reference_id=ref_id,
        reference_type=ref_type,
    )
    db_session.commit()
    assert first is not None

    # Duplicate creation attempt
    second = notification_service.create_notification(
        db=db_session,
        user_id=user_id,
        event_type=event_type,
        title="Accepted Again",
        message="Duplicate text",
        reference_id=ref_id,
        reference_type=ref_type,
    )
    db_session.commit()

    # Second returns existing notification
    assert second.id == first.id

    # Total rows in db for this user must remain 1
    total = db_session.query(Notification).filter(Notification.user_id == user_id).count()
    assert total == 1


def test_borrowing_request_notification_lifecycle(client, db_session):
    """
    Tests end-to-end notification generation through borrowing lifecycle:
    1. Requester submits request -> Owner receives 'borrow_request_created' notification.
    2. Owner accepts request -> Requester receives 'borrow_request_accepted' notification.
    3. Owner completes request -> Requester receives 'borrow_request_completed' notification.
    """
    owner = AuthenticatedUser(id="notif-owner", email="owner@test.com", role="authenticated")
    requester = AuthenticatedUser(id="notif-requester", email="requester@test.com", role="authenticated")

    # Setup community, item, listing, and approved memberships
    comm = Community(id="comm-notif", name="Fashion Circle", creator_id=owner.id, is_private=True, status="active")
    db_session.add(comm)

    mem_owner = CommunityMembership(community_id=comm.id, user_id=owner.id, role="owner", status="approved")
    mem_requester = CommunityMembership(community_id=comm.id, user_id=requester.id, role="member", status="approved")
    db_session.add_all([mem_owner, mem_requester])

    item = WardrobeItem(id="item-notif", user_id=owner.id, name="Vintage Leather Jacket", category="jackets", primary_color="black", image_path="jacket.jpg")
    db_session.add(item)

    listing = CommunityListing(id="list-notif", community_id=comm.id, wardrobe_item_id=item.id, owner_id=owner.id, status="active")
    db_session.add(listing)
    db_session.commit()

    # 1. Requester creates borrow request
    app.dependency_overrides[get_current_user] = lambda: requester
    create_res = client.post(
        f"/api/communities/{comm.id}/listings/{listing.id}/requests",
        json={"message": "Would love to wear this on Friday"},
    )
    assert create_res.status_code == 201
    request_data = create_res.json()
    req_id = request_data["id"]

    # Verify Owner received 'borrow_request_created' notification
    app.dependency_overrides[get_current_user] = lambda: owner
    owner_notifs = client.get("/api/notifications").json()
    assert len(owner_notifs) == 1
    assert owner_notifs[0]["event_type"] == "borrow_request_created"
    assert owner_notifs[0]["reference_id"] == req_id
    assert "Vintage Leather Jacket" in owner_notifs[0]["message"]
    assert owner_notifs[0]["is_read"] is False

    # 2. Owner accepts the request
    accept_res = client.patch(
        f"/api/requests/{req_id}/status",
        json={"status": "accepted"},
    )
    assert accept_res.status_code == 200

    # Verify Requester received 'borrow_request_accepted' notification
    app.dependency_overrides[get_current_user] = lambda: requester
    requester_notifs = client.get("/api/notifications").json()
    assert len(requester_notifs) == 1
    assert requester_notifs[0]["event_type"] == "borrow_request_accepted"
    assert requester_notifs[0]["reference_id"] == req_id
    assert requester_notifs[0]["is_read"] is False

    # 3. Owner marks request as completed
    app.dependency_overrides[get_current_user] = lambda: owner
    complete_res = client.patch(
        f"/api/requests/{req_id}/status",
        json={"status": "completed"},
    )
    assert complete_res.status_code == 200

    # Verify Requester received 'borrow_request_completed' notification
    app.dependency_overrides[get_current_user] = lambda: requester
    requester_notifs_updated = client.get("/api/notifications").json()
    types = [n["event_type"] for n in requester_notifs_updated]
    assert "borrow_request_accepted" in types
    assert "borrow_request_completed" in types

    app.dependency_overrides.pop(get_current_user, None)


def test_community_membership_notifications_lifecycle(client, db_session):
    """
    Tests notification generation on community membership events:
    1. Applicant requests to join -> Creator/Admin receives 'membership_requested'.
    2. Admin approves request -> Applicant receives 'membership_approved'.
    """
    creator = AuthenticatedUser(id="comm-creator-user", email="creator@circle.com", role="authenticated")
    applicant = AuthenticatedUser(id="comm-applicant-user", email="applicant@circle.com", role="authenticated")

    # Community created by creator
    comm = Community(id="comm-circle-notif", name="Campus Designers", creator_id=creator.id, is_private=True, status="active")
    creator_mem = CommunityMembership(community_id=comm.id, user_id=creator.id, role="owner", status="approved")
    db_session.add_all([comm, creator_mem])
    db_session.commit()

    # 1. Applicant requests to join
    app.dependency_overrides[get_current_user] = lambda: applicant
    join_res = client.post(f"/api/communities/{comm.id}/join")
    assert join_res.status_code == 200

    # Creator receives membership_requested notification
    app.dependency_overrides[get_current_user] = lambda: creator
    creator_notifs = client.get("/api/notifications").json()
    assert len(creator_notifs) == 1
    assert creator_notifs[0]["event_type"] == "membership_requested"
    assert "Campus Designers" in creator_notifs[0]["message"]

    # 2. Creator approves applicant
    approve_res = client.post(f"/api/communities/{comm.id}/members/{applicant.id}/approve")
    assert approve_res.status_code == 200

    # Applicant receives membership_approved notification
    app.dependency_overrides[get_current_user] = lambda: applicant
    applicant_notifs = client.get("/api/notifications").json()
    assert len(applicant_notifs) == 1
    assert applicant_notifs[0]["event_type"] == "membership_approved"
    assert "Campus Designers" in applicant_notifs[0]["message"]

    app.dependency_overrides.pop(get_current_user, None)
