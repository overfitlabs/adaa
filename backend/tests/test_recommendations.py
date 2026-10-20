from app.main import app
from app.auth.supabase_auth import AuthenticatedUser, get_current_user


def test_recommendations_empty_wardrobe(client):
    user = AuthenticatedUser(id="user-rec-1", email="user1@example.com")
    app.dependency_overrides[get_current_user] = lambda: user
    try:
        res = client.get("/api/recommendations")
        assert res.status_code == 200
        data = res.json()
        assert len(data) >= 1
        assert "Capsule Foundation" in data[0]["title"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)
