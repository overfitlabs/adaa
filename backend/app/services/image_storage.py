import io
import logging
import os
import re
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from pydantic import BaseModel
from fastapi import HTTPException, UploadFile, status
from PIL import Image

from app.config import settings

logger = logging.getLogger("wardrobelens.image_storage")


class ImageMetadata(BaseModel):
    public_id: str
    storage_provider: str  # "cloudinary" | "local"
    format: Optional[str] = None
    version: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    bytes_size: Optional[int] = None


class ImageStorageService:
    """
    Unified Image Storage Service supporting:
    - Cloudinary authenticated storage (type='authenticated') with HMAC signed expiring URLs.
    - Local disk storage with path-traversal prevention for offline dev, unit tests, and legacy records.
    - Content validation, EXIF metadata stripping, and size enforcement.
    """

    def __init__(self, base_dir: Optional[Path] = None):
        self.base_dir = (base_dir or settings.storage_path).resolve()
        self.base_dir.mkdir(parents=True, exist_ok=True)
        (self.base_dir / "wardrobe").mkdir(exist_ok=True)
        (self.base_dir / "inspirations").mkdir(exist_ok=True)
        (self.base_dir / "tryon").mkdir(exist_ok=True)
        (self.base_dir / "profiles").mkdir(exist_ok=True)

    def _configure_cloudinary(self) -> None:
        if not settings.is_cloudinary_configured:
            return
        import cloudinary

        config_kwargs: Dict[str, Any] = {
            "cloud_name": settings.CLOUDINARY_CLOUD_NAME,
            "api_key": settings.CLOUDINARY_API_KEY,
            "api_secret": settings.CLOUDINARY_API_SECRET,
            "secure": settings.CLOUDINARY_SECURE_DELIVERY,
        }
        if settings.CLOUDINARY_AUTH_TOKEN_KEY:
            config_kwargs["auth_token"] = {
                "key": settings.CLOUDINARY_AUTH_TOKEN_KEY,
                "duration": settings.IMAGE_DELIVERY_TTL_SECONDS,
            }
        cloudinary.config(**config_kwargs)

    def validate_and_sanitize_image(
        self, file: UploadFile, contents: Optional[bytes] = None
    ) -> Tuple[bytes, str, int, int]:
        """
        Validates content type, verifies file integrity with Pillow,
        strips camera EXIF/GPS metadata, and returns (clean_bytes, ext, width, height).
        """
        filename = file.filename or "image.jpg"
        ext = filename.split(".")[-1].lower() if "." in filename else ""
        if ext not in settings.allowed_extensions_list:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported file type .{ext}. Allowed: {settings.allowed_extensions_list}",
            )

        raw_bytes = contents
        if raw_bytes is None:
            # Synchronous read inside caller or pre-read
            raise ValueError("File contents must be provided as bytes")

        if len(raw_bytes) > settings.max_upload_size_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Image exceeds size limit of {settings.MAX_UPLOAD_SIZE_MB}MB.",
            )

        try:
            with Image.open(io.BytesIO(raw_bytes)) as img:
                img.verify()

            # Re-open for sanitization (stripping EXIF metadata)
            with Image.open(io.BytesIO(raw_bytes)) as img:
                width, height = img.size
                image_format = (img.format or "JPEG").upper()
                if image_format not in ["JPEG", "PNG", "WEBP"]:
                    image_format = "JPEG"

                # Convert to RGB / RGBA cleanly without EXIF data
                if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                    clean_img = img.convert("RGBA")
                    save_format = "PNG" if image_format == "PNG" else "WEBP"
                else:
                    clean_img = img.convert("RGB")
                    save_format = "JPEG" if image_format == "JPEG" else image_format

                out_buf = io.BytesIO()
                clean_img.save(out_buf, format=save_format, quality=90)
                clean_bytes = out_buf.getvalue()

                clean_ext = "jpg" if save_format == "JPEG" else save_format.lower()
                return clean_bytes, clean_ext, width, height

        except HTTPException:
            raise
        except Exception as e:
            logger.warning("Corrupt or invalid image uploaded: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Corrupt or invalid image file: {str(e)}",
            )

    async def upload(
        self,
        file: Optional[UploadFile] = None,
        user_id: Optional[str] = None,
        subfolder: str = "wardrobe",
        pre_sanitized: Optional[Tuple[bytes, str, int, int]] = None,
    ) -> ImageMetadata:
        """
        Uploads image using authenticated user ID.
        If Cloudinary is configured and STORAGE_BACKEND is 'cloudinary', stores asset as type='authenticated'.
        Otherwise falls back cleanly to local disk storage.
        """
        if pre_sanitized:
            clean_bytes, ext, width, height = pre_sanitized
        elif file:
            raw_bytes = await file.read()
            clean_bytes, ext, width, height = self.validate_and_sanitize_image(file, raw_bytes)
        else:
            raise ValueError("Either file or pre_sanitized must be provided to upload")

        effective_user = user_id or "legacy"
        safe_subfolder = re.sub(r"[^a-zA-Z0-9_\-]", "", subfolder)

        if settings.is_cloudinary_configured and settings.STORAGE_BACKEND == "cloudinary":
            self._configure_cloudinary()
            import cloudinary.uploader

            folder_path = f"wardrobelens/users/{effective_user}/{safe_subfolder}"
            asset_uuid = uuid.uuid4().hex
            public_id = f"{folder_path}/{asset_uuid}"

            try:
                upload_res = cloudinary.uploader.upload(
                    clean_bytes,
                    public_id=public_id,
                    type="authenticated",
                    resource_type="image",
                    overwrite=False,
                )
                logger.info(
                    "Uploaded authenticated Cloudinary asset: public_id=%s, bytes=%d",
                    public_id,
                    len(clean_bytes),
                )
                return ImageMetadata(
                    public_id=upload_res.get("public_id", public_id),
                    storage_provider="cloudinary",
                    format=upload_res.get("format", ext),
                    version=str(upload_res.get("version", "")),
                    width=upload_res.get("width", width),
                    height=upload_res.get("height", height),
                    bytes_size=upload_res.get("bytes", len(clean_bytes)),
                )
            except Exception as e:
                logger.error("Cloudinary upload failed: %s", str(e), exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Image upload service unavailable: {str(e)}",
                )

        # Local storage fallback
        filename = f"{uuid.uuid4().hex}.{ext}"
        target_dir = self.base_dir / safe_subfolder
        target_dir.mkdir(parents=True, exist_ok=True)
        target_path = target_dir / filename

        with open(target_path, "wb") as f:
            f.write(clean_bytes)

        rel_path = f"{safe_subfolder}/{filename}"
        logger.info("Saved local image: path=%s, bytes=%d", rel_path, len(clean_bytes))
        return ImageMetadata(
            public_id=rel_path,
            storage_provider="local",
            format=ext,
            version=None,
            width=width,
            height=height,
            bytes_size=len(clean_bytes),
        )

    def generate_delivery_url(
        self,
        public_id: str,
        storage_provider: str = "cloudinary",
        ttl_seconds: Optional[int] = None,
        transformation: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """
        Generates a delivery URL.
        For Cloudinary: generates a signed URL with type='authenticated' and HMAC signature/expiry.
        For local: returns the local storage relative path (/storage/...).
        """
        if storage_provider == "cloudinary":
            self._configure_cloudinary()
            import cloudinary.utils

            effective_ttl = ttl_seconds or settings.IMAGE_DELIVERY_TTL_SECONDS
            url_options: Dict[str, Any] = {
                "type": "authenticated",
                "sign_url": True,
                "secure": settings.CLOUDINARY_SECURE_DELIVERY,
            }

            if transformation:
                url_options["transformation"] = transformation
            else:
                url_options["transformation"] = [
                    {"quality": "auto", "fetch_format": "auto"}
                ]

            if settings.CLOUDINARY_AUTH_TOKEN_KEY:
                url_options["auth_token"] = {
                    "key": settings.CLOUDINARY_AUTH_TOKEN_KEY,
                    "duration": effective_ttl,
                }
            else:
                logger.debug(
                    "CLOUDINARY_AUTH_TOKEN_KEY not set: generating tamper-proof HMAC-signed URL for '%s'. Note: 30-minute time-expiry requires Token-Based Authentication key.",
                    public_id,
                )

            signed_url, _ = cloudinary.utils.cloudinary_url(public_id, **url_options)
            return signed_url

        # Local storage
        clean_path = public_id.lstrip("/")
        return f"/storage/{clean_path}"

    def delete(self, public_id: str, storage_provider: str = "cloudinary") -> bool:
        """
        Deletes asset from Cloudinary or local disk.
        """
        if storage_provider == "cloudinary":
            if not settings.is_cloudinary_configured:
                logger.warning("Cloudinary not configured; cannot delete public_id=%s", public_id)
                return False
            self._configure_cloudinary()
            import cloudinary.uploader

            try:
                res = cloudinary.uploader.destroy(
                    public_id,
                    type="authenticated",
                    invalidate=True,
                )
                logger.info("Cloudinary delete result for %s: %s", public_id, res.get("result"))
                return res.get("result") in ["ok", "not found"]
            except Exception as e:
                logger.error("Failed to delete Cloudinary asset %s: %s", public_id, str(e))
                return False

        # Local disk deletion
        try:
            abs_path = self.get_absolute_path(public_id)
            if abs_path.is_file():
                abs_path.unlink()
                logger.info("Deleted local file: %s", abs_path)
                return True
        except Exception as e:
            logger.warning("Failed to delete local file %s: %s", public_id, str(e))
        return False

    def get_absolute_path(self, relative_path: str) -> Path:
        """Resolves relative path securely to prevent directory traversal."""
        clean_rel = os.path.normpath(relative_path).lstrip("\\/")
        abs_path = (self.base_dir / clean_rel).resolve()
        if not str(abs_path).startswith(str(self.base_dir.resolve())):
            raise HTTPException(status_code=403, detail="Access denied: invalid path.")
        return abs_path

    # Backwards compatibility helper for existing code during transition
    async def save_image(self, file: UploadFile, subfolder: str = "wardrobe") -> Tuple[str, Path]:
        raw_bytes = await file.read()
        clean_bytes, ext, _, _ = self.validate_and_sanitize_image(file, raw_bytes)
        filename = f"{uuid.uuid4().hex}.{ext}"
        target_dir = self.base_dir / subfolder
        target_dir.mkdir(parents=True, exist_ok=True)
        target_path = target_dir / filename
        with open(target_path, "wb") as f:
            f.write(clean_bytes)
        return f"{subfolder}/{filename}", target_path

    def delete_file(self, relative_path: str) -> bool:
        return self.delete(relative_path, storage_provider="local")


image_storage_service = ImageStorageService()
