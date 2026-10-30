import io
from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest
from fastapi import HTTPException, UploadFile
from PIL import Image

from app.config import settings
from app.services.image_storage import ImageStorageService, ImageMetadata


@pytest.fixture
def sample_pil_bytes():
    buf = io.BytesIO()
    img = Image.new("RGB", (100, 100), color=(200, 50, 50))
    img.save(buf, format="JPEG")
    return buf.getvalue()


@pytest.fixture
def sample_png_bytes():
    buf = io.BytesIO()
    img = Image.new("RGBA", (80, 80), color=(50, 200, 50, 255))
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_validate_and_sanitize_image_corrupt_rejection():
    service = ImageStorageService()
    file = UploadFile(filename="test.jpg", file=io.BytesIO(b"not an image file"))
    with pytest.raises(HTTPException) as exc_info:
        service.validate_and_sanitize_image(file, b"not an image file")
    assert exc_info.value.status_code == 400
    assert "Corrupt or invalid image file" in exc_info.value.detail


def test_validate_and_sanitize_image_oversized_rejection(sample_pil_bytes):
    service = ImageStorageService()
    file = UploadFile(filename="big.jpg", file=io.BytesIO(sample_pil_bytes))
    with patch.object(settings, "MAX_UPLOAD_SIZE_MB", 0):  # 0 MB forces 413
        with pytest.raises(HTTPException) as exc_info:
            service.validate_and_sanitize_image(file, sample_pil_bytes)
        assert exc_info.value.status_code == 413
        assert "Image exceeds size limit" in exc_info.value.detail


def test_validate_and_sanitize_image_strips_exif(sample_pil_bytes):
    service = ImageStorageService()
    file = UploadFile(filename="photo.jpg", file=io.BytesIO(sample_pil_bytes))
    clean_bytes, ext, w, h = service.validate_and_sanitize_image(file, sample_pil_bytes)
    assert ext == "jpg"
    assert w == 100
    assert h == 100
    # Clean image should be a valid readable JPEG
    with Image.open(io.BytesIO(clean_bytes)) as img:
        assert img.format == "JPEG"
        # No EXIF dictionary present
        exif = img.getexif()
        assert len(exif) == 0


@pytest.mark.asyncio
async def test_upload_local_fallback(sample_pil_bytes, tmp_path):
    service = ImageStorageService(base_dir=tmp_path)
    file = UploadFile(filename="garment.jpg", file=io.BytesIO(sample_pil_bytes))

    with patch.object(settings, "STORAGE_BACKEND", "local"):
        meta = await service.upload(file, user_id="user-123", subfolder="wardrobe")
        assert meta.storage_provider == "local"
        assert meta.public_id.startswith("wardrobe/")
        assert meta.format == "jpg"
        assert (tmp_path / meta.public_id).is_file()


@pytest.mark.asyncio
async def test_upload_cloudinary_authenticated(sample_pil_bytes):
    service = ImageStorageService()
    file = UploadFile(filename="garment.jpg", file=io.BytesIO(sample_pil_bytes))

    mock_res = {
        "public_id": "wardrobelens/users/user-123/wardrobe/abc123xyz",
        "format": "jpg",
        "version": 1712345678,
        "width": 100,
        "height": 100,
        "bytes": len(sample_pil_bytes),
    }

    with patch.object(settings, "STORAGE_BACKEND", "cloudinary"), \
         patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch("cloudinary.uploader.upload", return_value=mock_res) as mock_upload:

        meta = await service.upload(file, user_id="user-123", subfolder="wardrobe")

        assert meta.storage_provider == "cloudinary"
        assert meta.public_id == "wardrobelens/users/user-123/wardrobe/abc123xyz"
        assert meta.version == "1712345678"

        mock_upload.assert_called_once()
        call_kwargs = mock_upload.call_args[1]
        assert call_kwargs["type"] == "authenticated"
        assert call_kwargs["resource_type"] == "image"
        assert call_kwargs["overwrite"] is False


@pytest.mark.asyncio
async def test_upload_cloudinary_failure_raises_502(sample_pil_bytes):
    service = ImageStorageService()
    file = UploadFile(filename="garment.jpg", file=io.BytesIO(sample_pil_bytes))

    with patch.object(settings, "STORAGE_BACKEND", "cloudinary"), \
         patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch("cloudinary.uploader.upload", side_effect=RuntimeError("Cloudinary gateway timeout")):

        with pytest.raises(HTTPException) as exc_info:
            await service.upload(file, user_id="user-123", subfolder="wardrobe")
        assert exc_info.value.status_code == 502
        assert "Image upload service unavailable" in exc_info.value.detail


def test_generate_delivery_url_local():
    service = ImageStorageService()
    url = service.generate_delivery_url("wardrobe/abc.jpg", storage_provider="local")
    assert url == "/storage/wardrobe/abc.jpg"


def test_generate_delivery_url_cloudinary_signed():
    service = ImageStorageService()
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"):

        url = service.generate_delivery_url(
            "wardrobelens/users/u1/wardrobe/item1",
            storage_provider="cloudinary",
            ttl_seconds=1800,
        )
        assert url.startswith("https://res.cloudinary.com/mycloud/image/authenticated/s--")
        assert "item1" in url


def test_generate_delivery_url_cloudinary_with_auth_token():
    service = ImageStorageService()
    hex_key = "0123456789abcdef0123456789abcdef"
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch.object(settings, "CLOUDINARY_AUTH_TOKEN_KEY", hex_key):

        url = service.generate_delivery_url(
            "wardrobelens/users/u1/wardrobe/item1",
            storage_provider="cloudinary",
            ttl_seconds=1800,
        )
        assert "__cld_token__=" in url
        assert "exp=" in url
        assert "hmac=" in url


def test_delete_asset(tmp_path):
    service = ImageStorageService(base_dir=tmp_path)
    local_file = tmp_path / "wardrobe" / "to_delete.jpg"
    local_file.parent.mkdir(parents=True, exist_ok=True)
    local_file.write_bytes(b"delete me")
    assert local_file.is_file()

    # Local delete
    assert service.delete("wardrobe/to_delete.jpg", storage_provider="local") is True
    assert not local_file.is_file()

    # Cloudinary delete
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch("cloudinary.uploader.destroy", return_value={"result": "ok"}) as mock_destroy:

        res = service.delete("wardrobelens/users/u1/wardrobe/item1", storage_provider="cloudinary")
        assert res is True
        mock_destroy.assert_called_once_with(
            "wardrobelens/users/u1/wardrobe/item1",
            type="authenticated",
            invalidate=True,
        )


def test_is_cloudinary_token_auth_configured_property():
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch.object(settings, "CLOUDINARY_AUTH_TOKEN_KEY", ""):
        assert settings.is_cloudinary_configured is True
        assert settings.is_cloudinary_token_auth_configured is False
        service = ImageStorageService()
        assert service.is_token_auth_active is False

    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch.object(settings, "CLOUDINARY_AUTH_TOKEN_KEY", "0123456789abcdef0123456789abcdef"):
        assert settings.is_cloudinary_token_auth_configured is True
        service = ImageStorageService()
        assert service.is_token_auth_active is True


def test_generate_delivery_url_custom_ttl():
    service = ImageStorageService()
    hex_key = "0123456789abcdef0123456789abcdef"
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "mycloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key123"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret456"), \
         patch.object(settings, "CLOUDINARY_AUTH_TOKEN_KEY", hex_key):

        url_300 = service.generate_delivery_url(
            "wardrobelens/users/u1/wardrobe/item1",
            storage_provider="cloudinary",
            ttl_seconds=300,
        )
        assert "__cld_token__=" in url_300
        assert "exp=" in url_300
        assert "hmac=" in url_300


def test_free_tier_authenticated_delivery_url_signed_without_token():
    """Verifies Cloudinary Free-tier delivery: HMAC path-signed URL (sign_url=True) without paid token."""
    service = ImageStorageService()
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "freecloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key_free"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret_free"), \
         patch.object(settings, "CLOUDINARY_AUTH_TOKEN_KEY", ""):

        url = service.generate_delivery_url(
            "wardrobelens/users/u1/wardrobe/shirt1",
            storage_provider="cloudinary",
            ttl_seconds=1800,
        )
        assert url.startswith("https://res.cloudinary.com/freecloud/image/authenticated/s--")
        assert "shirt1" in url
        assert "__cld_token__" not in url


def test_generate_private_download_url_api_endpoint():
    """Verifies Strategy A utility: time-limited private download URL via api.cloudinary.com REST API."""
    service = ImageStorageService()
    with patch.object(settings, "CLOUDINARY_CLOUD_NAME", "freecloud"), \
         patch.object(settings, "CLOUDINARY_API_KEY", "key_free"), \
         patch.object(settings, "CLOUDINARY_API_SECRET", "secret_free"):

        dl_url = service.generate_private_download_url(
            "wardrobelens/users/u1/wardrobe/shirt1",
            format="png",
            expires_at=1800000000,
            attachment=False,
        )
        assert dl_url.startswith("https://api.cloudinary.com/v1_1/freecloud/image/download?")
        assert "public_id=wardrobelens%2Fusers%2Fu1%2Fwardrobe%2Fshirt1" in dl_url
        assert "format=png" in dl_url
        assert "type=authenticated" in dl_url
        assert "expires_at=1800000000" in dl_url
        assert "signature=" in dl_url
        assert "api_key=key_free" in dl_url


