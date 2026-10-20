import io
import time
import jwt
import pytest
from app.auth.supabase_auth import AuthenticatedUser, SupabaseJWTVerifier, get_current_user, get_optional_current_user
from app.models import WardrobeItem

TEST_SECRET = "super-secret-test-jwt-key-minimum-32-chars-long!"
TEST_PROJECT_URL = "https://adaa-test-project.supabase.co"


def _generate_token(user_id: str, email: str = "test@adaa.app", expired: bool = False) -> str:
    now = int(time.time())
    payload = {
        "sub": user_id,
        "email": email,
        "role": "authenticated",
        "aud": "authenticated",
        "iss": f"{TEST_PROJECT_URL}/auth/v1",
        "iat": now - 3600 if expired else now,
        "exp": now - 1800 if expired else now + 3600,
    }
    return jwt.encode(payload, TEST_SECRET, algorithm="HS256")


def test_logged_out_endpoints_require_authentication(client):
    """
    Ensures that when no authentication credentials are provided,
    FastAPI strictly returns 401 Unauthorized across all strictly protected endpoints.
    """
    protected_endpoints = [
        ("GET", "/api/communities"),
        ("GET", "/api/requests/incoming"),
        ("GET", "/api/requests/outgoing"),
        ("GET", "/api/recommendations"),
        ("POST", "/api/matching/match-outfit"),
        ("GET", "/api/auth/me"),
        ("GET", "/api/users/some-user-id/public-profile"),
    ]

    for method, path in protected_endpoints:
        if method == "GET":
            res = client.get(path)
        elif method == "POST":
            res = client.post(path, json={"items": []})
        assert res.status_code == 401, f"Expected 401 for unauthenticated {method} {path}, got {res.status_code}"


def test_expired_session_token_rejection(client, monkeypatch):
    """
    Ensures an expired token results in 401 Unauthorized ("Token has expired.").
    """
    from app.config import settings
    monkeypatch.setattr(settings, "SUPABASE_URL", TEST_PROJECT_URL)
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_AUDIENCE", "authenticated")

    expired_token = _generate_token("user-expired-1", expired=True)
    headers = {"Authorization": f"Bearer {expired_token}"}

    res_auth = client.get("/api/auth/me", headers=headers)
    assert res_auth.status_code == 401
    assert "expired" in res_auth.json()["detail"].lower()

    res_wardrobe = client.get("/api/wardrobe/items", headers=headers)
    assert res_wardrobe.status_code == 401
    assert "expired" in res_wardrobe.json()["detail"].lower()


def test_malformed_and_invalid_signature_tokens(client, monkeypatch):
    """
    Ensures malformed or forged JWT tokens fail closed with 401.
    """
    from app.config import settings
    monkeypatch.setattr(settings, "SUPABASE_URL", TEST_PROJECT_URL)
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", TEST_SECRET)
    monkeypatch.setattr(settings, "SUPABASE_AUDIENCE", "authenticated")

    # 1. Invalid signature
    forged_token = jwt.encode(
        {"sub": "hacker-1", "exp": int(time.time()) + 3600, "aud": "authenticated", "iss": f"{TEST_PROJECT_URL}/auth/v1"},
        "wrong-secret-key-that-does-not-match-at-all!!",
        algorithm="HS256",
    )
    res_forged = client.get("/api/auth/me", headers={"Authorization": f"Bearer {forged_token}"})
    assert res_forged.status_code == 401

    # 2. Malformed token
    res_malformed = client.get("/api/auth/me", headers={"Authorization": "Bearer not.a.valid.jwt"})
    assert res_malformed.status_code == 401


def test_switching_accounts_session_isolation(client, db_session, sample_image_bytes):
    """
    Regression test for switching accounts:
    - User A adds an item to their wardrobe.
    - Session switches to User B.
    - User B must NEVER see or access User A's item.
    - User B adding their own item must be strictly isolated to User B.
    """
    from app.main import app

    user_a = AuthenticatedUser(id="user-session-a", email="usera@adaa.app", role="authenticated")
    user_b = AuthenticatedUser(id="user-session-b", email="userb@adaa.app", role="authenticated")

    # Step 1: User A logs in and creates an item
    app.dependency_overrides[get_current_user] = lambda: user_a
    app.dependency_overrides[get_optional_current_user] = lambda: user_a

    files = {"file": ("item_a.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_a = {"name": "User A Cashmere Sweater", "category": "tops", "primary_color": "Cream"}
    res_a = client.post("/api/wardrobe/items", data=form_a, files=files)
    assert res_a.status_code == 201
    item_a_id = res_a.json()["id"]

    # Verify User A sees item A
    list_a = client.get("/api/wardrobe/items")
    assert list_a.status_code == 200
    assert any(i["id"] == item_a_id for i in list_a.json())

    # Step 2: Switch to User B (Simulating User A logout and User B login)
    app.dependency_overrides[get_current_user] = lambda: user_b
    app.dependency_overrides[get_optional_current_user] = lambda: user_b

    # User B list must be empty (or not contain User A's item)
    list_b = client.get("/api/wardrobe/items")
    assert list_b.status_code == 200
    assert not any(i["id"] == item_a_id for i in list_b.json())

    # User B direct access to User A's item must 404
    assert client.get(f"/api/wardrobe/items/{item_a_id}").status_code == 404
    assert client.put(f"/api/wardrobe/items/{item_a_id}", json={"name": "Hacked"}).status_code == 404
    assert client.delete(f"/api/wardrobe/items/{item_a_id}").status_code == 404

    # User B recommendations must only use User B's wardrobe (empty capsule fallback)
    rec_b = client.get("/api/recommendations")
    assert rec_b.status_code == 200
    assert "Capsule Foundation" in rec_b.json()[0]["title"]

    # User B creates User B's item
    files_b = {"file": ("item_b.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_b = {"name": "User B Denim Jeans", "category": "bottoms", "primary_color": "Blue"}
    res_b = client.post("/api/wardrobe/items", data=form_b, files=files_b)
    assert res_b.status_code == 201
    item_b_id = res_b.json()["id"]

    # User B list has item B but NOT item A
    list_b_updated = client.get("/api/wardrobe/items")
    ids_b = [i["id"] for i in list_b_updated.json()]
    assert item_b_id in ids_b
    assert item_a_id not in ids_b
