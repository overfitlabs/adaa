import os
import uuid
from pathlib import Path
from typing import Tuple
from fastapi import HTTPException, UploadFile, status
from PIL import Image
from app.config import settings


class StorageService:
    def __init__(self, base_dir: Path = None):
        self.base_dir = base_dir or settings.storage_path
        self.base_dir.mkdir(parents=True, exist_ok=True)
        # Separate subdirectories for organization and privacy
        (self.base_dir / "wardrobe").mkdir(exist_ok=True)
        (self.base_dir / "inspirations").mkdir(exist_ok=True)
        (self.base_dir / "tryon").mkdir(exist_ok=True)

    def validate_file(self, file: UploadFile) -> str:
        """Validate file extension and content type."""
        if not file.filename:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file must have a filename.",
            )

        ext = file.filename.split(".")[-1].lower()
        if ext not in settings.allowed_extensions_list:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported file type .{ext}. Allowed: {settings.allowed_extensions_list}",
            )
        return ext

    async def save_image(self, file: UploadFile, subfolder: str = "wardrobe") -> Tuple[str, Path]:
        """Validates, checks image integrity with Pillow, saves to disk, and returns relative path and absolute Path."""
        ext = self.validate_file(file)

        # Read content and enforce size limits
        contents = await file.read()
        if len(contents) > settings.max_upload_size_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Image exceeds size limit of {settings.MAX_UPLOAD_SIZE_MB}MB.",
            )

        # Validate that the file is actually a readable image using Pillow
        from io import BytesIO

        try:
            with Image.open(BytesIO(contents)) as img:
                img.verify()
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Corrupt or invalid image file: {str(e)}",
            )

        filename = f"{uuid.uuid4().hex}.{ext}"
        target_dir = self.base_dir / subfolder
        target_dir.mkdir(parents=True, exist_ok=True)
        target_path = target_dir / filename

        with open(target_path, "wb") as f:
            f.write(contents)

        relative_path = f"{subfolder}/{filename}"
        return relative_path, target_path

    def get_absolute_path(self, relative_path: str) -> Path:
        """Resolves relative path securely to prevent directory traversal."""
        clean_rel = os.path.normpath(relative_path).lstrip("\\/")
        abs_path = (self.base_dir / clean_rel).resolve()
        if not str(abs_path).startswith(str(self.base_dir.resolve())):
            raise HTTPException(status_code=403, detail="Access denied: invalid path.")
        return abs_path

    def delete_file(self, relative_path: str) -> bool:
        try:
            abs_path = self.get_absolute_path(relative_path)
            if abs_path.is_file():
                abs_path.unlink()
                return True
        except Exception:
            pass
        return False


storage_service = StorageService()
