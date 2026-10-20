from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.config import settings
from app.database import get_db

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """
    Lightweight, secure health-check endpoint for Render and orchestrators.
    Performs a fast liveness ping against the active database.
    Does NOT leak connection strings, database credentials, or internal SQL errors.
    """
    db_ok = False
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    status_code = status.HTTP_200_OK if db_ok else status.HTTP_503_SERVICE_UNAVAILABLE
    content = {
        "status": "healthy" if db_ok else "unhealthy",
        "service": "WardrobeLens Backend",
        "database": "connected" if db_ok else "disconnected",
        "environment": settings.ENVIRONMENT,
        "vision_provider": settings.VISION_PROVIDER,
        "tryon_provider": settings.TRYON_PROVIDER,
        "storage_backend": settings.STORAGE_BACKEND,
    }
    return JSONResponse(status_code=status_code, content=content)
