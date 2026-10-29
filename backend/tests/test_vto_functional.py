import io
from unittest.mock import patch, AsyncMock, MagicMock
import httpx
import pytest
from PIL import Image

from app.models import TryOnTaskRecord, WardrobeItem
from app.config import settings
from app.api import routes_tryon
from app.services.tryon_provider import YouCamTryOnProvider
from tests.test_supabase_auth import generate_test_jwt, SupabaseJWTVerifier, TEST_PROJECT_URL, TEST_SECRET


def test_vto_wardrobe_ownership_enforcement(client, db_session, sample_image_bytes):
    token_user_a = generate_test_jwt(sub="user-vto-owner", email="owner@test.com")
    token_user_b = generate_test_jwt(sub="user-vto-intruder", email="intruder@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # 1. Create wardrobe item owned by User A
        item_a = WardrobeItem(
            user_id="user-vto-owner",
            name="Silk Trench Coat",
            category="outerwear",
            primary_color="beige",
            image_path="wardrobe/trench.jpg",
            storage_provider="local",
        )
        db_session.add(item_a)
        db_session.commit()
        db_session.refresh(item_a)

        # Write dummy local file for test
        storage_p = settings.storage_path / "wardrobe"
        storage_p.mkdir(parents=True, exist_ok=True)
        (storage_p / "trench.jpg").write_bytes(sample_image_bytes)

        # 2. User B attempts to initiate try-on using User A's wardrobe item
        files = {
            "user_image": ("selfie.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        }
        res_intruder = client.post(
            "/api/tryon/tasks",
            data={
                "wardrobe_item_id": item_a.id,
                "garment_category": "outer",
            },
            files=files,
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_intruder.status_code == 404
        assert "not found" in res_intruder.json()["detail"].lower()

        # 3. User A uses their own item -> success 202
        res_owner = client.post(
            "/api/tryon/tasks",
            data={
                "wardrobe_item_id": item_a.id,
                "garment_category": "outer",
            },
            files={"user_image": ("selfie.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")},
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_owner.status_code == 202
        assert res_owner.json()["task_id"] is not None


def test_vto_garment_category_validation(client, sample_image_bytes):
    # Invalid category
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    res_invalid = client.post(
        "/api/tryon/tasks",
        data={"garment_category": "super_unsupported_category_123"},
        files=files,
    )
    assert res_invalid.status_code == 400
    assert "invalid garment_category" in res_invalid.json()["detail"].lower()

    # Valid categories
    for cat in ["upper body", "dress", "outer", "auto"]:
        files_valid = {
            "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
            "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        }
        res_valid = client.post(
            "/api/tryon/tasks",
            data={"garment_category": cat},
            files=files_valid,
        )
        assert res_valid.status_code == 202


def test_vto_image_dimension_validation(client):
    """Images below 128x128 should be rejected with 400 Bad Request."""
    tiny_img = Image.new("RGB", (64, 64), color="red")
    buf = io.BytesIO()
    tiny_img.save(buf, format="JPEG")
    tiny_bytes = buf.getvalue()

    ok_img = Image.new("RGB", (200, 200), color="blue")
    buf_ok = io.BytesIO()
    ok_img.save(buf_ok, format="JPEG")
    ok_bytes = buf_ok.getvalue()

    # User image too small
    files = {
        "user_image": ("tiny.jpg", io.BytesIO(tiny_bytes), "image/jpeg"),
        "garment_image": ("ok.jpg", io.BytesIO(ok_bytes), "image/jpeg"),
    }
    res = client.post("/api/tryon/tasks", data={"garment_category": "upper_body"}, files=files)
    assert res.status_code == 400
    assert "128x128" in res.json()["detail"]

    # Garment image too small
    files = {
        "user_image": ("ok.jpg", io.BytesIO(ok_bytes), "image/jpeg"),
        "garment_image": ("tiny.jpg", io.BytesIO(tiny_bytes), "image/jpeg"),
    }
    res = client.post("/api/tryon/tasks", data={"garment_category": "upper_body"}, files=files)
    assert res.status_code == 400
    assert "128x128" in res.json()["detail"]


def test_youcam_category_normalization():
    """Verify that normalize_garment_category maps all supported aliases to official underscore formats."""
    from app.services.tryon_provider import normalize_garment_category

    assert normalize_garment_category("upper body") == "upper_body"
    assert normalize_garment_category("tops") == "upper_body"
    assert normalize_garment_category("lower body") == "lower_body"
    assert normalize_garment_category("pants") == "lower_body"
    assert normalize_garment_category("dress") == "full_body"
    assert normalize_garment_category("outerwear") == "outer"
    assert normalize_garment_category("shoes") == "shoes"
    assert normalize_garment_category("auto") == "auto"


@pytest.mark.asyncio
async def test_youcam_polling_null_results():
    """Verify that polling when results is None (e.g. running or error) doesn't raise AttributeError."""
    provider = YouCamTryOnProvider(
        api_key="mock_key",
        base_url="https://yce-api-01.makeupar.com/s2s/v2.0",
    )

    async def mock_get_running(url, *args, **kwargs):
        return httpx.Response(
            200,
            json={
                "status": 200,
                "data": {
                    "task_status": "running",
                    "results": None,
                },
            },
            request=httpx.Request("GET", url),
        )

    with patch("httpx.AsyncClient.get", side_effect=mock_get_running):
        status_info = await provider.get_task_status("task_running_123")
        assert status_info["status"] == "processing"
        assert status_info["result_url"] is None


@pytest.mark.asyncio
async def test_vto_youcam_provider_mocked_contract(sample_image_bytes):
    provider = YouCamTryOnProvider(
        api_key="mock_key_xyz",
        base_url="https://yce-api-01.makeupar.com/s2s/v2.0",
    )

    # Mock httpx client calls
    async def mock_post(url, *args, **kwargs):
        if url.endswith("/file"):
            return httpx.Response(
                200,
                json={
                    "status": 200,
                    "data": {
                        "files": [
                            {
                                "file_id": "file_ref_mock_123",
                                "requests": [
                                    {
                                        "method": "PUT",
                                        "url": "https://yce-us.s3-accelerate.amazonaws.com/test_put",
                                    }
                                ],
                            }
                        ]
                    },
                },
                request=httpx.Request("POST", url),
            )
        elif "/task" in url:
            return httpx.Response(
                200,
                json={
                    "status": 200,
                    "data": {
                        "task_id": "task_youcam_mock_456",
                    },
                },
                request=httpx.Request("POST", url),
            )
        return httpx.Response(404, request=httpx.Request("POST", url))

    async def mock_request(method, url, *args, **kwargs):
        return httpx.Response(200, request=httpx.Request(method, url))

    async def mock_get(url, *args, **kwargs):
        return httpx.Response(
            200,
            json={
                "status": 200,
                "data": {
                    "task_status": "success",
                    "results": {
                        "url": "https://cdn.perfectcorp.com/mock_result.jpg",
                    },
                },
            },
            request=httpx.Request("GET", url),
        )

    with patch("httpx.AsyncClient.post", side_effect=mock_post), \
         patch("httpx.AsyncClient.request", side_effect=mock_request), \
         patch("httpx.AsyncClient.get", side_effect=mock_get):

        task_info = await provider.create_tryon_task(
            user_image_bytes=sample_image_bytes,
            garment_image_bytes=sample_image_bytes,
            user_filename="user.jpg",
            garment_filename="garment.jpg",
            garment_category="upper body",
        )
        assert task_info["task_id"] == "task_youcam_mock_456"
        assert task_info["status"] == "processing"
        assert task_info["provider"] == "youcam"

        status_info = await provider.get_task_status("task_youcam_mock_456")
        assert status_info["status"] == "success"
        assert status_info["result_url"] == "https://cdn.perfectcorp.com/mock_result.jpg"


def test_vto_server_side_result_ingestion(client, sample_image_bytes, monkeypatch):
    """Verifies that an external result_url is downloaded server-side, sanitized, and stored."""
    # 1. Create a task in DB
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    res = client.post("/api/tryon/tasks", files=files, data={"garment_category": "upper body"})
    assert res.status_code == 202
    task_id = res.json()["task_id"]

    # 2. Mock provider to return an external URL
    mock_provider = MagicMock()
    mock_provider.get_task_status = AsyncMock(return_value={
        "task_id": "ext-123",
        "status": "success",
        "result_url": "https://external-cdn.example.com/vto_result.jpg",
        "error": None,
    })

    monkeypatch.setattr("app.api.routes_tryon.get_tryon_provider", lambda: mock_provider)

    # Mock httpx.AsyncClient.get for the server-side download
    async def mock_download_get(self, url, *args, **kwargs):
        return httpx.Response(200, content=sample_image_bytes, request=httpx.Request("GET", url))

    with patch("httpx.AsyncClient.get", mock_download_get):
        poll_res = client.get(f"/api/tryon/tasks/{task_id}")
        assert poll_res.status_code == 200
        data = poll_res.json()
        assert data["status"] == "success"
        # Must be served via application's private storage, NOT the external CDN
        assert "external-cdn.example.com" not in data["result_image_url"]
        assert "/storage/tryon/" in data["result_image_url"]


def test_vto_ssrf_protection_blocks_internal_destinations(client, sample_image_bytes, monkeypatch):
    """Verifies that result_url pointing to internal IPs or localhost is blocked as SSRF."""
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    res = client.post("/api/tryon/tasks", files=files, data={"garment_category": "upper body"})
    task_id = res.json()["task_id"]

    # Mock provider returning dangerous localhost SSRF URL
    mock_provider = MagicMock()
    mock_provider.get_task_status = AsyncMock(return_value={
        "task_id": "ext-ssrf",
        "status": "success",
        "result_url": "http://127.0.0.1:8000/api/internal-secret",
        "error": None,
    })
    monkeypatch.setattr("app.api.routes_tryon.get_tryon_provider", lambda: mock_provider)

    poll_res = client.get(f"/api/tryon/tasks/{task_id}")
    assert poll_res.status_code == 200
    data = poll_res.json()
    assert data["status"] == "failed"
    assert "error" in data["error_message"].lower()


def test_vto_history_authentication_required(client):
    """Anonymous requests to /api/tryon/history must return 401 Unauthorized."""
    res = client.get("/api/tryon/history")
    assert res.status_code == 401
    assert "authentication required" in res.json()["detail"].lower()


def test_vto_history_user_isolation_and_empty_state(client, db_session):
    """User B cannot see User A's try-on history, and an account with no tasks returns empty list."""
    token_user_a = generate_test_jwt(sub="user-vto-hist-a", email="a@test.com")
    token_user_b = generate_test_jwt(sub="user-vto-hist-b", email="b@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # User A has 1 successful try-on task
        task_a = TryOnTaskRecord(
            user_id="user-vto-hist-a",
            status="success",
            provider="mock",
            user_image_path="tryon/user_a.jpg",
            garment_image_path="tryon/garment_a.jpg",
            result_image_public_id="tryon/result_a.jpg",
            storage_provider="local",
        )
        db_session.add(task_a)
        db_session.commit()

        # User B queries history -> empty state
        res_b = client.get("/api/tryon/history", headers={"Authorization": f"Bearer {token_user_b}"})
        assert res_b.status_code == 200
        data_b = res_b.json()
        assert data_b["items"] == []
        assert data_b["total_count"] == 0
        assert data_b["has_more"] is False
        assert data_b["next_cursor"] is None

        # User A queries history -> sees task_a
        res_a = client.get("/api/tryon/history", headers={"Authorization": f"Bearer {token_user_a}"})
        assert res_a.status_code == 200
        data_a = res_a.json()
        assert len(data_a["items"]) == 1
        assert data_a["items"][0]["task_id"] == task_a.id
        assert data_a["total_count"] == 1


def test_vto_history_cursor_pagination_and_deterministic_order(client, db_session):
    """Verify cursor pagination with deterministic created_at DESC, id DESC sorting."""
    from datetime import datetime, timedelta
    token_user = generate_test_jwt(sub="user-vto-pages", email="pages@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        base_time = datetime(2026, 10, 20, 10, 0, 0)
        # Create 5 tasks with sequential timestamps
        tasks = []
        for i in range(5):
            t = TryOnTaskRecord(
                id=f"page-task-{i}",
                user_id="user-vto-pages",
                status="success",
                provider="mock",
                user_image_path=f"tryon/user_{i}.jpg",
                garment_image_path=f"tryon/garment_{i}.jpg",
                result_image_public_id=f"tryon/res_{i}.jpg",
                storage_provider="local",
                created_at=base_time + timedelta(hours=i),
            )
            tasks.append(t)
            db_session.add(t)
        db_session.commit()

        # Query page 1 (limit=2)
        res_p1 = client.get("/api/tryon/history?limit=2", headers={"Authorization": f"Bearer {token_user}"})
        assert res_p1.status_code == 200
        d1 = res_p1.json()
        assert len(d1["items"]) == 2
        assert d1["total_count"] == 5
        assert d1["has_more"] is True
        assert d1["next_cursor"] is not None
        # Newest first: page-task-4, page-task-3
        assert d1["items"][0]["task_id"] == "page-task-4"
        assert d1["items"][1]["task_id"] == "page-task-3"

        # Query page 2 with cursor
        cursor1 = d1["next_cursor"]
        res_p2 = client.get(f"/api/tryon/history?limit=2&cursor={cursor1}", headers={"Authorization": f"Bearer {token_user}"})
        assert res_p2.status_code == 200
        d2 = res_p2.json()
        assert len(d2["items"]) == 2
        assert d2["items"][0]["task_id"] == "page-task-2"
        assert d2["items"][1]["task_id"] == "page-task-1"
        assert d2["has_more"] is True

        # Query page 3 (last item)
        cursor2 = d2["next_cursor"]
        res_p3 = client.get(f"/api/tryon/history?limit=2&cursor={cursor2}", headers={"Authorization": f"Bearer {token_user}"})
        assert res_p3.status_code == 200
        d3 = res_p3.json()
        assert len(d3["items"]) == 1
        assert d3["items"][0]["task_id"] == "page-task-0"
        assert d3["has_more"] is False
        assert d3["next_cursor"] is None

        # Invalid cursor format returns 400 Bad Request
        res_invalid = client.get("/api/tryon/history?cursor=totally_bogus_token!!!", headers={"Authorization": f"Bearer {token_user}"})
        assert res_invalid.status_code == 400
        assert "cursor format" in res_invalid.json()["detail"].lower()


def test_vto_history_missing_and_expired_assets(client, db_session):
    """Missing or expired results return result_image_url=None and can_retry=False without 500 errors."""
    from datetime import datetime, timedelta
    token_user = generate_test_jwt(sub="user-vto-expired", email="exp@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # Expired task
        past_time = datetime.utcnow() - timedelta(days=10)
        task_exp = TryOnTaskRecord(
            user_id="user-vto-expired",
            status="success",
            provider="mock",
            user_image_path="tryon/u_old.jpg",
            garment_image_path="tryon/g_old.jpg",
            result_image_public_id=None,  # Cleaned up by retention
            storage_provider="local",
            expires_at=past_time,
        )
        db_session.add(task_exp)
        db_session.commit()

        res = client.get("/api/tryon/history", headers={"Authorization": f"Bearer {token_user}"})
        assert res.status_code == 200
        item = res.json()["items"][0]
        assert item["result_image_url"] is None
        assert item["can_retry"] is False


def test_vto_polling_idempotency_prevents_duplicate_uploads(client, sample_image_bytes, monkeypatch):
    """Verify that repeated polling on an already-processed task does not duplicate uploads."""
    files = {
        "user_image": ("user.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
    }
    res = client.post("/api/tryon/tasks", files=files, data={"garment_category": "upper body"})
    task_id = res.json()["task_id"]

    upload_mock = AsyncMock(wraps=routes_tryon.image_storage_service.upload)
    monkeypatch.setattr(routes_tryon.image_storage_service, "upload", upload_mock)

    # Mock provider succeeds on poll
    mock_provider = MagicMock()
    mock_provider.get_task_status = AsyncMock(return_value={
        "task_id": "idem-123",
        "status": "success",
        "result_url": "mock://test-result.jpg",
        "error": None,
    })
    monkeypatch.setattr("app.api.routes_tryon.get_tryon_provider", lambda: mock_provider)

    # Poll once -> succeeds and stores result
    poll1 = client.get(f"/api/tryon/tasks/{task_id}")
    assert poll1.status_code == 200
    assert poll1.json()["status"] == "success"
    first_call_count = upload_mock.call_count

    # Poll second time -> remains success, does NOT call upload again
    poll2 = client.get(f"/api/tryon/tasks/{task_id}")
    assert poll2.status_code == 200
    assert poll2.json()["status"] == "success"
    assert upload_mock.call_count == first_call_count


def test_tryon_model_crud_and_task_integration(client, sample_image_bytes, monkeypatch):
    """Test saving, retrieving, using, and deleting a default try-on model."""
    token = generate_test_jwt(sub="user-saved-model-1", email="model@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # 1. Initial check - no model saved
        get_res = client.get("/api/tryon/model", headers=headers)
        assert get_res.status_code == 200
        assert get_res.json()["has_model"] is False

        # 2. Upload default model
        files = {"image": ("my_body.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        post_res = client.post("/api/tryon/model", files=files, headers=headers)
        assert post_res.status_code == 201
        data = post_res.json()
        assert data["has_model"] is True
        assert data["image_url"] is not None

        # 3. Create try-on task using saved model (no user_image passed)
        g_files = {"garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        task_res = client.post(
            "/api/tryon/tasks",
            files=g_files,
            data={"garment_category": "upper body", "use_saved_model": "true"},
            headers=headers,
        )
        assert task_res.status_code == 202
        task_data = task_res.json()
        assert task_data["used_saved_model"] is True
        assert task_data["is_friend_tryon"] is False

        # 4. Delete the task -> model asset must NOT be deleted
        del_task = client.delete(f"/api/tryon/tasks/{task_data['task_id']}", headers=headers)
        assert del_task.status_code == 204

        # Verify model still exists
        verify_model = client.get("/api/tryon/model", headers=headers)
        assert verify_model.status_code == 200
        assert verify_model.json()["has_model"] is True

        # 5. Delete the default model
        del_model = client.delete("/api/tryon/model", headers=headers)
        assert del_model.status_code == 204

        get_res_after = client.get("/api/tryon/model", headers=headers)
        assert get_res_after.status_code == 200
        assert get_res_after.json()["has_model"] is False


def test_model_replacement_and_removal_preserves_task_assets(client, sample_image_bytes, monkeypatch):
    """Verify that removing a default model does NOT delete the asset if existing completed tasks reference it."""
    token = generate_test_jwt(sub="user-preserve-asset-1", email="preserve@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # Upload model
        files = {"image": ("body1.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        post_res = client.post("/api/tryon/model", files=files, headers=headers)
        assert post_res.status_code == 201

        # Create task using saved model
        g_files = {"garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        task_res = client.post(
            "/api/tryon/tasks",
            files=g_files,
            data={"garment_category": "upper body", "use_saved_model": "true"},
            headers=headers,
        )
        assert task_res.status_code == 202
        task_data = task_res.json()

        # Track storage deletion calls
        delete_mock = MagicMock(wraps=routes_tryon.image_storage_service.delete)
        monkeypatch.setattr(routes_tryon.image_storage_service, "delete", delete_mock)

        # Delete the default model while task exists
        del_res = client.delete("/api/tryon/model", headers=headers)
        assert del_res.status_code == 204

        # Verify image_storage_service.delete was NOT called because task references it
        assert delete_mock.call_count == 0



def test_friend_tryon_requires_consent(client, sample_image_bytes):
    """Test that friend try-on requires explicit consent and sets is_friend_tryon."""
    token = generate_test_jwt(sub="user-friend-1", email="friend@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # Friend try-on without consent -> 400
        files = {
            "user_image": ("friend.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
            "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        }
        res_fail = client.post(
            "/api/tryon/tasks",
            files=files,
            data={"garment_category": "upper body", "is_friend_tryon": "true", "friend_consent_acknowledged": "false"},
            headers=headers,
        )
        assert res_fail.status_code == 400
        assert "consent" in res_fail.json()["detail"].lower()

        # Friend try-on with consent -> success
        files2 = {
            "user_image": ("friend.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
            "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        }
        res_ok = client.post(
            "/api/tryon/tasks",
            files=files2,
            data={"garment_category": "upper body", "is_friend_tryon": "true", "friend_consent_acknowledged": "true"},
            headers=headers,
        )
        assert res_ok.status_code == 202
        assert res_ok.json()["is_friend_tryon"] is True
        assert res_ok.json()["used_saved_model"] is False




