import io
from datetime import datetime, timedelta
from unittest.mock import patch
import pytest

from app.models import TryOnTaskRecord, WardrobeItem
from app.api.routes_tryon import cleanup_expired_tryon_tasks
from tests.test_supabase_auth import generate_test_jwt, SupabaseJWTVerifier, TEST_PROJECT_URL, TEST_SECRET


def test_tryon_ownership_isolation(client, db_session, sample_image_bytes):
    token_user_a = generate_test_jwt(sub="user-tryon-a", email="usera@test.com")
    token_user_b = generate_test_jwt(sub="user-tryon-b", email="userb@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # 1. User A creates a try-on task
        files = {
            "user_image": ("body.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
            "garment_image": ("garment.jpg", io.BytesIO(sample_image_bytes), "image/jpeg"),
        }
        res_create = client.post(
            "/api/tryon/tasks",
            data={"garment_category": "upper body"},
            files=files,
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_create.status_code == 202
        task_id = res_create.json()["task_id"]

        # 2. User A can view their own task status
        res_get_a = client.get(
            f"/api/tryon/tasks/{task_id}",
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_get_a.status_code == 200
        assert res_get_a.json()["task_id"] == task_id

        # 3. User B cannot view User A's task status (404)
        res_get_b = client.get(
            f"/api/tryon/tasks/{task_id}",
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_get_b.status_code == 404

        # 4. Anonymous caller cannot view User A's task status (404)
        res_get_anon = client.get(f"/api/tryon/tasks/{task_id}")
        assert res_get_anon.status_code == 404

        # 5. User B cannot delete User A's task (404)
        res_del_b = client.delete(
            f"/api/tryon/tasks/{task_id}",
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_del_b.status_code == 404

        # 6. User A can delete their task
        res_del_a = client.delete(
            f"/api/tryon/tasks/{task_id}",
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_del_a.status_code == 204


def test_tryon_7_day_retention_cleanup(tmp_path, db_session):
    from app.config import settings

    now = datetime.utcnow()
    # 1. Create task expired 8 days ago
    expired_task = TryOnTaskRecord(
        user_id="user-retention-test",
        user_image_path="tryon/expired_user.jpg",
        garment_image_path="tryon/expired_garment.jpg",
        storage_provider="local",
        status="success",
        expires_at=now - timedelta(days=1),
    )

    # 2. Create task valid for another 6 days
    valid_task = TryOnTaskRecord(
        user_id="user-retention-test",
        user_image_path="tryon/valid_user.jpg",
        garment_image_path="tryon/valid_garment.jpg",
        storage_provider="local",
        status="success",
        expires_at=now + timedelta(days=6),
    )

    # 3. Create legacy unowned task without expires_at (must NOT be deleted)
    legacy_task = TryOnTaskRecord(
        user_id=None,
        user_image_path="tryon/legacy_user.jpg",
        garment_image_path="tryon/legacy_garment.jpg",
        storage_provider="local",
        status="success",
        expires_at=None,
    )

    db_session.add_all([expired_task, valid_task, legacy_task])
    db_session.commit()

    # Create dummy local files
    tryon_dir = settings.storage_path / "tryon"
    tryon_dir.mkdir(parents=True, exist_ok=True)
    expired_file = tryon_dir / "expired_user.jpg"
    valid_file = tryon_dir / "valid_user.jpg"
    legacy_file = tryon_dir / "legacy_user.jpg"

    expired_file.write_bytes(b"expired")
    valid_file.write_bytes(b"valid")
    legacy_file.write_bytes(b"legacy")

    # Run cleanup
    cleaned = cleanup_expired_tryon_tasks(db_session)
    assert cleaned == 1

    # Verify expired task and file are gone
    assert db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == expired_task.id).first() is None
    assert not expired_file.is_file()

    # Verify valid task and file are preserved
    assert db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == valid_task.id).first() is not None
    assert valid_file.is_file()

    # Verify legacy unowned task without expires_at is preserved
    assert db_session.query(TryOnTaskRecord).filter(TryOnTaskRecord.id == legacy_task.id).first() is not None
    assert legacy_file.is_file()

    # Clean up dummy files
    if valid_file.is_file():
        valid_file.unlink()
    if legacy_file.is_file():
        legacy_file.unlink()

    # Second run should be idempotent
    cleaned_again = cleanup_expired_tryon_tasks(db_session)
    assert cleaned_again == 0
