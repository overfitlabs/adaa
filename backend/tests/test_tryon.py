import io
import json
from app.config import settings
from app.models import OutfitAnalysisRecord, WardrobeItem, TryOnTaskRecord


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


def test_tryon_with_attached_inspiration_and_detected_crops(client, db_session, sample_image_bytes):
    insp_dir = settings.storage_path / "inspirations"
    insp_dir.mkdir(parents=True, exist_ok=True)
    crop_file = insp_dir / "blazer_crop.jpg"
    crop_file.write_bytes(sample_image_bytes)

    detected_items = [
        {
            "id": "item-blazer-999",
            "name": "Tailored Velvet Blazer",
            "category": "outerwear",
            "primary_color": "emerald",
            "attributes": {"material": "velvet", "fit": "tailored"},
            "confidence": 0.96,
            "extracted_image_path": "inspirations/blazer_crop.jpg",
        }
    ]
    analysis = OutfitAnalysisRecord(
        image_path="inspirations/full_outfit.jpg",
        storage_provider="local",
        items_json=json.dumps(detected_items),
        summary="Chic Evening Outfit",
        vibe="formal",
        status="completed",
    )
    db_session.add(analysis)
    db_session.commit()
    db_session.refresh(analysis)

    initial_analyses_count = db_session.query(OutfitAnalysisRecord).count()
    initial_wardrobe_count = db_session.query(WardrobeItem).count()

    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    form_data = {
        "inspiration_analysis_id": analysis.id,
        "inspiration_item_id": "item-blazer-999",
        "garment_category": "auto",
    }

    res = client.post("/api/tryon/tasks", files=files, data=form_data)
    assert res.status_code == 202
    data = res.json()
    assert data["status"] in ["pending", "processing"]
    assert data["inspiration_analysis_id"] == analysis.id

    task_rec = db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == data["task_id"]).first()
    assert task_rec is not None
    assert task_rec.garment_image_path == "inspirations/blazer_crop.jpg"
    assert task_rec.inspiration_analysis_id == analysis.id

    # Verify no duplicate analysis or wardrobe records were created
    assert db_session.query(OutfitAnalysisRecord).count() == initial_analyses_count
    assert db_session.query(WardrobeItem).count() == initial_wardrobe_count


def test_tryon_with_attached_inspiration_full_image_without_crops(client, db_session, sample_image_bytes):
    insp_dir = settings.storage_path / "inspirations"
    insp_dir.mkdir(parents=True, exist_ok=True)
    full_img = insp_dir / "monochrome_look.jpg"
    full_img.write_bytes(sample_image_bytes)

    analysis = OutfitAnalysisRecord(
        image_path="inspirations/monochrome_look.jpg",
        storage_provider="local",
        items_json="[]",
        summary="Monochrome Minimalist Outfit",
        vibe="minimalist",
        status="completed",
    )
    db_session.add(analysis)
    db_session.commit()
    db_session.refresh(analysis)

    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    form_data = {
        "inspiration_analysis_id": analysis.id,
        "garment_category": "dress",
    }

    res = client.post("/api/tryon/tasks", files=files, data=form_data)
    assert res.status_code == 202
    data = res.json()
    assert data["inspiration_analysis_id"] == analysis.id

    task_rec = db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == data["task_id"]).first()
    assert task_rec is not None
    assert task_rec.garment_image_path == "inspirations/monochrome_look.jpg"


def test_tryon_with_wardrobe_item_and_attached_inspiration_context(client, db_session, sample_image_bytes):
    wardrobe_dir = settings.storage_path / "wardrobe"
    wardrobe_dir.mkdir(parents=True, exist_ok=True)
    w_img = wardrobe_dir / "user_pants.jpg"
    w_img.write_bytes(sample_image_bytes)

    wardrobe_item = WardrobeItem(
        name="Tailored Pleated Trousers",
        category="bottoms",
        primary_color="charcoal",
        image_path="wardrobe/user_pants.jpg",
        storage_provider="local",
    )
    db_session.add(wardrobe_item)

    analysis = OutfitAnalysisRecord(
        image_path="inspirations/street_vibe.jpg",
        storage_provider="local",
        items_json="[]",
        summary="Street Style Inspiration",
        vibe="streetwear",
        status="completed",
    )
    db_session.add(analysis)
    db_session.commit()
    db_session.refresh(wardrobe_item)
    db_session.refresh(analysis)

    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    form_data = {
        "wardrobe_item_id": wardrobe_item.id,
        "inspiration_analysis_id": analysis.id,
        "garment_category": "lower body",
    }

    res = client.post("/api/tryon/tasks", files=files, data=form_data)
    assert res.status_code == 202
    data = res.json()
    assert data["inspiration_analysis_id"] == analysis.id

    task_rec = db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == data["task_id"]).first()
    assert task_rec is not None
    assert task_rec.garment_image_path == "wardrobe/user_pants.jpg"
    assert task_rec.inspiration_analysis_id == analysis.id


def test_tryon_standalone_requires_garment_input(client, sample_image_bytes):
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    form_data = {"garment_category": "upper body"}

    res = client.post("/api/tryon/tasks", files=files, data=form_data)
    assert res.status_code == 400
    assert "Either a garment image file, a wardrobe_item_id, or an attached inspiration must be provided" in res.json()["detail"]
