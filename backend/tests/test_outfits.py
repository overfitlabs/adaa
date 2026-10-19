import io


def test_saved_outfit_lifecycle(client, sample_image_bytes):
    # 1. Create a wardrobe item
    files = {"file": ("tee.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    form_data = {
        "name": "White Essential Tee",
        "category": "tops",
        "primary_color": "White",
    }
    w_res = client.post("/api/wardrobe/items", data=form_data, files=files)
    item_id = w_res.json()["id"]

    # 2. Save an outfit
    payload = {
        "name": "Minimalist Saturday Look",
        "occasion": "Casual Weekend",
        "notes": "Pair with white sneakers",
        "item_ids": [item_id],
    }
    outfit_res = client.post("/api/outfits", json=payload)
    assert outfit_res.status_code == 201
    outfit_data = outfit_res.json()
    assert outfit_data["name"] == "Minimalist Saturday Look"
    assert len(outfit_data["items"]) == 1
    assert outfit_data["items"][0]["id"] == item_id
    outfit_id = outfit_data["id"]

    # 3. List outfits
    list_res = client.get("/api/outfits")
    assert list_res.status_code == 200
    assert any(o["id"] == outfit_id for o in list_res.json())

    # 4. Delete outfit
    del_res = client.delete(f"/api/outfits/{outfit_id}")
    assert del_res.status_code == 204
