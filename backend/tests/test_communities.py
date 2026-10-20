import io
from unittest.mock import patch
from app.main import app
from app.config import settings
from app.auth.supabase_auth import AuthenticatedUser, get_current_user, get_optional_current_user
from app.models import WardrobeItem


def test_community_creation_and_owner_membership(client, db_session):
    user_a = AuthenticatedUser(id="user-a-111", email="a@campus.edu", role="authenticated")
    app.dependency_overrides[get_current_user] = lambda: user_a

    # Create community
    res = client.post("/api/communities", json={
        "name": "Sustainable Campus Swap",
        "description": "Share and borrow pre-loved outfits.",
        "is_private": True,
    })
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Sustainable Campus Swap"
    assert data["creator_id"] == "user-a-111"
    assert data["members_count"] == 1
    assert data["my_membership"]["role"] == "owner"
    assert data["my_membership"]["status"] == "approved"
    comm_id = data["id"]

    # Discover communities includes the new community
    disc_res = client.get("/api/communities")
    assert disc_res.status_code == 200
    comms = disc_res.json()
    assert any(c["id"] == comm_id for c in comms)

    # Get my communities includes it
    my_res = client.get("/api/communities/my")
    assert my_res.status_code == 200
    my_comms = my_res.json()
    assert any(c["id"] == comm_id for c in my_comms)

    app.dependency_overrides.pop(get_current_user, None)


def test_join_request_and_admin_approval_and_rejection(client, db_session):
    user_owner = AuthenticatedUser(id="user-owner-100", email="owner@campus.edu", role="authenticated")
    user_joiner = AuthenticatedUser(id="user-joiner-200", email="joiner@campus.edu", role="authenticated")
    user_rejectee = AuthenticatedUser(id="user-rejectee-300", email="reject@campus.edu", role="authenticated")

    # Create community as owner
    app.dependency_overrides[get_current_user] = lambda: user_owner
    c_res = client.post("/api/communities", json={"name": "Fashion Society"})
    assert c_res.status_code == 201
    comm_id = c_res.json()["id"]

    # User joiner requests to join
    app.dependency_overrides[get_current_user] = lambda: user_joiner
    j_res = client.post(f"/api/communities/{comm_id}/join")
    assert j_res.status_code == 200
    assert j_res.json()["status"] == "requested"

    # User joiner cannot approve themselves (forbidden)
    assert client.post(f"/api/communities/{comm_id}/members/user-joiner-200/approve").status_code == 403

    # Owner approves joiner
    app.dependency_overrides[get_current_user] = lambda: user_owner
    appr_res = client.post(f"/api/communities/{comm_id}/members/user-joiner-200/approve")
    assert appr_res.status_code == 200
    assert appr_res.json()["status"] == "approved"

    # User rejectee requests to join
    app.dependency_overrides[get_current_user] = lambda: user_rejectee
    client.post(f"/api/communities/{comm_id}/join")

    # Owner rejects rejectee
    app.dependency_overrides[get_current_user] = lambda: user_owner
    rej_res = client.post(f"/api/communities/{comm_id}/members/user-rejectee-300/reject")
    assert rej_res.status_code == 200
    assert rej_res.json()["status"] == "rejected"

    app.dependency_overrides.pop(get_current_user, None)


def test_multiple_independent_communities_and_isolation(client, db_session):
    user_a = AuthenticatedUser(id="user-a-iso", email="a@iso.com", role="authenticated")
    user_b = AuthenticatedUser(id="user-b-iso", email="b@iso.com", role="authenticated")

    # User A creates Comm A
    app.dependency_overrides[get_current_user] = lambda: user_a
    comm_a = client.post("/api/communities", json={"name": "Comm A"}).json()["id"]

    # User B creates Comm B
    app.dependency_overrides[get_current_user] = lambda: user_b
    comm_b = client.post("/api/communities", json={"name": "Comm B"}).json()["id"]

    # User A requests to join Comm B
    app.dependency_overrides[get_current_user] = lambda: user_a
    client.post(f"/api/communities/{comm_b}/join")

    # User A cannot approve anyone in Comm B even though User A is an owner in Comm A
    assert client.post(f"/api/communities/{comm_b}/members/user-a-iso/approve").status_code == 403

    app.dependency_overrides.pop(get_current_user, None)


def test_access_denial_for_pending_rejected_and_non_members(client, db_session):
    user_owner = AuthenticatedUser(id="user-owner-priv", email="owner@priv.com", role="authenticated")
    user_pending = AuthenticatedUser(id="user-pending", email="pending@priv.com", role="authenticated")
    user_stranger = AuthenticatedUser(id="user-stranger", email="stranger@priv.com", role="authenticated")

    # Create community
    app.dependency_overrides[get_current_user] = lambda: user_owner
    comm_id = client.post("/api/communities", json={"name": "Secret Society"}).json()["id"]

    # Pending requests to join
    app.dependency_overrides[get_current_user] = lambda: user_pending
    client.post(f"/api/communities/{comm_id}/join")

    # Pending cannot view listings
    assert client.get(f"/api/communities/{comm_id}/listings").status_code == 403

    # Stranger cannot view listings
    app.dependency_overrides[get_current_user] = lambda: user_stranger
    assert client.get(f"/api/communities/{comm_id}/listings").status_code == 403

    # Owner can view listings (starts empty)
    app.dependency_overrides[get_current_user] = lambda: user_owner
    listings_res = client.get(f"/api/communities/{comm_id}/listings")
    assert listings_res.status_code == 200
    assert listings_res.json() == []

    app.dependency_overrides.pop(get_current_user, None)


def test_wardrobe_sharing_and_unlisting(client, db_session, sample_image_bytes):
    user_a = AuthenticatedUser(id="user-a-share", email="a@share.com", role="authenticated")
    user_b = AuthenticatedUser(id="user-b-share", email="b@share.com", role="authenticated")

    # User A creates a personal wardrobe item
    app.dependency_overrides[get_optional_current_user] = lambda: user_a
    files = {"file": ("item.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    item_res = client.post("/api/wardrobe/items", data={"name": "Silk Slip Dress", "category": "dresses", "primary_color": "Emerald"}, files=files)
    assert item_res.status_code == 201
    item_id = item_res.json()["id"]

    # User A creates Comm 1
    app.dependency_overrides[get_current_user] = lambda: user_a
    comm_1 = client.post("/api/communities", json={"name": "Evening Wear Circle"}).json()["id"]

    # User A shares item to Comm 1
    share_res = client.post(f"/api/communities/{comm_1}/listings", json={
        "wardrobe_item_id": item_id,
        "notes": "Available for special events!",
    })
    assert share_res.status_code == 201
    listing_id = share_res.json()["id"]
    assert share_res.json()["item"]["is_community_shared"] is True

    # User B cannot share User A's item to any community
    app.dependency_overrides[get_current_user] = lambda: user_b
    comm_2 = client.post("/api/communities", json={"name": "User B Comm"}).json()["id"]
    assert client.post(f"/api/communities/{comm_2}/listings", json={"wardrobe_item_id": item_id}).status_code == 403

    # User A checks where the item is listed
    app.dependency_overrides[get_current_user] = lambda: user_a
    shares_res = client.get(f"/api/wardrobe/items/{item_id}/listings")
    assert shares_res.status_code == 200
    assert len(shares_res.json()) == 1
    assert shares_res.json()[0]["community_id"] == comm_1

    # User A unlists the item
    del_res = client.delete(f"/api/communities/{comm_1}/listings/{listing_id}")
    assert del_res.status_code == 200

    # Verify item still exists in personal wardrobe!
    app.dependency_overrides[get_optional_current_user] = lambda: user_a
    check_item = client.get(f"/api/wardrobe/items/{item_id}")
    assert check_item.status_code == 200
    assert check_item.json()["name"] == "Silk Slip Dress"
    assert check_item.json()["is_community_shared"] is False

    app.dependency_overrides.pop(get_current_user, None)
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_cross_community_shared_closet_search(client, db_session, sample_image_bytes):
    user_a = AuthenticatedUser(id="user-a-cross", email="a@cross.com", role="authenticated")
    user_b = AuthenticatedUser(id="user-b-cross", email="b@cross.com", role="authenticated")
    user_c = AuthenticatedUser(id="user-c-cross", email="c@cross.com", role="authenticated")

    # User A creates Comm 1 and item (Denim Jacket)
    app.dependency_overrides[get_current_user] = lambda: user_a
    comm_1 = client.post("/api/communities", json={"name": "Denim Lovers"}).json()["id"]
    app.dependency_overrides[get_optional_current_user] = lambda: user_a
    files1 = {"file": ("denim.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    item1 = client.post("/api/wardrobe/items", data={"name": "Vintage Denim Jacket", "category": "outerwear", "primary_color": "Blue", "brand": "Levi's"}, files=files1).json()["id"]
    client.post(f"/api/communities/{comm_1}/listings", json={"wardrobe_item_id": item1})

    # User C creates Comm 2 and item (Sneakers)
    app.dependency_overrides[get_current_user] = lambda: user_c
    comm_2 = client.post("/api/communities", json={"name": "Kicks Community"}).json()["id"]
    app.dependency_overrides[get_optional_current_user] = lambda: user_c
    files2 = {"file": ("sneakers.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    item2 = client.post("/api/wardrobe/items", data={"name": "Air Jordan 1", "category": "shoes", "primary_color": "Red", "brand": "Nike"}, files=files2).json()["id"]
    client.post(f"/api/communities/{comm_2}/listings", json={"wardrobe_item_id": item2})

    # User B joins Comm 1 and Comm 2
    app.dependency_overrides[get_current_user] = lambda: user_b
    client.post(f"/api/communities/{comm_1}/join")
    client.post(f"/api/communities/{comm_2}/join")

    # Approve User B in both
    app.dependency_overrides[get_current_user] = lambda: user_a
    client.post(f"/api/communities/{comm_1}/members/user-b-cross/approve")
    app.dependency_overrides[get_current_user] = lambda: user_c
    client.post(f"/api/communities/{comm_2}/members/user-b-cross/approve")

    # User B queries cross-community shared closet
    app.dependency_overrides[get_current_user] = lambda: user_b
    shared_res = client.get("/api/communities/shared-closet")
    assert shared_res.status_code == 200
    shared_items = shared_res.json()
    assert len(shared_items) == 2
    item_names = [s["item"]["name"] for s in shared_items]
    assert "Vintage Denim Jacket" in item_names
    assert "Air Jordan 1" in item_names

    # Filter by category
    shoes_res = client.get("/api/communities/shared-closet?category=shoes")
    assert shoes_res.status_code == 200
    assert len(shoes_res.json()) == 1
    assert shoes_res.json()[0]["item"]["name"] == "Air Jordan 1"

    # Search keyword
    search_res = client.get("/api/communities/shared-closet?search=Levi")
    assert search_res.status_code == 200
    assert len(search_res.json()) == 1
    assert search_res.json()[0]["item"]["name"] == "Vintage Denim Jacket"

    app.dependency_overrides.pop(get_current_user, None)
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_last_owner_protection_and_member_removal(client, db_session):
    user_owner1 = AuthenticatedUser(id="owner-1", email="o1@comm.com", role="authenticated")
    user_member = AuthenticatedUser(id="member-2", email="m2@comm.com", role="authenticated")

    # Create community
    app.dependency_overrides[get_current_user] = lambda: user_owner1
    comm_id = client.post("/api/communities", json={"name": "Owner Protection Club"}).json()["id"]

    # Owner cannot leave if sole owner
    leave_res = client.post(f"/api/communities/{comm_id}/leave")
    assert leave_res.status_code == 400
    assert "last remaining owner" in leave_res.json()["detail"]

    # User member joins and is approved
    app.dependency_overrides[get_current_user] = lambda: user_member
    client.post(f"/api/communities/{comm_id}/join")
    app.dependency_overrides[get_current_user] = lambda: user_owner1
    client.post(f"/api/communities/{comm_id}/members/member-2/approve")

    # Owner cannot be demoted if sole owner
    demote_res = client.patch(f"/api/communities/{comm_id}/members/owner-1/role", json={"role": "member"})
    assert demote_res.status_code == 400
    assert "last remaining owner" in demote_res.json()["detail"]

    # Promote member-2 to owner
    promote_res = client.patch(f"/api/communities/{comm_id}/members/member-2/role", json={"role": "owner"})
    assert promote_res.status_code == 200
    assert promote_res.json()["role"] == "owner"

    # Now owner-1 CAN leave because there is another approved owner!
    leave_res2 = client.post(f"/api/communities/{comm_id}/leave")
    assert leave_res2.status_code == 200

    app.dependency_overrides.pop(get_current_user, None)


def test_private_image_delivery_for_community_members(client, db_session, sample_image_bytes):
    with patch.object(settings, "STORAGE_BACKEND", "local"):
        user_owner = AuthenticatedUser(id="img-owner", email="owner@img.com", role="authenticated")
        user_member = AuthenticatedUser(id="img-member", email="member@img.com", role="authenticated")
        user_stranger = AuthenticatedUser(id="img-stranger", email="stranger@img.com", role="authenticated")

        # Create wardrobe item with local file
        app.dependency_overrides[get_optional_current_user] = lambda: user_owner
        files = {"file": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        item_res = client.post("/api/wardrobe/items", data={"name": "Community Dress", "category": "dresses", "primary_color": "Blue"}, files=files)
        assert item_res.status_code == 201
        item = item_res.json()
        filename = item["image_path"].replace("wardrobe/", "")

        # Before sharing: user_member cannot access the image
        app.dependency_overrides[get_optional_current_user] = lambda: user_member
        headers_member = {"Authorization": "Bearer fake-token-member"}
        from app.auth.supabase_auth import get_jwt_verifier
        verifier = get_jwt_verifier()
        orig_verify = verifier.verify_token
        try:
            verifier.verify_token = lambda tok: user_member if "member" in tok else (user_stranger if "stranger" in tok else user_owner)

            # Member blocked before listing
            assert client.get(f"/storage/wardrobe/{filename}", headers=headers_member).status_code == 404

            # Create community & join
            app.dependency_overrides[get_current_user] = lambda: user_owner
            comm_id = client.post("/api/communities", json={"name": "Dress Share"}).json()["id"]
            client.post(f"/api/communities/{comm_id}/listings", json={"wardrobe_item_id": item["id"]})

            app.dependency_overrides[get_current_user] = lambda: user_member
            client.post(f"/api/communities/{comm_id}/join")
            app.dependency_overrides[get_current_user] = lambda: user_owner
            client.post(f"/api/communities/{comm_id}/members/img-member/approve")

            # Member now HAS ACCESS because item is actively listed in an approved community!
            res_access = client.get(f"/storage/wardrobe/{filename}", headers=headers_member)
            assert res_access.status_code == 200

            # Stranger STILL BLOCKED
            headers_stranger = {"Authorization": "Bearer fake-token-stranger"}
            assert client.get(f"/storage/wardrobe/{filename}", headers=headers_stranger).status_code == 404
        finally:
            verifier.verify_token = orig_verify
            app.dependency_overrides.pop(get_current_user, None)
            app.dependency_overrides.pop(get_optional_current_user, None)
