import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import init_db
from app.api import (
    routes_health,
    routes_analysis,
    routes_wardrobe,
    routes_matching,
    routes_outfits,
    routes_tryon,
    routes_recommendations,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure DB tables and storage directories exist
    init_db()
    settings.storage_path.mkdir(parents=True, exist_ok=True)
    yield
    # Shutdown


app = FastAPI(
    title="WardrobeLens API",
    description="Intelligent fashion assistant backend for outfit analysis, wardrobe management, multi-attribute matching, and virtual try-on.",
    version="1.0.0",
    lifespan=lifespan,
)

# Enable CORS for Flutter mobile app (Android emulator 10.0.2.2, physical devices, Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount local storage for serving image files
app.mount(
    "/storage",
    StaticFiles(directory=str(settings.storage_path)),
    name="storage",
)

# Include API Routers
app.include_router(routes_health.router)
app.include_router(routes_analysis.router)
app.include_router(routes_wardrobe.router)
app.include_router(routes_matching.router)
app.include_router(routes_outfits.router)
app.include_router(routes_tryon.router)
app.include_router(routes_recommendations.router)


@app.get("/")
def root():
    return {
        "app": "WardrobeLens API",
        "version": "1.0.0",
        "docs_url": "/docs",
        "health_check": "/health",
    }
