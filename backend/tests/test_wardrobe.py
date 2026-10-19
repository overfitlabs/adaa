import io


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
        "formality": "smart-casual",
        "tags": '["classic", "office", "autumn"]',
    }
    response = client.post("/api/wardrobe/items", data=form_data, files=files)
    assert response.status_code == 201
    item = response.json()
    assert item["name"] == "Navy Wool Blazer"
    assert item["category"] == "jackets"
    assert item["primary_color"] == "Navy"
    assert "classic" in item["tags"]
    item_id = item["id"]

    # Get single item
    get_res = client.get(f"/api/wardrobe/items/{item_id}")
    assert get_res.status_code == 200
    assert get_res.json()["id"] == item_id

    # Filter by category
    cat_res = client.get("/api/wardrobe/items?category=jackets")
    assert cat_res.status_code == 200
    assert len(cat_res.json()) >= 1

    # Search item
    search_res = client.get("/api/wardrobe/items?search=Blazer")
    assert search_res.status_code == 200
    assert len(search_res.json()) >= 1

    # Update item
    update_res = client.put(
        f"/api/wardrobe/items/{item_id}",
        json={"name": "Updated Navy Wool Blazer", "fit": "Oversized"},
    )
    assert update_res.status_code == 200
    assert update_res.json()["name"] == "Updated Navy Wool Blazer"
    assert update_res.json()["fit"] == "Oversized"

    # Delete item
    del_res = client.delete(f"/api/wardrobe/items/{item_id}")
    assert del_res.status_code == 204

    # Verify deleted
    not_found_res = client.get(f"/api/wardrobe/items/{item_id}")
    assert not_found_res.status_code == 404
