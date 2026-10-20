import io
from contextlib import contextmanager
import pytest
from app.main import app
from app.auth.supabase_auth import AuthenticatedUser, get_current_user, get_optional_current_user
from app.models import WardrobeItem, SavedOutfit


@contextmanager
def auth_as(user: AuthenticatedUser):
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_optional_current_user] = lambda: user
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_optional_current_user, None)


def _create_item(client, user: AuthenticatedUser, name: str, category: str, color: str, sample_image_bytes) -> str:
    with auth_as(user):
        files = {"file": (f"{name}.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        form_data = {
            "name": name,
            "category": category,
            "primary_color": color,
        }
        res = client.post("/api/wardrobe/items", data=form_data, files=files)
        assert res.status_code == 201, res.text
        return res.json()["id"]


def test_generate_outfits_unauthenticated_blocked(client):
    res = client.post("/api/recommendations/generate", json={"occasion": "Everyday"})
    assert res.status_code == 401

    res_get = client.get("/api/recommendations/generate")
    assert res_get.status_code == 401


def test_generate_outfits_empty_wardrobe(client):
    user = AuthenticatedUser(id="stylist-user-empty", email="empty@adaa.app")
    with auth_as(user):
        res = client.post("/api/recommendations/generate", json={"occasion": "Everyday"})
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "empty_wardrobe"
        assert len(data["outfits"]) == 0
        assert "empty" in data["message"].lower()


def test_generate_outfits_insufficient_items(client, sample_image_bytes):
    user = AuthenticatedUser(id="stylist-user-insufficient", email="insufficient@adaa.app")

    # Add only 1 top, no bottoms
    _create_item(client, user, "Solo Tee", "tops", "White", sample_image_bytes)

    with auth_as(user):
        res = client.post("/api/recommendations/generate", json={"occasion": "Casual"})
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "insufficient_items"
        assert len(data["outfits"]) == 0
        assert "bottoms" in data["missing_categories"]


def test_generate_outfits_multi_combinations_and_explanations(client, sample_image_bytes):
    user = AuthenticatedUser(id="stylist-user-full", email="full@adaa.app")

    # Seed a complete capsule wardrobe
    t1 = _create_item(client, user, "White Oxford Shirt", "shirts", "White", sample_image_bytes)
    t2 = _create_item(client, user, "Navy Cashmere Knit", "sweaters", "Navy", sample_image_bytes)
    b1 = _create_item(client, user, "Raw Denim Jeans", "jeans", "Navy", sample_image_bytes)
    b2 = _create_item(client, user, "Tailored Charcoal Trousers", "trousers", "Grey", sample_image_bytes)
    j1 = _create_item(client, user, "Olive Field Jacket", "jackets", "Olive", sample_image_bytes)
    s1 = _create_item(client, user, "Clean Minimalist Sneakers", "footwear", "White", sample_image_bytes)

    with auth_as(user):
        payload = {
            "occasion": "Smart Casual",
            "vibe": "Minimalist",
            "instructions": "incorporate olive tones and clean sneakers",
        }
        res = client.post("/api/recommendations/generate", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert len(data["outfits"]) >= 2

        # Check structure of returned outfits
        for outfit in data["outfits"]:
            assert outfit["name"]
            assert outfit["occasion"] == "Smart Casual"
            assert outfit["vibe"] == "Minimalist"
            assert outfit["compatibility_score"] >= 0.80
            assert len(outfit["items"]) >= 2
            assert len(outfit["styling_tips"]) >= 1
            assert outfit["explanation"]
            # Verify no invented item IDs
            for itm in outfit["items"]:
                assert itm["id"] in {t1, t2, b1, b2, j1, s1}
                assert itm["image_url"] is not None


def test_generate_outfits_refinement_cycle(client, sample_image_bytes):
    user = AuthenticatedUser(id="stylist-user-refine", email="refine@adaa.app")

    _create_item(client, user, "Linen Shirt", "shirts", "Beige", sample_image_bytes)
    _create_item(client, user, "Black Tee", "tops", "Black", sample_image_bytes)
    _create_item(client, user, "Chino Pants", "trousers", "Tan", sample_image_bytes)
    _create_item(client, user, "Black Denim", "jeans", "Black", sample_image_bytes)

    with auth_as(user):
        # Initial request
        res1 = client.post("/api/recommendations/generate", json={"occasion": "Casual", "refine_index": 0})
        assert res1.status_code == 200
        outfits1 = res1.json()["outfits"]

        # Refined alternative request
        res2 = client.post("/api/recommendations/generate", json={"occasion": "Casual", "refine_index": 1})
        assert res2.status_code == 200
        outfits2 = res2.json()["outfits"]

        assert len(outfits1) > 0
        assert len(outfits2) > 0
        # Combination order or selection differs across refinement iterations
        item_sets_1 = [tuple(sorted(o["item_ids"])) for o in outfits1]
        item_sets_2 = [tuple(sorted(o["item_ids"])) for o in outfits2]
        assert item_sets_1 != item_sets_2 or len(item_sets_1) == 1


def test_saved_outfit_validation_unowned_items_rejected(client, sample_image_bytes):
    user_a = AuthenticatedUser(id="user-a-wardrobe", email="usera@adaa.app")
    user_b = AuthenticatedUser(id="user-b-wardrobe", email="userb@adaa.app")

    # User A creates an item
    item_a = _create_item(client, user_a, "User A Jacket", "jackets", "Black", sample_image_bytes)

    # User B tries to save an outfit containing User A's item
    with auth_as(user_b):
        payload = {
            "name": "Stolen Look",
            "item_ids": [item_a],
        }
        res = client.post("/api/outfits", json=payload)
        assert res.status_code == 403
        assert "another user's wardrobe" in res.text


def test_saved_outfit_deduplication(client, sample_image_bytes):
    user = AuthenticatedUser(id="user-dedup-outfit", email="dedup@adaa.app")
    i1 = _create_item(client, user, "Dedup Shirt", "shirts", "White", sample_image_bytes)
    i2 = _create_item(client, user, "Dedup Pants", "trousers", "Navy", sample_image_bytes)

    with auth_as(user):
        payload = {
            "name": "Clean Friday Look",
            "occasion": "Work",
            "item_ids": [i1, i2],
        }
        # First save
        res1 = client.post("/api/outfits", json=payload)
        assert res1.status_code == 201
        id1 = res1.json()["id"]

        # Duplicate save with same items in reverse order
        payload_rev = {
            "name": "Duplicate Friday Look",
            "occasion": "Work",
            "item_ids": [i2, i1],
        }
        res2 = client.post("/api/outfits", json=payload_rev)
        assert res2.status_code in [200, 201]
        id2 = res2.json()["id"]

        # Must return the existing outfit without duplicating
        assert id1 == id2

        # Check total count in list is 1
        list_res = client.get("/api/outfits")
        assert list_res.status_code == 200
        matching = [o for o in list_res.json() if o["id"] == id1]
        assert len(matching) == 1


def test_saved_outfit_cross_user_isolation(client, sample_image_bytes):
    user_a = AuthenticatedUser(id="user-iso-a", email="isoa@adaa.app")
    user_b = AuthenticatedUser(id="user-iso-b", email="isob@adaa.app")

    i_a = _create_item(client, user_a, "Top A", "tops", "Blue", sample_image_bytes)

    # Save outfit for User A
    with auth_as(user_a):
        res = client.post("/api/outfits", json={"name": "User A Private Look", "item_ids": [i_a]})
        assert res.status_code == 201
        outfit_a_id = res.json()["id"]

    # User B lists outfits -> User A's outfit must not appear
    with auth_as(user_b):
        list_res = client.get("/api/outfits")
        assert list_res.status_code == 200
        assert not any(o["id"] == outfit_a_id for o in list_res.json())

        # User B direct GET -> 404
        get_res = client.get(f"/api/outfits/{outfit_a_id}")
        assert get_res.status_code == 404

        # User B delete attempt -> 404
        del_res = client.delete(f"/api/outfits/{outfit_a_id}")
        assert del_res.status_code == 404
