import io
import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from pathlib import Path
from app.services.vision_provider import GeminiVisionProvider


def test_analyze_outfit_image_and_history(client, sample_image_bytes):
    from app.schemas import DetectedFashionItem, StyleAttributes
    sample_item = DetectedFashionItem(
        id="item-test-1",
        category="jackets",
        sub_category="Blazer",
        name="Navy Wool Blazer",
        primary_color="Navy",
        attributes=StyleAttributes(material="wool", formality="smart-casual"),
    )
    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Classic tailored outfit", "Smart Casual", [sample_item])
        )
        mock_get_provider.return_value = mock_provider

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


def test_analyze_outfit_image_timeout_handling(client, sample_image_bytes):
    files = {"file": ("timeout_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=TimeoutError("Gemini AI vision analysis timed out after 40s. The service may be under heavy load.")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 504
        assert "timed out" in response.json()["detail"].lower()


def test_analyze_outfit_image_auth_failure_handling(client, sample_image_bytes):
    files = {"file": ("auth_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=PermissionError("Gemini API authentication failed. Please verify your GEMINI_API_KEY.")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 401
        assert "authentication failed" in response.json()["detail"].lower()


def test_analyze_outfit_image_unavailable_handling(client, sample_image_bytes):
    files = {"file": ("unavailable_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=RuntimeError("Gemini model is currently experiencing high demand. Please try again shortly. (status 503)")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 503
        assert "high demand" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_gemini_vision_provider_markdown_fences_and_parsing(tmp_path):
    # Create test image file
    from PIL import Image
    test_img_path = tmp_path / "test_garment.jpg"
    Image.new("RGB", (100, 100), color="blue").save(test_img_path)

    provider = GeminiVisionProvider(api_key="mock-key-for-unit-test", model_name="gemini-2.5-flash", timeout_seconds=5)

    mock_gemini_json = {
        "summary": "Crisp minimalist outfit",
        "vibe": "Minimalist Sartorial",
        "items": [
            {
                "category": "jackets",
                "sub_category": "Blazer",
                "name": "Navy Wool Blazer",
                "primary_color": "Navy",
                "secondary_color": None,
                "attributes": {
                    "pattern": "solid",
                    "material": "wool",
                    "fit": "tailored",
                    "formality": "smart-casual"
                },
                "confidence": 0.98,
                "bounding_box_description": "Upper body outer garment"
            }
        ]
    }
    # Wrap in markdown fences as LLMs frequently do
    wrapped_text = f"```json\n{json.dumps(mock_gemini_json)}\n```"

    mock_response = MagicMock()
    mock_response.text = wrapped_text

    with patch("google.genai.Client") as mock_client_cls:
        mock_client = MagicMock()
        mock_aio = MagicMock()
        mock_models = MagicMock()
        mock_models.generate_content = AsyncMock(return_value=mock_response)
        mock_aio.models = mock_models
        mock_client.aio = mock_aio
        mock_client_cls.return_value = mock_client

        summary, vibe, items = await provider.analyze_outfit_image(test_img_path)

        assert summary == "Crisp minimalist outfit"
        assert vibe == "Minimalist Sartorial"
        assert len(items) == 1
        assert items[0].name == "Navy Wool Blazer"
        assert items[0].category == "jackets"
        assert items[0].primary_color == "Navy"
        assert items[0].attributes.material == "wool"


def test_multi_item_extraction_with_crops(client, sample_image_bytes):
    from app.schemas import DetectedFashionItem, StyleAttributes
    items = [
        DetectedFashionItem(
            id="item-crop-1",
            category="jackets",
            sub_category="Blazer",
            name="Structured Blazer",
            primary_color="Navy",
            attributes=StyleAttributes(material="wool"),
            box_2d=[100, 150, 600, 850],
        ),
        DetectedFashionItem(
            id="item-crop-2",
            category="trousers",
            sub_category="Trousers",
            name="Pleated Trousers",
            primary_color="Charcoal",
            attributes=StyleAttributes(material="wool"),
            box_2d=[550, 200, 950, 800],
        ),
    ]
    files = {"file": ("outfit_multi.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Coordinated suit set", "Smart Casual", items)
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 2
        for it in data["items"]:
            assert it["extracted_image_url"] is not None
            assert it["extracted_image_path"] is not None
            assert it["box_2d"] is not None

        # Verify retrieval retains extracted images
        analysis_id = data["analysis_id"]
        get_res = client.get(f"/api/analysis/{analysis_id}")
        assert get_res.status_code == 200
        get_items = get_res.json()["items"]
        assert len(get_items) == 2
        assert get_items[0]["extracted_image_url"] is not None


def test_multi_item_overlapping_garments_and_storage_privacy(client, sample_image_bytes):
    from app.config import settings
    from app.schemas import DetectedFashionItem, StyleAttributes
    from app.main import app
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser

    user_a = AuthenticatedUser(id="user-overlap-owner", email="owner@adaa.style", role="authenticated")
    user_b = AuthenticatedUser(id="user-overlap-other", email="other@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user_a

    # Realistic outfit with overlapping layers and accessories:
    # 1. Outer blazer
    # 2. Inner shirt (spatially contained within blazer box)
    # 3. Gold chain necklace (accessory over shirt)
    # 4. Inverted/invalid box (ymin > ymax)
    items = [
        DetectedFashionItem(
            id="item-outer-blazer",
            category="jackets",
            sub_category="Blazer",
            name="Tailored Wool Blazer",
            primary_color="Navy",
            attributes=StyleAttributes(material="wool", fit="tailored"),
            box_2d=[100, 150, 750, 850],
        ),
        DetectedFashionItem(
            id="item-inner-shirt",
            category="shirts",
            sub_category="Dress Shirt",
            name="Poplin Cotton Shirt",
            primary_color="White",
            attributes=StyleAttributes(material="cotton"),
            box_2d=[200, 250, 600, 750],  # Overlapped by blazer
        ),
        DetectedFashionItem(
            id="item-necklace",
            category="accessories",
            sub_category="Necklace",
            name="Gold Chain Necklace",
            primary_color="Gold",
            attributes=StyleAttributes(material="gold"),
            box_2d=[180, 420, 280, 580],  # Small accessory on shirt
        ),
        DetectedFashionItem(
            id="item-invalid-coords",
            category="accessories",
            sub_category="Belt",
            name="Leather Dress Belt",
            primary_color="Brown",
            attributes=StyleAttributes(material="leather"),
            box_2d=[800, 600, 400, 200],  # Inverted coordinates: ymin > ymax, xmin > xmax
        ),
    ]

    files = {"file": ("outfit_overlap.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch.object(settings, "STORAGE_BACKEND", "local"), \
         patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Editorial layered outfit", "Classic Luxury", items)
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 4

        # Verify all crops were generated without error
        for it in data["items"]:
            assert it["extracted_image_url"] is not None
            assert it["extracted_image_path"] is not None

        # Verify storage route for extracted items
        blazer_item = data["items"][0]
        extracted_path = blazer_item["extracted_image_path"]
        extracted_filename = extracted_path.split("/")[-1]

        # 1. Owner can access via /storage/extracted/{filename} with auth token
        with patch("app.api.routes_storage.get_jwt_verifier") as mock_v:
            v_instance = MagicMock()
            v_instance.verify_token.return_value = user_a
            mock_v.return_value = v_instance

            headers_owner = {"Authorization": "Bearer valid-token-owner"}
            get_res = client.get(f"/storage/extracted/{extracted_filename}", headers=headers_owner)
            assert get_res.status_code == 200
            assert get_res.headers["content-type"] in ("image/jpeg", "image/png", "image/webp")
            assert len(get_res.content) > 0

        # 2. Unauthorized other user is denied (404)
        with patch("app.api.routes_storage.get_jwt_verifier") as mock_v:
            v_instance = MagicMock()
            v_instance.verify_token.return_value = user_b
            mock_v.return_value = v_instance

            headers_other = {"Authorization": "Bearer valid-token-other"}
            denied_res = client.get(f"/storage/extracted/{extracted_filename}", headers=headers_other)
            assert denied_res.status_code == 404

        # 3. Path traversal or invalid/unsupported extension is rejected (400)
        traversal_res = client.get("/storage/extracted/..test.jpg")
        assert traversal_res.status_code == 400

        unsupported_res = client.get("/storage/extracted/config.py")
        assert unsupported_res.status_code == 400

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_delete_analysis_owner_success(client, db_session):
    from app.models import OutfitAnalysisRecord
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    user = AuthenticatedUser(id="owner-del-test", email="owner@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    rec = OutfitAnalysisRecord(
        id="analysis-to-delete-1",
        user_id="owner-del-test",
        image_path="inspirations/outfit_del.jpg",
        storage_provider="local",
        items_json=json.dumps([
            {"id": "c1", "extracted_image_path": "extracted/crop_del1.jpg"},
            {"id": "c2", "extracted_image_path": "extracted/crop_del2.jpg"},
        ]),
    )
    db_session.add(rec)
    db_session.commit()

    with patch("app.api.routes_analysis.image_storage_service.delete", return_value=True) as mock_del:
        res = client.delete(f"/api/analysis/{rec.id}")
        assert res.status_code == 204

        deleted_assets = [call.args[0] for call in mock_del.call_args_list]
        assert "inspirations/outfit_del.jpg" in deleted_assets
        assert "extracted/crop_del1.jpg" in deleted_assets
        assert "extracted/crop_del2.jpg" in deleted_assets

    assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == "analysis-to-delete-1").first() is None
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_delete_analysis_cross_user_denial(client, db_session):
    from app.models import OutfitAnalysisRecord
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    user_owner = AuthenticatedUser(id="owner-user-xyz", email="owner@adaa.style", role="authenticated")
    user_other = AuthenticatedUser(id="other-user-abc", email="other@adaa.style", role="authenticated")

    rec = OutfitAnalysisRecord(
        id="analysis-cross-user-1",
        user_id="owner-user-xyz",
        image_path="inspirations/secret_fit.jpg",
        storage_provider="local",
        items_json="[]",
    )
    db_session.add(rec)
    db_session.commit()

    # User Other attempts to delete User Owner's record
    app.dependency_overrides[get_optional_current_user] = lambda: user_other
    with patch("app.api.routes_analysis.image_storage_service.delete") as mock_del:
        res = client.delete(f"/api/analysis/{rec.id}")
        assert res.status_code == 404
        mock_del.assert_not_called()

    # Anonymous user attempts to delete
    app.dependency_overrides[get_optional_current_user] = lambda: None
    with patch("app.api.routes_analysis.image_storage_service.delete") as mock_del:
        res = client.delete(f"/api/analysis/{rec.id}")
        assert res.status_code == 404
        mock_del.assert_not_called()

    assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == rec.id).first() is not None
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_delete_analysis_repeated_idempotence(client, db_session):
    from app.models import OutfitAnalysisRecord
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    user = AuthenticatedUser(id="repeat-del-user", email="user@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    rec = OutfitAnalysisRecord(
        id="analysis-repeat-1",
        user_id="repeat-del-user",
        image_path="inspirations/fit_repeat.jpg",
        storage_provider="local",
        items_json="[]",
    )
    db_session.add(rec)
    db_session.commit()

    with patch("app.api.routes_analysis.image_storage_service.delete", return_value=True):
        res1 = client.delete(f"/api/analysis/{rec.id}")
        assert res1.status_code == 204

        res2 = client.delete(f"/api/analysis/{rec.id}")
        assert res2.status_code == 404

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_delete_analysis_preserves_wardrobe_items(client, db_session):
    from app.models import OutfitAnalysisRecord, WardrobeItem
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    user = AuthenticatedUser(id="preserve-user", email="preserve@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    saved_crop_path = "extracted/saved_blazer_crop.jpg"
    unsaved_crop_path = "extracted/unsaved_tie_crop.jpg"
    main_photo_path = "inspirations/main_outfit.jpg"

    # User saved the blazer crop to their wardrobe
    wardrobe_item = WardrobeItem(
        id="w-item-preserved-1",
        user_id="preserve-user",
        name="Saved Navy Blazer",
        category="jackets",
        primary_color="Navy",
        image_path=saved_crop_path,
        storage_provider="local",
    )
    db_session.add(wardrobe_item)

    rec = OutfitAnalysisRecord(
        id="analysis-preserve-test",
        user_id="preserve-user",
        image_path=main_photo_path,
        storage_provider="local",
        items_json=json.dumps([
            {"id": "crop1", "extracted_image_path": saved_crop_path},
            {"id": "crop2", "extracted_image_path": unsaved_crop_path},
        ]),
    )
    db_session.add(rec)
    db_session.commit()

    with patch("app.api.routes_analysis.image_storage_service.delete", return_value=True) as mock_del:
        res = client.delete(f"/api/analysis/{rec.id}")
        assert res.status_code == 204

        deleted_assets = [call.args[0] for call in mock_del.call_args_list]
        assert main_photo_path in deleted_assets
        assert unsaved_crop_path in deleted_assets
        assert saved_crop_path not in deleted_assets

    assert db_session.query(WardrobeItem).filter(WardrobeItem.id == "w-item-preserved-1").first() is not None
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_delete_analysis_storage_failure_rollback(client, db_session):
    from app.models import OutfitAnalysisRecord
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    user = AuthenticatedUser(id="fail-user", email="fail@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: user

    rec = OutfitAnalysisRecord(
        id="analysis-storage-fail",
        user_id="fail-user",
        image_path="inspirations/outfit_err.jpg",
        storage_provider="local",
        items_json="[]",
    )
    db_session.add(rec)
    db_session.commit()

    with patch("app.api.routes_analysis.image_storage_service.delete", return_value=False):
        res = client.delete(f"/api/analysis/{rec.id}")
        assert res.status_code == 502
        assert "clean up storage" in res.json()["detail"].lower()

    assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == rec.id).first() is not None
    app.dependency_overrides.pop(get_optional_current_user, None)


def test_cleanup_abandoned_analyses_logic(db_session):
    from datetime import datetime, timedelta
    from app.models import OutfitAnalysisRecord, SavedOutfit
    from app.api.routes_analysis import cleanup_abandoned_analyses

    now = datetime.utcnow()
    old_abandoned = OutfitAnalysisRecord(
        id="scan-abandoned-old",
        user_id="test-clean-user",
        image_path="inspirations/old_abandoned.jpg",
        storage_provider="local",
        items_json="[]",
        created_at=now - timedelta(hours=30),
    )

    recent_scan = OutfitAnalysisRecord(
        id="scan-recent-active",
        user_id="test-clean-user",
        image_path="inspirations/recent_active.jpg",
        storage_provider="local",
        items_json="[]",
        created_at=now - timedelta(hours=2),
    )

    old_saved = OutfitAnalysisRecord(
        id="scan-old-saved-outfit",
        user_id="test-clean-user",
        image_path="inspirations/old_saved.jpg",
        storage_provider="local",
        items_json="[]",
        created_at=now - timedelta(hours=30),
    )
    saved_outfit = SavedOutfit(
        id="saved-outfit-ref-1",
        user_id="test-clean-user",
        name="Summer Linen Set",
        inspiration_analysis_id="scan-old-saved-outfit",
    )

    db_session.add_all([old_abandoned, recent_scan, old_saved, saved_outfit])
    db_session.commit()

    with patch("app.api.routes_analysis.image_storage_service.delete", return_value=True):
        result = cleanup_abandoned_analyses(db_session, max_age_hours=24)
        assert result["status"] == "success"
        assert result["abandoned_scans_cleaned"] == 1

        assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == "scan-abandoned-old").first() is None
        assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == "scan-recent-active").first() is not None
        assert db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == "scan-old-saved-outfit").first() is not None


def test_cleanup_endpoint_ordinary_user_denied(client):
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    ordinary_user = AuthenticatedUser(id="ordinary-user", email="user@adaa.style", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: ordinary_user

    res = client.post("/api/analysis/cleanup")
    assert res.status_code == 403
    assert "Operator authorization required" in res.json()["detail"]

    app.dependency_overrides[get_optional_current_user] = lambda: None
    res_anon = client.post("/api/analysis/cleanup")
    assert res_anon.status_code == 403

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_cleanup_endpoint_operator_secret_allowed(client, db_session):
    from app.config import settings
    with patch.object(settings, "OPERATOR_SECRET", "super-secret-operator-key"):
        headers = {"X-Operator-Secret": "super-secret-operator-key"}
        res = client.post("/api/analysis/cleanup", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "abandoned_scans_cleaned" in data


def test_cleanup_endpoint_admin_role_allowed(client, db_session):
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app

    admin_user = AuthenticatedUser(id="admin-user", email="admin@adaa.style", role="service_role")
    app.dependency_overrides[get_optional_current_user] = lambda: admin_user

    res = client.post("/api/analysis/cleanup")
    assert res.status_code == 200
    assert res.json()["status"] == "success"

    app.dependency_overrides.pop(get_optional_current_user, None)


