import io
import json
import pytest
from app.auth.supabase_auth import AuthenticatedUser, get_current_user
from app.main import app


def test_profile_defaults_and_self_view(client):
    user_a = AuthenticatedUser(id="user-p2-a", email="alice@campus.edu", role="authenticated")
    app.dependency_overrides[get_current_user] = lambda: user_a

    # 1. Owner views their own complete profile
    res = client.get("/api/users/me")
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == "user-p2-a"
    assert data["email"] == "alice@campus.edu"
    assert "privacy_settings" in data

    # Verify default privacy rules: phone, email, age, and fit details are private by default
    privacy = data["privacy_settings"]
    assert privacy["show_profile_photo"] is True
    assert privacy["show_bio"] is True
    assert privacy["show_age"] is False
    assert privacy["show_phone"] is False
    assert privacy["show_email"] is False
    assert privacy["show_fit_preferences"] is False
    assert privacy["show_preferred_styles"] is True

    app.dependency_overrides.pop(get_current_user, None)


def test_profile_update_and_fit_preferences(client):
    user_b = AuthenticatedUser(id="user-p2-b", email="bob@campus.edu", role="authenticated")
    app.dependency_overrides[get_current_user] = lambda: user_b

    # Update profile with full sizing, fit preferences, and styles
    update_payload = {
        "display_name": "Bob Miller",
        "bio": "Minimalist capsule wardrobe enthusiast.",
        "age": 23,
        "phone_number": "+1-555-0199",
        "tops_size": "M",
        "bottoms_size": "32",
        "shoe_size": "10.5",
        "preferred_fit": "relaxed",
        "preferred_styles": ["Minimalist", "Workwear", "Casual"],
    }
    update_res = client.patch("/api/users/me/profile", json=update_payload)
    assert update_res.status_code == 200
    updated = update_res.json()

    assert updated["display_name"] == "Bob Miller"
    assert updated["bio"] == "Minimalist capsule wardrobe enthusiast."
    assert updated["age"] == 23
    assert updated["phone_number"] == "+1-555-0199"
    assert updated["fit_preferences"]["tops_size"] == "M"
    assert updated["fit_preferences"]["bottoms_size"] == "32"
    assert updated["fit_preferences"]["shoe_size"] == "10.5"
    assert updated["fit_preferences"]["preferred_fit"] == "relaxed"
    assert "Minimalist" in updated["preferred_styles"]
    assert "Workwear" in updated["preferred_styles"]

    # Verify account email was not modified
    assert updated["email"] == "bob@campus.edu"

    app.dependency_overrides.pop(get_current_user, None)


def test_field_level_privacy_enforcement_in_public_profile(client):
    user_owner = AuthenticatedUser(id="user-p2-owner", email="owner@campus.edu", role="authenticated")
    user_peer = AuthenticatedUser(id="user-p2-peer", email="peer@campus.edu", role="authenticated")
    user_stranger = AuthenticatedUser(id="user-p2-stranger", email="stranger@campus.edu", role="authenticated")

    # 1. Owner populates their profile with both public and sensitive info
    app.dependency_overrides[get_current_user] = lambda: user_owner
    client.patch("/api/users/me/profile", json={
        "display_name": "Taylor Swiftly",
        "bio": "Vintage denim & leather enthusiast.",
        "avatar_url": "https://example.com/avatar.jpg",
        "age": 24,
        "phone_number": "+1-212-555-0144",
        "tops_size": "S",
        "bottoms_size": "26",
        "shoe_size": "7.5",
        "preferred_fit": "oversized",
        "preferred_styles": ["Vintage", "Boho"],
    })

    # Create community & have peer join and be approved
    comm_id = client.post("/api/communities", json={"name": "Campus Vintage Swap"}).json()["id"]

    app.dependency_overrides[get_current_user] = lambda: user_peer
    client.post(f"/api/communities/{comm_id}/join")
    app.dependency_overrides[get_current_user] = lambda: user_owner
    client.post(f"/api/communities/{comm_id}/members/user-p2-peer/approve")

    # 2. Stranger (not in community) attempts to view owner public profile -> 404
    app.dependency_overrides[get_current_user] = lambda: user_stranger
    stranger_res = client.get(f"/api/users/{user_owner.id}/public-profile")
    assert stranger_res.status_code == 404

    # 3. Peer views owner profile under DEFAULT privacy settings:
    # Defaults: photo=visible, bio=visible, styles=visible; phone=hidden, email=hidden, age=hidden, fit=hidden
    app.dependency_overrides[get_current_user] = lambda: user_peer
    peer_res = client.get(f"/api/users/{user_owner.id}/public-profile")
    assert peer_res.status_code == 200
    peer_view = peer_res.json()

    assert peer_view["display_name"] == "Taylor Swiftly"
    assert peer_view["avatar_url"] == "https://example.com/avatar.jpg"
    assert peer_view["bio"] == "Vintage denim & leather enthusiast."
    assert "Vintage" in peer_view["preferred_styles"]

    # Sensitive fields MUST be absent / withheld by default
    assert "phone_number" not in peer_view
    assert "email" not in peer_view
    assert "age" not in peer_view
    assert "fit_preferences" not in peer_view

    # 4. Owner explicitly enables visibility for phone, email, age, and fit preferences
    app.dependency_overrides[get_current_user] = lambda: user_owner
    priv_update_res = client.patch("/api/users/me/privacy", json={
        "show_phone": True,
        "show_email": True,
        "show_age": True,
        "show_fit_preferences": True,
        "show_profile_photo": False,  # hide photo now
        "show_bio": False,            # hide bio now
        "show_preferred_styles": False, # hide styles now
    })
    assert priv_update_res.status_code == 200

    # 5. Peer re-fetches owner profile:
    # Now phone, email, age, fit are visible; photo, bio, styles are withheld!
    app.dependency_overrides[get_current_user] = lambda: user_peer
    peer_res_2 = client.get(f"/api/users/{user_owner.id}/public-profile")
    assert peer_res_2.status_code == 200
    peer_view_2 = peer_res_2.json()

    assert peer_view_2["phone_number"] == "+1-212-555-0144"
    assert peer_view_2["email"] == "owner@campus.edu"
    assert peer_view_2["age"] == 24
    assert peer_view_2["fit_preferences"]["tops_size"] == "S"
    assert peer_view_2["fit_preferences"]["preferred_fit"] == "oversized"

    # Hidden fields must NOT be in JSON
    assert "avatar_url" not in peer_view_2
    assert "bio" not in peer_view_2
    assert "preferred_styles" not in peer_view_2

    # Display name always remains for community interactions
    assert peer_view_2["display_name"] == "Taylor Swiftly"

    # 6. Owner viewing themselves via /public-profile always sees complete info
    app.dependency_overrides[get_current_user] = lambda: user_owner
    owner_self_res = client.get(f"/api/users/{user_owner.id}/public-profile")
    assert owner_self_res.status_code == 200
    self_view = owner_self_res.json()
    assert self_view["avatar_url"] == "https://example.com/avatar.jpg"
    assert self_view["bio"] == "Vintage denim & leather enthusiast."
    assert self_view["phone_number"] == "+1-212-555-0144"
    assert self_view["email"] == "owner@campus.edu"

    app.dependency_overrides.pop(get_current_user, None)


def test_avatar_upload_sanitization_and_persistence(client, sample_image_bytes):
    user_c = AuthenticatedUser(id="user-p2-c", email="cathy@campus.edu", role="authenticated")
    app.dependency_overrides[get_current_user] = lambda: user_c

    files = {"file": ("avatar.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    upload_res = client.post("/api/users/me/avatar", files=files)
    assert upload_res.status_code == 200
    data = upload_res.json()
    assert "avatar_url" in data
    avatar_url = data["avatar_url"]
    assert avatar_url is not None

    # Check that profile now reflects the updated avatar
    me_res = client.get("/api/users/me")
    assert me_res.status_code == 200
    assert me_res.json()["avatar_url"] == avatar_url

    app.dependency_overrides.pop(get_current_user, None)


def test_profile_security_and_authorization_isolation(client):
    # 1. Unauthenticated requests must receive 401
    app.dependency_overrides.pop(get_current_user, None)
    res_me = client.get("/api/users/me")
    assert res_me.status_code == 401
    res_patch = client.patch("/api/users/me/profile", json={"display_name": "Hacker"})
    assert res_patch.status_code == 401
    res_priv = client.get("/api/users/me/privacy")
    assert res_priv.status_code == 401

    # 2. User X cannot modify User Y's privacy settings or profile
    user_x = AuthenticatedUser(id="user-sec-x", email="x@campus.edu", role="authenticated")
    user_y = AuthenticatedUser(id="user-sec-y", email="y@campus.edu", role="authenticated")

    # Set initial for Y
    app.dependency_overrides[get_current_user] = lambda: user_y
    client.patch("/api/users/me/profile", json={"display_name": "Original Y", "bio": "Original Bio Y"})
    client.patch("/api/users/me/privacy", json={"show_age": False, "show_phone": False})

    # Now act as X and ensure updates apply ONLY to X
    app.dependency_overrides[get_current_user] = lambda: user_x
    client.patch("/api/users/me/profile", json={"display_name": "I am X", "bio": "X bio"})
    client.patch("/api/users/me/privacy", json={"show_age": True, "show_phone": True})

    # Verify Y's profile and privacy were NOT affected
    app.dependency_overrides[get_current_user] = lambda: user_y
    y_profile = client.get("/api/users/me").json()
    assert y_profile["display_name"] == "Original Y"
    assert y_profile["bio"] == "Original Bio Y"
    assert y_profile["privacy_settings"]["show_age"] is False
    assert y_profile["privacy_settings"]["show_phone"] is False

    app.dependency_overrides.pop(get_current_user, None)

