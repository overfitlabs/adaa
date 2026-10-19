from fastapi import APIRouter
from app.config import settings

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "WardrobeLens Backend",
        "environment": settings.ENVIRONMENT,
        "vision_provider": settings.VISION_PROVIDER,
        "has_gemini_key": bool(settings.GEMINI_API_KEY),
        "tryon_provider": settings.TRYON_PROVIDER,
        "has_youcam_key": bool(settings.YOUCAM_API_KEY),
    }
