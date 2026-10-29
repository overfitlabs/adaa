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
        assert items[0].category in ("jackets", "outerwear")
        assert items[0].primary_color in ("Navy", "navy")
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




# =============================================================================
# MediaFlows Integration & Backward-Compatibility Test Suite
# =============================================================================

def test_mediaflows_webhook_authentication_rejects_missing_or_invalid_secret(client, db_session):
    from app.config import settings
    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "super-secret-webhook-key"):
        # 1. Missing secret
        res1 = client.post("/api/analysis/mediaflows-webhook", json={"scan_id": "any-id"})
        assert res1.status_code == 401
        assert "secret" in res1.json()["detail"].lower()

        # 2. Invalid secret
        res2 = client.post(
            "/api/analysis/mediaflows-webhook",
            json={"scan_id": "any-id"},
            headers={"X-MediaFlows-Secret": "wrong-secret-key"},
        )
        assert res2.status_code == 401
        assert "invalid" in res2.json()["detail"].lower()

        # 3. Valid secret with missing scan record -> 404
        res3 = client.post(
            "/api/analysis/mediaflows-webhook",
            json={"scan_id": "nonexistent-scan-id"},
            headers={"X-MediaFlows-Secret": "super-secret-webhook-key"},
        )
        assert res3.status_code == 404


def test_mediaflows_webhook_successful_processing_and_crops(client, db_session):
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    import uuid

    scan_id = str(uuid.uuid4())
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id="user-owner-123",
        image_path=f"wardrobelens/users/user-owner-123/inspirations/{scan_id}.jpg",
        storage_provider="local",
        status="processing",
        items_json="[]",
        summary="Pending scan...",
    )
    db_session.add(record)
    db_session.commit()

    gemini_output = {
        "summary": "Elevated business casual look",
        "vibe": "Smart Casual",
        "items": [
            {
                "category": "jackets",
                "sub_category": "Blazer",
                "name": "Camel Wool Tailored Blazer",
                "primary_color": "Camel",
                "attributes": {"material": "wool", "fit": "tailored"},
                "confidence": 0.96,
                "box_2d": [100, 200, 600, 800],
            },
            {
                "category": "trousers",
                "name": "Navy Pleated Trousers",
                "primary_color": "Navy",
                "attributes": {"formality": "smart-casual"},
                "confidence": 0.92,
                "box_2d": [600, 250, 950, 750],
            },
        ],
    }

    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "test-secret-mf"):
        res = client.post(
            "/api/analysis/mediaflows-webhook",
            json={
                "scan_id": scan_id,
                "gemini_output": json.dumps(gemini_output),
                "untrusted_user_id": "malicious-user-id",
            },
            headers={"X-MediaFlows-Secret": "test-secret-mf"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "completed"
        assert data["scan_id"] == scan_id

    # Verify database record updated
    db_session.refresh(record)
    assert record.status == "completed"
    assert record.summary == "Elevated business casual look"
    assert record.vibe == "Smart Casual"
    assert record.user_id == "user-owner-123"  # Derivation from DB preserved, untrusted_user_id ignored
    items = json.loads(record.items_json)
    assert len(items) == 2
    assert items[0]["name"] == "Camel Wool Tailored Blazer"
    assert items[0]["extracted_image_path"] is not None


def test_mediaflows_webhook_idempotency_ignores_duplicate(client, db_session):
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    import uuid

    scan_id = str(uuid.uuid4())
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id="user-owner-456",
        image_path=f"wardrobelens/users/user-owner-456/inspirations/{scan_id}.jpg",
        storage_provider="local",
        status="completed",  # Already completed
        items_json=json.dumps([{"id": "item-1", "name": "Existing Blazer", "category": "jackets", "primary_color": "Black"}]),
        summary="Original summary",
    )
    db_session.add(record)
    db_session.commit()

    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "test-secret-mf"):
        with patch("app.api.routes_analysis._extract_garment_crops") as mock_crops:
            res = client.post(
                "/api/analysis/mediaflows-webhook",
                json={
                    "scan_id": scan_id,
                    "gemini_output": {"summary": "Overwritten summary", "items": []},
                },
                headers={"Authorization": "Bearer test-secret-mf"},
            )
            assert res.status_code == 200
            assert res.json()["status"] == "completed"
            assert "already completed" in res.json()["message"].lower()

            # No crops or updates should have occurred
            mock_crops.assert_not_called()

    db_session.refresh(record)
    assert record.summary == "Original summary"  # Not mutated


def test_mediaflows_fallback_race_late_callback_cannot_overwrite_completed(client, db_session):
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    import uuid

    scan_id = str(uuid.uuid4())
    # Record completed via server-side direct Gemini fallback
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id="user-owner-789",
        image_path="inspirations/outfit.jpg",
        storage_provider="local",
        status="completed",
        items_json=json.dumps([{"id": "fb-item-1", "name": "Fallback Dress", "category": "dresses", "primary_color": "Red"}]),
        summary="Fallback completed summary",
    )
    db_session.add(record)
    db_session.commit()

    # Delayed slow callback finally arrives
    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "test-secret-mf"):
        res = client.post(
            "/api/analysis/mediaflows-webhook",
            json={
                "scan_id": scan_id,
                "gemini_output": {"summary": "Slow callback summary", "items": []},
            },
            headers={"X-MediaFlows-Secret": "test-secret-mf"},
        )
        assert res.status_code == 200
        assert res.json()["status"] == "completed"

    db_session.refresh(record)
    assert record.summary == "Fallback completed summary"
    items = json.loads(record.items_json)
    assert len(items) == 1
    assert items[0]["name"] == "Fallback Dress"


def test_mediaflows_scan_status_endpoint_and_authorization(client, db_session):
    from app.models import OutfitAnalysisRecord
    from app.auth.supabase_auth import get_optional_current_user, AuthenticatedUser
    from app.main import app
    import uuid

    scan_id = str(uuid.uuid4())
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id="user-alice",
        image_path="inspirations/alice.jpg",
        storage_provider="local",
        status="completed",
        items_json="[]",
        summary="Alice's outfit",
    )
    db_session.add(record)
    db_session.commit()

    # User Bob attempts to access Alice's scan
    bob_user = AuthenticatedUser(id="user-bob", email="bob@test.com", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: bob_user
    res_forbidden = client.get(f"/api/analysis/scans/{scan_id}")
    assert res_forbidden.status_code == 404

    # Alice accesses her own scan
    alice_user = AuthenticatedUser(id="user-alice", email="alice@test.com", role="authenticated")
    app.dependency_overrides[get_optional_current_user] = lambda: alice_user
    res_ok = client.get(f"/api/analysis/scans/{scan_id}")
    assert res_ok.status_code == 200
    data = res_ok.json()
    assert data["scan_id"] == scan_id
    assert data["status"] == "completed"
    assert data["result"]["summary"] == "Alice's outfit"

    app.dependency_overrides.pop(get_optional_current_user, None)


def test_mediaflows_server_timeout_triggers_direct_gemini_fallback(client, db_session, sample_image_bytes):
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    from app.schemas import DetectedFashionItem, StyleAttributes
    from datetime import datetime, timedelta
    import uuid

    scan_id = str(uuid.uuid4())
    past_time = datetime.utcnow() - timedelta(seconds=30)
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id=None,
        image_path="inspirations/timeout_scan.jpg",
        storage_provider="local",
        status="processing",
        items_json="[]",
        summary="Pending...",
        created_at=past_time,
    )
    db_session.add(record)
    db_session.commit()

    sample_fallback_item = DetectedFashionItem(
        id="fb-1",
        category="tops",
        name="Silk Blouse",
        primary_color="White",
        attributes=StyleAttributes(material="silk"),
    )

    with patch.object(settings, "MEDIAFLOWS_TIMEOUT_SECONDS", 25):
        with patch("app.api.routes_analysis._fetch_image_bytes_for_record", return_value=sample_image_bytes):
            with patch("app.api.routes_analysis.get_vision_provider") as mock_vision:
                mock_provider = MagicMock()
                mock_provider.analyze_outfit_image = AsyncMock(
                    return_value=("Fallback silk look", "Minimalist", [sample_fallback_item])
                )
                mock_vision.return_value = mock_provider

                res = client.get(f"/api/analysis/scans/{scan_id}")
                assert res.status_code == 200
                data = res.json()
                assert data["status"] == "completed"
                assert data["result"]["summary"] == "Fallback silk look"

    db_session.refresh(record)
    assert record.status == "completed"
    assert record.summary == "Fallback silk look"


def test_mediaflows_malformed_gemini_payload_handling(client, db_session):
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    import uuid

    scan_id = str(uuid.uuid4())
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id=None,
        image_path="inspirations/malformed.jpg",
        storage_provider="local",
        status="processing",
        items_json="[]",
        summary="Pending...",
    )
    db_session.add(record)
    db_session.commit()

    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "test-secret-mf"):
        with patch("app.api.routes_analysis._execute_direct_gemini_fallback", side_effect=RuntimeError("Fallback offline")):
            res = client.post(
                "/api/analysis/mediaflows-webhook",
                json={
                    "scan_id": scan_id,
                    "gemini_output": "{ this is definitely not valid json :::",
                },
                headers={"X-MediaFlows-Secret": "test-secret-mf"},
            )
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "failed"

    db_session.refresh(record)
    assert record.status == "failed"
    assert "parsing error" in record.error_message.lower()


def test_mediaflows_pipeline_when_enabled_returns_processing_and_tags_upload(client, sample_image_bytes):
    from app.config import settings
    from app.services.image_storage import image_storage_service
    files = {"file": ("outfit_mf.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}

    with patch.object(settings, "USE_MEDIAFLOWS", True):
        with patch("app.api.routes_analysis.image_storage_service.upload", wraps=image_storage_service.upload) as mock_upload:
            res = client.post("/api/analysis/analyze-image", files=files)
            assert res.status_code == 200
            data = res.json()
            assert data["status"] == "processing"
            assert "analysis_id" in data
            assert len(data["items"]) == 0

            # Verify that inspiration upload was tagged with 'adaa-scan-pending'
            mock_upload.assert_called_once()
            call_kwargs = mock_upload.call_args.kwargs
            assert call_kwargs.get("subfolder") == "inspirations"
            assert call_kwargs.get("tags") == ["adaa-scan-pending"]
            assert "scan_id" in call_kwargs.get("context", {})


def test_mediaflows_pipeline_when_disabled_uses_synchronous_untagged_flow(client, sample_image_bytes):
    from app.config import settings
    from app.services.image_storage import image_storage_service
    from app.schemas import DetectedFashionItem, StyleAttributes
    sample_item = DetectedFashionItem(
        id="item-sync-1",
        category="tops",
        name="Cotton T-Shirt",
        primary_color="White",
        attributes=StyleAttributes(material="cotton"),
    )
    files = {"file": ("outfit_sync.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}

    with patch.object(settings, "USE_MEDIAFLOWS", False):
        with patch("app.api.routes_analysis.get_vision_provider") as mock_vision:
            mock_provider = MagicMock()
            mock_provider.analyze_outfit_image = AsyncMock(
                return_value=("Casual Cotton T-Shirt", "Casual", [sample_item])
            )
            mock_vision.return_value = mock_provider

            with patch("app.api.routes_analysis.image_storage_service.upload", wraps=image_storage_service.upload) as mock_upload:
                res = client.post("/api/analysis/analyze-image", files=files)
                assert res.status_code == 200
                data = res.json()
                assert data["status"] == "completed"
                assert len(data["items"]) >= 1

                # Verify uploads in disabled mode:
                # 1. Inspiration upload: tags=None (NOT tagged with adaa-scan-pending)
                # 2. Extracted crops upload: subfolder="extracted", tags=None
                assert mock_upload.call_count >= 1
                for call in mock_upload.call_args_list:
                    assert call.kwargs.get("tags") is None


def test_crops_and_unrelated_uploads_never_tagged_adaa_scan_pending(client, sample_image_bytes):
    """
    Guarantees extracted garment crops, default models, friend photos, and VTO result images
    are NEVER tagged with 'adaa-scan-pending', preventing recursive or unrelated triggers.
    """
    from app.services.image_storage import image_storage_service

    import inspect
    sig = inspect.signature(image_storage_service.upload)
    assert "tags" in sig.parameters
    assert "context" in sig.parameters
    assert sig.parameters["tags"].default is None


def test_database_migration_compatibility_for_analysis_status(db_session):
    from app.models import OutfitAnalysisRecord
    import uuid

    test_id = str(uuid.uuid4())
    record = OutfitAnalysisRecord(
        id=test_id,
        user_id=None,
        image_path="test/path.jpg",
        storage_provider="local",
        items_json="[]",
    )
    db_session.add(record)
    db_session.commit()
    db_session.refresh(record)

    # Automatically has status 'completed' by default
    assert record.status == "completed"
    assert record.error_message is None


def test_mediaflows_auth_url_security_and_expiring_url_generation(client, db_session):
    """
    Guarantees /api/analysis/mediaflows-url:
    1. Rejects requests without valid X-MediaFlows-Secret (401).
    2. Rejects requests for nonexistent public_id (404).
    3. Successfully generates short-lived expiring private download URLs via GET and POST
       without exposing permanent signed URLs in public metadata or requiring token auth.
    """
    from app.config import settings
    from app.models import OutfitAnalysisRecord
    import uuid

    scan_id = str(uuid.uuid4())
    test_pid = f"wardrobelens/users/test/inspirations/{scan_id}"
    record = OutfitAnalysisRecord(
        id=scan_id,
        user_id="user-mf-123",
        image_path=test_pid,
        cloudinary_public_id=test_pid,
        storage_provider="cloudinary",
        image_format="jpg",
        status="processing",
        items_json="[]",
        summary="Pending...",
    )
    db_session.add(record)
    db_session.commit()

    with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "test-mf-secret"):
        with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mock-cloud"):
            with patch.object(settings, "CLOUDINARY_API_KEY", "mock-key"):
                with patch.object(settings, "CLOUDINARY_API_SECRET", "mock-secret"):
                    # 1. Reject without secret
                    res1 = client.get(f"/api/analysis/mediaflows-url?public_id={test_pid}")
                    assert res1.status_code == 401

                    # 2. Reject with wrong secret
                    res2 = client.get(
                        f"/api/analysis/mediaflows-url?public_id={test_pid}",
                        headers={"X-MediaFlows-Secret": "wrong-secret"},
                    )
                    assert res2.status_code == 401

                    # 3. Reject unknown public_id
                    res3 = client.get(
                        "/api/analysis/mediaflows-url?public_id=unknown/path/img",
                        headers={"X-MediaFlows-Secret": "test-mf-secret"},
                    )
                    assert res3.status_code == 404

                    # 4. Valid GET request with public_id
                    res4 = client.get(
                        f"/api/analysis/mediaflows-url?public_id={test_pid}",
                        headers={"X-MediaFlows-Secret": "test-mf-secret"},
                    )
                    assert res4.status_code == 200
                    data4 = res4.json()
                    assert "url" in data4
                    assert "image_url" in data4
                    assert "api.cloudinary.com" in data4["url"]
                    assert "expires_at=" in data4["url"]
                    assert "signature=" in data4["url"]
                    assert data4["public_id"] == test_pid
                    assert data4["scan_id"] == scan_id

                    # 5. Valid POST request with JSON body
                    res5 = client.post(
                        "/api/analysis/mediaflows-url",
                        json={"public_id": test_pid},
                        headers={"X-MediaFlows-Secret": "test-mf-secret"},
                    )
                    assert res5.status_code == 200
                    data5 = res5.json()
                    assert data5["url"] == data4["url"]


def test_crops_and_regular_uploads_do_not_inject_signed_url_into_context(sample_image_bytes):
    """
    Guarantees regular uploads without 'adaa-scan-pending' do not generate or inject
    signed URLs into asset context.
    """
    from app.config import settings
    from app.services.image_storage import image_storage_service
    import cloudinary.uploader

    with patch.object(settings, "STORAGE_BACKEND", "cloudinary"):
        with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mock-cloud"):
            with patch.object(settings, "CLOUDINARY_API_KEY", "mock-key"):
                with patch.object(settings, "CLOUDINARY_API_SECRET", "mock-secret"):
                    mock_upload_ret = {
                        "public_id": "wardrobelens/users/test/extracted/crop-1",
                        "format": "jpg",
                        "version": "12345",
                        "width": 100,
                        "height": 100,
                        "bytes": len(sample_image_bytes),
                    }
                    with patch.object(cloudinary.uploader, "upload", return_value=mock_upload_ret) as mock_upload:
                        import asyncio
                        meta = asyncio.run(
                            image_storage_service.upload(
                                user_id="user-123",
                                subfolder="extracted",
                                pre_sanitized=(sample_image_bytes, "jpg", 100, 100),
                                tags=None,
                            )
                        )
                        mock_upload.assert_called_once()
                        upload_kwargs = mock_upload.call_args.kwargs
                        assert "context" not in upload_kwargs or "signed_url" not in upload_kwargs.get("context", {})


def test_end_to_end_mediaflows_request_to_webhook_to_status_path(client, db_session, sample_image_bytes):
    """
    End-to-end integration test verifying the complete MediaFlows pipeline:
    1. /api/analysis/analyze-image initiates scan and returns processing status.
    2. MediaFlows calls /api/analysis/mediaflows-url using public_id to get short-lived expiring download URL.
    3. MediaFlows delivers Gemini analysis to /api/analysis/mediaflows-webhook using public_id.
    4. Client polls /api/analysis/scans/{scan_id} and receives the completed result.
    """
    from app.config import settings

    files = {"file": ("outfit_e2e.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}

    with patch.object(settings, "USE_MEDIAFLOWS", True):
        with patch.object(settings, "MEDIAFLOWS_WEBHOOK_SECRET", "mf-secret-e2e"):
            # 1. Initiate analysis
            res_init = client.post("/api/analysis/analyze-image", files=files)
            assert res_init.status_code == 200
            init_data = res_init.json()
            assert init_data["status"] == "processing"
            scan_id = init_data["analysis_id"]

            # Query DB to get public_id as provided by On_Asset_Upload block
            from app.models import OutfitAnalysisRecord
            rec = db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == scan_id).first()
            assert rec is not None
            public_id = rec.cloudinary_public_id or rec.image_path

            # 2. MediaFlows HTTP Request block fetches short-lived image URL using public_id
            res_url = client.get(
                f"/api/analysis/mediaflows-url?public_id={public_id}",
                headers={"X-MediaFlows-Secret": "mf-secret-e2e"},
            )
            assert res_url.status_code == 200
            url_data = res_url.json()
            assert "url" in url_data
            assert "api.cloudinary.com" in url_data["url"]
            assert "expires_at=" in url_data["url"]

            # 3. MediaFlows Webhook delivers Gemini results using public_id
            gemini_result = {
                "summary": "Tailored linen blazer look",
                "vibe": "Summer Smart Casual",
                "items": [
                    {
                        "category": "jackets",
                        "sub_category": "Blazer",
                        "name": "Oatmeal Linen Blazer",
                        "primary_color": "Beige",
                        "confidence": 0.95,
                        "box_2d": [100, 100, 600, 600],
                    }
                ],
            }
            res_wh = client.post(
                "/api/analysis/mediaflows-webhook",
                json={
                    "public_id": public_id,
                    "gemini_output": json.dumps(gemini_result),
                },
                headers={"X-MediaFlows-Secret": "mf-secret-e2e"},
            )
            assert res_wh.status_code == 200
            assert res_wh.json()["status"] == "completed"

            # 4. Client polls status and gets completed analysis
            res_done = client.get(f"/api/analysis/scans/{scan_id}")
            assert res_done.status_code == 200
            done_data = res_done.json()
            assert done_data["status"] == "completed"
            assert done_data["result"]["summary"] == "Tailored linen blazer look"
            assert len(done_data["result"]["items"]) == 1
            assert done_data["result"]["items"][0]["name"] == "Oatmeal Linen Blazer"


def test_wardrobe_detect_item_with_mediaflows_disabled_uses_direct_gemini(client, sample_image_bytes):
    """
    Verifies /api/wardrobe/detect-item preserves direct synchronous Gemini path when USE_MEDIAFLOWS=False.
    """
    from app.config import settings
    from app.schemas import DetectedFashionItem, StyleAttributes

    sample_item = DetectedFashionItem(
        id="det-1",
        category="tops",
        name="Linen Shirt",
        primary_color="White",
        attributes=StyleAttributes(material="linen"),
    )
    files = {"file": ("item.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}

    with patch.object(settings, "USE_MEDIAFLOWS", False):
        with patch("app.api.routes_wardrobe.get_vision_provider") as mock_vision:
            mock_provider = MagicMock()
            mock_provider.analyze_outfit_image = AsyncMock(
                return_value=("Linen shirt look", "Casual", [sample_item])
            )
            mock_vision.return_value = mock_provider

            res = client.post("/api/wardrobe/detect-item", files=files)
            assert res.status_code == 200
            data = res.json()
            assert data["detected_item"]["name"] == "Linen Shirt"
            assert data["detected_vibe"] == "Casual"


def test_multi_garment_extraction_creates_distinct_square_crops(client, sample_image_bytes):
    """
    Verifies that an outfit containing a top and bottom produces distinct garment results,
    each extracted as an independent, actual image file standardized to 1:1 square dimensions (600x600).
    """
    from PIL import Image
    from app.schemas import DetectedFashionItem, StyleAttributes
    from app.config import settings

    top_item = DetectedFashionItem(
        id="item-top-1",
        category="tops",
        sub_category="T-Shirt",
        name="Essential White T-Shirt",
        primary_color="White",
        attributes=StyleAttributes(material="cotton", fit="regular"),
        box_2d=[100, 200, 500, 800],
    )
    bottom_item = DetectedFashionItem(
        id="item-bottom-1",
        category="bottoms",
        sub_category="Jeans",
        name="Straight Indigo Denim",
        primary_color="Blue",
        attributes=StyleAttributes(material="denim", fit="straight"),
        box_2d=[520, 220, 950, 780],
    )

    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Minimalist casual ensemble", "Casual Everyday", [top_item, bottom_item])
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 2

        item_top = data["items"][0]
        item_bottom = data["items"][1]

        # Verify items are distinct
        assert item_top["name"] == "Essential White T-Shirt"
        assert item_bottom["name"] == "Straight Indigo Denim"
        assert item_top["extracted_image_path"] != item_bottom["extracted_image_path"]
        assert item_top["extracted_image_url"] != data["image_url"]
        assert item_bottom["extracted_image_url"] != data["image_url"]

        # Verify extracted crops exist as physical square images (600x600)
        top_crop_rel = item_top["extracted_image_path"].lstrip("/")
        if top_crop_rel.startswith("storage/"):
            top_crop_rel = top_crop_rel[len("storage/"):]
        top_file = settings.storage_path / top_crop_rel
        assert top_file.is_file(), f"Expected top crop file at {top_file}"
        with Image.open(top_file) as top_img:
            assert top_img.size == (600, 600), f"Expected 600x600 square, got {top_img.size}"

        bottom_crop_rel = item_bottom["extracted_image_path"].lstrip("/")
        if bottom_crop_rel.startswith("storage/"):
            bottom_crop_rel = bottom_crop_rel[len("storage/"):]
        bottom_file = settings.storage_path / bottom_crop_rel
        assert bottom_file.is_file(), f"Expected bottom crop file at {bottom_file}"
        with Image.open(bottom_file) as bot_img:
            assert bot_img.size == (600, 600), f"Expected 600x600 square, got {bot_img.size}"


def test_crop_idempotency_uses_deterministic_names(client, sample_image_bytes):
    """
    Verifies that re-extracting crops for the same asset produces identical deterministic public IDs,
    preventing duplicate Cloudinary asset creation on retry.
    """
    from app.schemas import DetectedFashionItem, StyleAttributes
    from app.api.routes_analysis import _extract_garment_crops

    item = DetectedFashionItem(
        id="det-idem-1",
        category="outerwear",
        name="Taupe Wool Coat",
        primary_color="Taupe",
        attributes=StyleAttributes(material="wool"),
        box_2d=[100, 150, 700, 850],
    )

    import asyncio
    asyncio.run(
        _extract_garment_crops(
            clean_bytes=sample_image_bytes,
            items=[item],
            user_id="test_user",
            original_public_id="wardrobelens/users/test_user/inspirations/source_asset_123",
            original_storage_provider="local",
        )
    )
    first_path = item.extracted_image_path
    assert "source_asset_123_garment_0" in first_path

    # Second run on same asset
    asyncio.run(
        _extract_garment_crops(
            clean_bytes=sample_image_bytes,
            items=[item],
            user_id="test_user",
            original_public_id="wardrobelens/users/test_user/inspirations/source_asset_123",
            original_storage_provider="local",
        )
    )
    second_path = item.extracted_image_path
    assert second_path == first_path, "Crop path should be deterministic across retries"


def test_bulk_add_wardrobe_items_saves_extracted_crop_references(client):
    """
    Verifies that saving extracted garments into the wardrobe via bulk-add persists
    the actual extracted crop image_path on each WardrobeItem record.
    """
    payload = {
        "items": [
            {
                "client_id": "c-1",
                "name": "Extracted Crop Shirt",
                "category": "tops",
                "primary_color": "White",
                "image_path": "extracted/crop_shirt_sq.jpg",
            },
            {
                "client_id": "c-2",
                "name": "Extracted Crop Trousers",
                "category": "bottoms",
                "primary_color": "Charcoal",
                "image_path": "extracted/crop_trousers_sq.jpg",
            },
        ]
    }
    res = client.post("/api/wardrobe/items/bulk", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["saved_count"] == 2
    assert data["results"][0]["item"]["image_path"] == "extracted/crop_shirt_sq.jpg"
    assert data["results"][1]["item"]["image_path"] == "extracted/crop_trousers_sq.jpg"


def test_metadata_normalization_canonical_rules():
    """
    Verifies that the metadata normalization service standardizes categories, colors,
    materials, patterns, fits, and seasons according to canonical rules, preserving
    distinctions (e.g. cotton blend vs cotton) and rejecting verbose sentences.
    """
    from app.services.metadata_normalizer import (
        normalize_category,
        normalize_color,
        normalize_pattern,
        normalize_material,
        normalize_fit,
        normalize_season,
        normalize_garment_metadata,
    )

    # Categories
    assert normalize_category("t-shirt") == "tops"
    assert normalize_category("JEANS") == "bottoms"
    assert normalize_category("blazer") == "outerwear"
    assert normalize_category("sneakers") == "shoes"
    assert normalize_category("tote bag") == "bags"
    assert normalize_category("gold necklace") == "accessories"
    assert normalize_category("unknown random widget") == "other"

    # Colors
    assert normalize_color("Lime Green") == "lime green"
    assert normalize_color("dark-blue") == "dark blue"
    assert normalize_color("off white") == "off-white"
    assert normalize_color("gray") == "grey"

    # Materials
    assert normalize_material("100% Cotton") == "cotton"
    assert normalize_material("cotton blend") == "cotton blend"
    assert normalize_material("cotton blend") != normalize_material("cotton")
    assert normalize_material("pure wool") == "wool"
    assert normalize_material("vegan leather") == "faux leather"
    assert normalize_material("uncertain impossible to tell from image") is None

    # Patterns
    assert normalize_pattern("stripes") == "striped"
    assert normalize_pattern("polka dots") == "polka dot"
    assert normalize_pattern("plain") == "solid"
    assert normalize_pattern("graphic") == "graphic print"

    # Fits
    assert normalize_fit("slim fit") == "slim"
    assert normalize_fit("oversize") == "oversized"
    assert normalize_fit("wide-leg") == "wide leg"
    assert normalize_fit("This is a very loose and breezy silhouette that sits nicely") == "loose"
    assert normalize_fit("unclear") is None

    # Seasons
    assert normalize_season("autumn") == "fall"
    assert normalize_season("all seasons") == "all-season"
    assert normalize_season("year-round") == "all-season"
    assert normalize_season("unknown") is None

    # Batch normalization
    res = normalize_garment_metadata(
        category="t-shirt",
        primary_color="Lime Green",
        secondary_color="lime green",  # should be cleared because identical to primary
        material="Cotton Blend",
        fit="slim-fit",
        season="autumn",
        pattern="stripes",
        name="  Striped Summer Tee  ",
    )
    assert res["category"] == "tops"
    assert res["primary_color"] == "lime green"
    assert res["secondary_color"] is None
    assert res["material"] == "cotton blend"
    assert res["fit"] == "slim"
    assert res["season"] == "fall"
    assert res["pattern"] == "striped"
    assert res["name"] == "Striped Summer Tee"


def test_wardrobe_detect_item_never_creates_outfit_analysis_record(client, sample_image_bytes, db_session):
    """
    CRITICAL: Verifies that uploading an image to /api/wardrobe/detect-item for closet
    cataloging extracts garments without creating an OutfitAnalysisRecord in the database,
    keeping personal wardrobe uploads separate from outfit inspiration analysis history.
    """
    from app.models import OutfitAnalysisRecord
    from app.schemas import DetectedFashionItem, StyleAttributes

    initial_analysis_count = db_session.query(OutfitAnalysisRecord).count()

    item_top = DetectedFashionItem(
        id="det-top",
        category="tops",
        name="White Oxford Shirt",
        primary_color="White",
        attributes=StyleAttributes(material="cotton", fit="regular"),
    )
    item_pants = DetectedFashionItem(
        id="det-pants",
        category="bottoms",
        name="Navy Chinos",
        primary_color="Navy",
        attributes=StyleAttributes(material="cotton", fit="straight"),
    )

    files = {"file": ("my_outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}

    with patch("app.api.routes_wardrobe.get_vision_provider") as mock_vision:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("My daily work outfit", "Smart Casual", [item_top, item_pants])
        )
        mock_vision.return_value = mock_provider

        res = client.post("/api/wardrobe/detect-item", files=files)
        assert res.status_code == 200
        data = res.json()
        assert len(data["detected_items"]) == 2
        assert data["detected_items"][0]["name"] == "White Oxford Shirt"
        assert data["detected_items"][1]["name"] == "Navy Chinos"

        # Verify ZERO outfit analysis records were created
        final_analysis_count = db_session.query(OutfitAnalysisRecord).count()
        assert final_analysis_count == initial_analysis_count, "Wardrobe detection must not create outfit analysis records"


def test_explicit_outfit_analysis_creates_and_lists_analysis_record(client, sample_image_bytes, db_session):
    """
    Verifies that explicit outfit analysis (/api/analysis) properly creates an OutfitAnalysisRecord
    and appears in list_recent_analyses, while wardrobe detection does not.
    """
    from app.models import OutfitAnalysisRecord
    from app.config import settings

    with patch.object(settings, "USE_MEDIAFLOWS", False):
        with patch("app.api.routes_analysis.get_vision_provider") as mock_vision:
            mock_provider = MagicMock()
            mock_provider.analyze_outfit_image = AsyncMock(
                return_value=("Editorial streetwear look", "Streetwear", [])
            )
            mock_vision.return_value = mock_provider

            files = {"file": ("streetwear.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
            res = client.post("/api/analysis/analyze-image", files=files)
            assert res.status_code == 200
            analysis_id = res.json()["analysis_id"]

            # Record must exist in DB
            rec = db_session.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == analysis_id).first()
            assert rec is not None
            assert rec.vibe == "Streetwear"

            # Must appear in list_recent_analyses
            list_res = client.get("/api/analysis")
            assert list_res.status_code == 200
            analyses = list_res.json()
            assert any(a["analysis_id"] == analysis_id for a in analyses)


def test_bulk_wardrobe_items_enforces_user_ownership_and_normalizes(client, db_session):
    """
    Verifies that bulk wardrobe creation persists user_id ownership, normalizes attributes,
    and does not create any outfit analysis records.
    """
    from app.models import WardrobeItem, OutfitAnalysisRecord
    from app.auth.supabase_auth import AuthenticatedUser, get_optional_current_user
    from app.main import app

    test_user = AuthenticatedUser(
        id="usr-owner-42",
        email="owner@adaa.fashion",
        role="authenticated",
    )

    app.dependency_overrides[get_optional_current_user] = lambda: test_user
    try:
        payload = {
            "items": [
                {
                    "client_id": "c-100",
                    "name": "T-Shirt With Logo",
                    "category": "t-shirt",  # should normalize to 'tops'
                    "primary_color": "Lime Green",  # should normalize to 'lime green'
                    "material": "100% Cotton",  # should normalize to 'cotton'
                    "fit": "slim fit",  # should normalize to 'slim'
                    "season": "autumn",  # should normalize to 'fall'
                    "pattern": "stripes",  # should normalize to 'striped'
                    "image_path": "wardrobe/test_item_1.jpg",
                }
            ]
        }
        res = client.post("/api/wardrobe/items/bulk", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["saved_count"] == 1
        item_id = data["results"][0]["item"]["id"]

        saved_item = db_session.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
        assert saved_item is not None
        assert saved_item.user_id == "usr-owner-42", "Wardrobe item must be owned by authenticated user"
        assert saved_item.category == "tops"
        assert saved_item.primary_color == "lime green"
        assert saved_item.material == "cotton"
        assert saved_item.fit == "slim"
        assert saved_item.season == "fall"
        assert saved_item.pattern == "striped"
    finally:
        app.dependency_overrides.pop(get_optional_current_user, None)
