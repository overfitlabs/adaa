import io


def test_tryon_task_creation_and_polling(client, sample_image_bytes):
    # Upload user image and garment image
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    form_data = {"garment_category": "upper body"}

    res = client.post("/api/tryon/tasks", files=files, data=form_data)
    assert res.status_code == 202
    task = res.json()
    assert "task_id" in task
    assert task["status"] in ["pending", "processing"]
    task_id = task["task_id"]

    # Poll status (first poll returns processing or success)
    poll_1 = client.get(f"/api/tryon/tasks/{task_id}")
    assert poll_1.status_code == 200

    # Poll status (second poll in mock provider transitions to success)
    poll_2 = client.get(f"/api/tryon/tasks/{task_id}")
    assert poll_2.status_code == 200
    assert poll_2.json()["status"] == "success"
    assert poll_2.json()["result_image_url"] is not None
