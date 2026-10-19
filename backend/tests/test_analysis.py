import io


def test_analyze_outfit_image_and_history(client, sample_image_bytes):
    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    response = client.post("/api/analysis/analyze-image", files=files)
    assert response.status_code == 200
    data = response.json()
    assert "analysis_id" in data
    assert "summary" in data
    assert "vibe_or_style" in data
    assert len(data["items"]) >= 1

    analysis_id = data["analysis_id"]

    # Retrieve by ID
    get_res = client.get(f"/api/analysis/{analysis_id}")
    assert get_res.status_code == 200
    assert get_res.json()["analysis_id"] == analysis_id

    # List history
    list_res = client.get("/api/analysis")
    assert list_res.status_code == 200
    assert any(a["analysis_id"] == analysis_id for a in list_res.json())
