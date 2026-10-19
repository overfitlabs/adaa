def test_recommendations_empty_wardrobe(client):
    res = client.get("/api/recommendations")
    assert res.status_code == 200
    data = res.json()
    assert len(data) >= 1
    assert "Capsule Foundation" in data[0]["title"]
