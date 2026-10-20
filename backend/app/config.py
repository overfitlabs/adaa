from pathlib import Path
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True

    # Vision AI Provider (gemini | mock)
    VISION_PROVIDER: str = "mock"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"
    VISION_TIMEOUT_SECONDS: int = 40

    # Virtual Try-On Provider (youcam | mock)
    TRYON_PROVIDER: str = "mock"
    YOUCAM_API_KEY: str = ""
    YOUCAM_BASE_URL: str = "https://yce-api-01.makeupar.com/s2s/v2.0"

    # Database & Storage
    DATABASE_URL: str = "sqlite:///./wardrobelens.db"
    STORAGE_DIR: str = "./storage"
    MAX_UPLOAD_SIZE_MB: int = 15
    ALLOWED_EXTENSIONS: str = "jpg,jpeg,png,webp"

    # Supabase Auth & JWT Configuration
    SUPABASE_URL: str = ""
    SUPABASE_JWT_SECRET: str = ""
    SUPABASE_AUDIENCE: str = "authenticated"

    # Cloudinary & Image Storage Configuration
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""
    CLOUDINARY_AUTH_TOKEN_KEY: str = ""
    CLOUDINARY_SECURE_DELIVERY: bool = True
    STORAGE_BACKEND: str = "cloudinary"  # "cloudinary" | "local"
    IMAGE_DELIVERY_TTL_SECONDS: int = 1800  # 30 minutes
    TRYON_RETENTION_DAYS: int = 7

    model_config = SettingsConfigDict(
        env_file=(
            str(Path(__file__).resolve().parent.parent / ".env")
            if (Path(__file__).resolve().parent.parent / ".env").exists()
            else ".env"
        ),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def allowed_extensions_list(self) -> List[str]:
        return [ext.strip().lower().lstrip(".") for ext in self.ALLOWED_EXTENSIONS.split(",")]

    @property
    def max_upload_size_bytes(self) -> int:
        return self.MAX_UPLOAD_SIZE_MB * 1024 * 1024

    @property
    def storage_path(self) -> Path:
        p = Path(self.STORAGE_DIR)
        p.mkdir(parents=True, exist_ok=True)
        return p

    @property
    def is_cloudinary_configured(self) -> bool:
        return bool(self.CLOUDINARY_CLOUD_NAME and self.CLOUDINARY_API_KEY and self.CLOUDINARY_API_SECRET)


settings = Settings()
