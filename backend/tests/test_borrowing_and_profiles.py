import io
from datetime import datetime, timedelta
from app.main import app
from app.auth.supabase_auth import AuthenticatedUser, get_current_user, get_optional_current_user


def test_borrow_request_lifecycle_and_authorization(client, db_session, sample_image_bytes):
    user_owner = AuthenticatedUser(id="user-owner-req", email="owner@req.edu", role="authenticated")
    user_borrower = AuthenticatedUser(id="user-borrower-req", email="borrower@req.edu", role="authenticated")
    user_stranger = AuthenticatedUser(id="user-stranger-req", email="stranger@req.edu", role="authenticated")

    # 1. Owner creates Community 1
    app.dependency_overrides[get_current_user] = lambda: user_owner
    c_res = client.post("/api/communities", json={"name": "Campus Borrow Circle"})
    assert c_res.status_code == 201
    comm_id = c_res.json()["id"]

    # 2. Owner creates wardrobe item & shares to community
    app.dependency_overrides[get_optional_current_user] = lambda: user_owner
    files = {"file": ("blazer.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    item_res = client.post(
        "/api/wardrobe/items",
        data={"name": "Oversized Wool Blazer", "category": "outerwear", "primary_color": "Camel"},
        files=files,
    )
    assert item_res.status_code == 201
    item_id = item_res.json()["id"]

    listing_res = client.post(
        f"/api/communities/{comm_id}/listings",
        json={"wardrobe_item_id": item_id, "notes": "Great for interviews!"},
    )
    assert listing_res.status_code == 201
    listing_id = listing_res.json()["id"]

    # 3. Borrower joins community & owner approves
    app.dependency_overrides[get_current_user] = lambda: user_borrower
    client.post(f"/api/communities/{comm_id}/join")
    app.dependency_overrides[get_current_user] = lambda: user_owner
    client.post(f"/api/communities/{comm_id}/members/user-borrower-req/approve")

    # 4. Validation: Unauthenticated attempt fails
    app.dependency_overrides.pop(get_current_user, None)
    unauth_res = client.post(f"/api/communities/{comm_id}/listings/{listing_id}/requests", json={})
    assert unauth_res.status_code == 401

    # 5. Validation: Stranger (non-member) cannot request
    app.dependency_overrides[get_current_user] = lambda: user_stranger
    stranger_res = client.post(f"/api/communities/{comm_id}/listings/{listing_id}/requests", json={})
    assert stranger_res.status_code == 403

    # 6. Validation: Owner cannot request own piece
    app.dependency_overrides[get_current_user] = lambda: user_owner
    self_res = client.post(f"/api/communities/{comm_id}/listings/{listing_id}/requests", json={})
    assert self_res.status_code == 400
    assert "own closet piece" in self_res.json()["detail"]

    # 7. Validation: Invalid date ordering (start > end) fails
    app.dependency_overrides[get_current_user] = lambda: user_borrower
    now = datetime.utcnow()
    invalid_dates_res = client.post(
        f"/api/communities/{comm_id}/listings/{listing_id}/requests",
        json={
            "start_date": (now + timedelta(days=5)).isoformat(),
            "end_date": (now + timedelta(days=2)).isoformat(),
        },
    )
    assert invalid_dates_res.status_code == 422

    # 8. Success: Borrower submits valid request with flexible dates
    req_res = client.post(
        f"/api/communities/{comm_id}/listings/{listing_id}/requests",
        json={
            "message": "Would love to borrow for Friday presentation!",
            "start_date": (now + timedelta(days=1)).isoformat(),
            "end_date": (now + timedelta(days=3)).isoformat(),
        },
    )
    assert req_res.status_code == 201
    req_data = req_res.json()
    req_id = req_data["id"]
    assert req_data["status"] == "pending"
    assert req_data["requester_id"] == "user-borrower-req"
    assert req_data["owner_id"] == "user-owner-req"
    assert req_data["item"]["name"] == "Oversized Wool Blazer"

    # 9. Validation: Duplicate pending request rejected with 409 Conflict
    dup_res = client.post(
        f"/api/communities/{comm_id}/listings/{listing_id}/requests",
        json={"message": "Duplicate attempt"},
    )
    assert dup_res.status_code == 409
    assert "already have a pending borrow request" in dup_res.json()["detail"]

    # 10. List Isolation: Incoming vs Outgoing
    # Owner sees incoming
    app.dependency_overrides[get_current_user] = lambda: user_owner
    inc_res = client.get("/api/requests/incoming")
    assert inc_res.status_code == 200
    assert len(inc_res.json()) == 1
    assert inc_res.json()[0]["id"] == req_id
    assert inc_res.json()[0]["requester_name"] is not None

    # Borrower sees outgoing
    app.dependency_overrides[get_current_user] = lambda: user_borrower
    out_res = client.get("/api/requests/outgoing")
    assert out_res.status_code == 200
    assert len(out_res.json()) == 1
    assert out_res.json()[0]["id"] == req_id
    assert out_res.json()[0]["owner_name"] is not None

    # Stranger sees neither
    app.dependency_overrides[get_current_user] = lambda: user_stranger
    assert len(client.get("/api/requests/incoming").json()) == 0
    assert len(client.get("/api/requests/outgoing").json()) == 0

    # 11. State Transitions:
    # Stranger cannot accept (404/403)
    assert client.patch(f"/api/requests/{req_id}/status", json={"status": "accepted"}).status_code == 404

    # Borrower cannot accept their own request (403)
    app.dependency_overrides[get_current_user] = lambda: user_borrower
    assert client.patch(f"/api/requests/{req_id}/status", json={"status": "accepted"}).status_code == 403

    # Borrower can cancel pending request
    cancel_res = client.patch(f"/api/requests/{req_id}/status", json={"status": "cancelled"})
    assert cancel_res.status_code == 200
    assert cancel_res.json()["status"] == "cancelled"

    # Terminal state: Cannot transition out of cancelled (409)
    assert client.patch(f"/api/requests/{req_id}/status", json={"status": "accepted"}).status_code == 409

    # 12. Re-request: After prior request became cancelled, borrower can submit a new request
    new_req_res = client.post(
        f"/api/communities/{comm_id}/listings/{listing_id}/requests",
        json={"message": "Rescheduling borrow dates"},
    )
    assert new_req_res.status_code == 201
    new_req_id = new_req_res.json()["id"]
    assert new_req_id != req_id

    # Owner accepts new request
    app.dependency_overrides[get_current_user] = lambda: user_owner
    acc_res = client.patch(f"/api/requests/{new_req_id}/status", json={"status": "accepted"})
    assert acc_res.status_code == 200
    assert acc_res.json()["status"] == "accepted"

    # Invalid transition: cannot decline once accepted (409)
    dec_res = client.patch(f"/api/requests/{new_req_id}/status", json={"status": "declined"})
    assert dec_res.status_code == 409

    # Completion: either party can mark accepted request as completed
    app.dependency_overrides[get_current_user] = lambda: user_borrower
    comp_res = client.patch(f"/api/requests/{new_req_id}/status", json={"status": "completed"})
    assert comp_res.status_code == 200
    assert comp_res.json()["status"] == "completed"

    app.dependency_overrides.pop(get_current_user, None)
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_public_profiles_and_profile_updates(client, db_session):
    user_a = AuthenticatedUser(id="user-prof-a", email="a@style.edu", role="authenticated")
    user_b = AuthenticatedUser(id="user-prof-b", email="b@style.edu", role="authenticated")
    user_c = AuthenticatedUser(id="user-prof-c", email="c@style.edu", role="authenticated")

    # 1. User A updates profile (name, bio)
    app.dependency_overrides[get_current_user] = lambda: user_a
    up_res = client.patch("/api/users/me/profile", json={
        "display_name": "Aria Chen",
        "bio": "Sustainable streetwear & minimalist aesthetics.",
    })
    assert up_res.status_code == 200
    data = up_res.json()
    assert data["display_name"] == "Aria Chen"
    assert data["bio"] == "Sustainable streetwear & minimalist aesthetics."

    # 2. Privacy: User C (stranger) attempts to view User A's profile without shared community -> 404
    app.dependency_overrides[get_current_user] = lambda: user_c
    c_view_res = client.get(f"/api/users/{user_a.id}/public-profile")
    assert c_view_res.status_code == 404

    # 3. User A creates community & User B joins and is approved
    app.dependency_overrides[get_current_user] = lambda: user_a
    comm_id = client.post("/api/communities", json={"name": "Aria Circle"}).json()["id"]

    app.dependency_overrides[get_current_user] = lambda: user_b
    client.post(f"/api/communities/{comm_id}/join")
    app.dependency_overrides[get_current_user] = lambda: user_a
    client.post(f"/api/communities/{comm_id}/members/user-prof-b/approve")

    # 4. User B can now view User A's public profile because they share an approved community!
    app.dependency_overrides[get_current_user] = lambda: user_b
    b_view_res = client.get(f"/api/users/{user_a.id}/public-profile")
    assert b_view_res.status_code == 200
    prof = b_view_res.json()
    assert prof["display_name"] == "Aria Chen"
    assert prof["bio"] == "Sustainable streetwear & minimalist aesthetics."
    assert "email" not in prof
    assert "student_email" not in prof
    assert "password" not in prof

    # 5. Shared item response enriches owner identity
    shared_res = client.get("/api/communities/shared-closet")
    assert shared_res.status_code == 200

    app.dependency_overrides.pop(get_current_user, None)
