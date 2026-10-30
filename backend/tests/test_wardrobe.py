import io
import json
from unittest.mock import patch, MagicMock
from app.models import WardrobeItem
from app.auth.supabase_auth import AuthenticatedUser


def test_create_and_get_wardrobe_item(client, sample_image_bytes):
    # Create item
    files = {"file": ("blazer.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_data = {
        "name": "Navy Wool Blazer",
        "category": "jackets",
        "sub_category": "Blazer",
        "primary_color": "Navy",
        "material": "Wool",
        "fit": "Tailored",
        "season": "autumn",
        "formality": "smart-casual",
        "brand": "Brooks Brothers",
        "size": "40R",
        "condition": "Excellent",
        "notes": "Dry clean only. Fits true to size.",
        "tags": '["classic", "office", "autumn"]',
    }
    response = client.post("/api/wardrobe/items", data=form_data, files=files)
    assert response.status_code == 201
    item = response.json()
    assert item["name"] == "Navy Wool Blazer"
    assert item["category"] == "outerwear"
    assert item["primary_color"] == "navy"
    assert item["brand"] == "Brooks Brothers"
    assert item["size"] == "40R"
    assert item["condition"] == "Excellent"
    assert item["notes"] == "Dry clean only. Fits true to size."
    assert "classic" in item["tags"]
    item_id = item["id"]

    # Get single item
    get_res = client.get(f"/api/wardrobe/items/{item_id}")
    assert get_res.status_code == 200
    assert get_res.json()["id"] == item_id
    assert get_res.json()["brand"] == "Brooks Brothers"

    # Filter by category
    cat_res = client.get("/api/wardrobe/items?category=jackets")
    assert cat_res.status_code == 200
    assert len(cat_res.json()) >= 1

    # Search item by brand
    search_brand_res = client.get("/api/wardrobe/items?brand=Brooks")
    assert search_brand_res.status_code == 200
    assert len(search_brand_res.json()) >= 1

    # Search item by notes text
    search_notes_res = client.get("/api/wardrobe/items?search=clean")
    assert search_notes_res.status_code == 200
    assert len(search_notes_res.json()) >= 1

    # Update item
    update_res = client.put(
        f"/api/wardrobe/items/{item_id}",
        json={
            "name": "Updated Navy Wool Blazer",
            "fit": "Oversized",
            "brand": "Brooks Brothers Vintage",
            "notes": "Hand wash cold now.",
        },
    )
    assert update_res.status_code == 200
    assert update_res.json()["name"] == "Updated Navy Wool Blazer"
    assert update_res.json()["fit"] == "oversized"
    assert update_res.json()["brand"] == "Brooks Brothers Vintage"
    assert update_res.json()["notes"] == "Hand wash cold now."
    # Check that untouched fields are preserved
    assert update_res.json()["size"] == "40R"
    assert update_res.json()["primary_color"] == "navy"

    # Delete item
    del_res = client.delete(f"/api/wardrobe/items/{item_id}")
    assert del_res.status_code == 204

    # Verify deleted
    not_found_res = client.get(f"/api/wardrobe/items/{item_id}")
    assert not_found_res.status_code == 404


def test_wardrobe_photo_replacement(client, sample_image_bytes):
    # Create item
    files = {"file": ("original.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_data = {
        "name": "Original White Linen Shirt",
        "category": "tops",
        "primary_color": "White",
    }
    create_res = client.post("/api/wardrobe/items", data=form_data, files=files)
    assert create_res.status_code == 201
    item = create_res.json()
    item_id = item["id"]
    original_path = item["image_path"]

    # Replace photo
    new_files = {"file": ("replacement.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    replace_res = client.put(f"/api/wardrobe/items/{item_id}/photo", files=new_files)
    assert replace_res.status_code == 200
    updated_item = replace_res.json()
    assert updated_item["image_path"] != original_path
    assert updated_item["name"] == "Original White Linen Shirt"

    # Clean up
    client.delete(f"/api/wardrobe/items/{item_id}")


def test_wardrobe_invalid_image_rejection(client):
    corrupt_files = {"file": ("corrupt.jpg", io.BytesIO(b"not-an-image-data"), "image/jpeg")}
    form_data = {
        "name": "Corrupt Item",
        "category": "tops",
        "primary_color": "Blue",
    }
    res = client.post("/api/wardrobe/items", data=form_data, files=corrupt_files)
    assert res.status_code == 400
    assert "invalid" in res.json()["detail"].lower() or "unsupported" in res.json()["detail"].lower()


def test_wardrobe_categories_endpoint(client, sample_image_bytes):
    # Add a top and a footwear piece
    f1 = {"file": ("top.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    client.post("/api/wardrobe/items", data={"name": "Shirt A", "category": "tops", "primary_color": "Blue"}, files=f1)

    f2 = {"file": ("shoes.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    client.post("/api/wardrobe/items", data={"name": "Sneakers B", "category": "shoes", "primary_color": "White"}, files=f2)

    cat_res = client.get("/api/wardrobe/categories")
    assert cat_res.status_code == 200
    categories = cat_res.json()
    cat_names = [c["category"] for c in categories]

    # Verify standard fashion categories are present
    assert "tops" in cat_names
    assert "bottoms" in cat_names
    assert "dresses" in cat_names
    assert "outerwear" in cat_names
    assert "shoes" in cat_names
    assert "bags" in cat_names
    assert "accessories" in cat_names

    top_cat = next(c for c in categories if c["category"] == "tops")
    shoes_cat = next(c for c in categories if c["category"] == "shoes")
    assert top_cat["count"] >= 1
    assert shoes_cat["count"] >= 1


def test_wardrobe_cross_user_isolation(client, db_session, sample_image_bytes):
    from app.main import app
    from app.auth.supabase_auth import get_optional_current_user

    user_a = AuthenticatedUser(id="owner-user-111", email="a@wardrobe.io", role="authenticated")
    user_b = AuthenticatedUser(id="other-user-222", email="b@wardrobe.io", role="authenticated")

    # Override auth to User A
    app.dependency_overrides[get_optional_current_user] = lambda: user_a
    files = {"file": ("item.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_data = {"name": "User A Leather Jacket", "category": "outerwear", "primary_color": "Black"}
    create_res = client.post("/api/wardrobe/items", data=form_data, files=files)
    assert create_res.status_code == 201
    item_id = create_res.json()["id"]

    # Switch to User B
    app.dependency_overrides[get_optional_current_user] = lambda: user_b

    # User B cannot view User A's item
    assert client.get(f"/api/wardrobe/items/{item_id}").status_code == 404

    # User B cannot update User A's item
    assert client.put(f"/api/wardrobe/items/{item_id}", json={"name": "Hacked"}).status_code == 404

    # User B cannot replace photo of User A's item
    f_replace = {"file": ("new.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    assert client.put(f"/api/wardrobe/items/{item_id}/photo", files=f_replace).status_code == 404

    # User B cannot delete User A's item
    assert client.delete(f"/api/wardrobe/items/{item_id}").status_code == 404

    # User B's list does not contain User A's item
    list_res = client.get("/api/wardrobe/items")
    assert list_res.status_code == 200
    user_b_ids = [i["id"] for i in list_res.json()]
    assert item_id not in user_b_ids

    # Switch back to User A and delete
    app.dependency_overrides[get_optional_current_user] = lambda: user_a
    del_res = client.delete(f"/api/wardrobe/items/{item_id}")
    assert del_res.status_code == 204

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_bulk_create_wardrobe_items(client, db_session):
    from app.main import app
    from app.auth.supabase_auth import get_optional_current_user

    user = AuthenticatedUser(id="user-bulk-test", email="bulk@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    payload = {
        "items": [
            {
                "client_id": "c1",
                "name": "Extracted Linen Shirt",
                "category": "shirts",
                "primary_color": "White",
                "material": "Linen",
                "image_path": "extracted/item1.jpg",
            },
            {
                "client_id": "c2",
                "name": "Extracted Denim Jeans",
                "category": "jeans",
                "primary_color": "Blue",
                "material": "Denim",
                "image_path": "extracted/item2.jpg",
            },
        ],
        "source_analysis_id": "analysis-123",
    }

    res = client.post("/api/wardrobe/items/bulk", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["saved_count"] == 2
    assert data["failed_count"] == 0
    assert len(data["results"]) == 2
    assert data["results"][0]["client_id"] == "c1"
    assert data["results"][0]["item"]["name"] == "Extracted Linen Shirt"
    assert data["results"][1]["client_id"] == "c2"
    assert data["results"][1]["item"]["name"] == "Extracted Denim Jeans"

    # Test deduplication on retry
    res_retry = client.post("/api/wardrobe/items/bulk", json=payload)
    assert res_retry.status_code == 201
    retry_data = res_retry.json()
    assert retry_data["saved_count"] == 2
    assert retry_data["results"][0]["item"]["id"] == data["results"][0]["item"]["id"]
    assert retry_data["results"][1]["item"]["id"] == data["results"][1]["item"]["id"]

    # Verify both records exist independently in the user's wardrobe list
    list_res = client.get("/api/wardrobe/items")
    assert list_res.status_code == 200
    names = [i["name"] for i in list_res.json()]
    assert "Extracted Linen Shirt" in names
    assert "Extracted Denim Jeans" in names

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_bulk_create_separate_identical_items_in_same_batch(client, db_session):
    """
    Verify that duplicate prevention does NOT incorrectly suppress legitimate separate items
    within the same bulk request (e.g. matching accessories/earrings or items from same outfit).
    """
    from app.main import app
    from app.auth.supabase_auth import get_optional_current_user

    user = AuthenticatedUser(id="user-earrings-test", email="earrings@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    # Two identical earrings in the same outfit capture
    payload = {
        "items": [
            {
                "client_id": "earring-left",
                "name": "Gold Hoop Earring",
                "category": "accessories",
                "primary_color": "Gold",
                "material": "Gold",
                "image_path": "extracted/earring.jpg",
            },
            {
                "client_id": "earring-right",
                "name": "Gold Hoop Earring",
                "category": "accessories",
                "primary_color": "Gold",
                "material": "Gold",
                "image_path": "extracted/earring.jpg",
            },
        ],
        "source_analysis_id": "analysis-earrings",
    }

    res = client.post("/api/wardrobe/items/bulk", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["saved_count"] == 2
    assert data["failed_count"] == 0
    assert len(data["results"]) == 2

    id1 = data["results"][0]["item"]["id"]
    id2 = data["results"][1]["item"]["id"]

    # Crucial: Both must be created with separate database IDs
    assert id1 != id2

    # Verify both exist in wardrobe
    list_res = client.get("/api/wardrobe/items?category=accessories")
    assert list_res.status_code == 200
    user_items = [i for i in list_res.json() if i["name"] == "Gold Hoop Earring"]
    assert len(user_items) == 2

    # Retry should be idempotent: mapping client_ids to their respective items without duplicates
    retry_res = client.post("/api/wardrobe/items/bulk", json=payload)
    assert retry_res.status_code == 201
    retry_data = retry_res.json()
    assert retry_data["saved_count"] == 2
    assert retry_data["failed_count"] == 0

    # Ensure no additional duplicate rows were inserted
    list_res_after = client.get("/api/wardrobe/items?category=accessories")
    user_items_after = [i for i in list_res_after.json() if i["name"] == "Gold Hoop Earring"]
    assert len(user_items_after) == 2

    app.dependency_overrides.pop(get_optional_current_user, None)
