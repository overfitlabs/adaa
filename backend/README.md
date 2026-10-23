<p align="center">
  <img src="../mobile/assets/branding/brand_name_tagline_logo_web.png" alt="adaa - your style, smarter" width="280" />
</p>

<p align="center">
  <strong>FastAPI Fashion Intelligence Microservice</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/FastAPI-0.115%2B-009688?style=flat-square&logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/Python-3.12%2B-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/SQLAlchemy-2.0-red?style=flat-square" alt="SQLAlchemy" />
  <img src="https://img.shields.io/badge/PostgreSQL-Supabase-3ECF8E?style=flat-square&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Vision%20AI-Gemini%202.5%20Flash-4285F4?style=flat-square&logo=google&logoColor=white" alt="Gemini" />
</p>

---

## Overview

The `adaa` backend is a high-performance Python microservice powered by **FastAPI**, **Pydantic v2**, and **SQLAlchemy 2.0**. It exposes RESTful APIs for multimodal garment attribute extraction, algorithmic outfit curation, virtual try-on job coordination, campus fashion communities, and zero-trust media delivery.

---

## Capabilities

- **Multimodal Fashion Vision**: Deconstructs garment photos using Google Gemini 2.5 Flash into standardized categories, materials, colors, fits, and patterns.
- **Garment Matching Engine**: Evaluates wardrobe compatibility against inspiration pieces using a multi-attribute weighted scoring algorithm.
- **AI Stylist & Lookbook Generation**: Curates occasion-tailored and weather-informed ensembles using closet inventory.
- **Virtual Try-On Pipeline**: Coordinates asynchronous try-on simulation jobs against Perfect Corp's YouCam S2S API v2.0 with automatic retention expiry.
- **Campus Style Circles**: Manages community membership approvals, shared closet listings, and borrowing request state machines.
- **Zero-Trust Media Access**: Delivers user images via Cloudinary authenticated signed URLs (`TTL=1800s`), eliminating unauthenticated public storage mounts.
- **Identity & Field-Level Privacy**: Validates Supabase JWT access tokens using asymmetric JWKS or legacy HS256, enforcing granular user privacy visibility filters.

---

## Local Setup

### 1. Virtual Environment Setup

**Windows (PowerShell):**
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

**macOS / Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Environment Configuration

Create a local `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

The default values support local offline execution using SQLite (`wardrobelens.db`) and realistic mock AI providers without requiring API keys.

### 4. Run Development Server

```powershell
uvicorn app.main:app --reload --port 8000
```

- **OpenAPI / Swagger UI**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Health Check Probe**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

---

## Automated Tests

Run the complete pytest test suite:

```powershell
# Windows
.\.venv\Scripts\pytest.exe -v

# macOS / Linux
pytest -v
```

The test suite covers:
- JWT verification (JWKS asymmetric + HS256) and session isolation
- Multimodal garment extraction and schema validation
- Community creation, membership approvals, and shared closet listings
- Garment borrowing request transitions and duplicate prevention
- Sizing preferences and field-level privacy filters
- Protected storage route security and token delivery

---

## Deployment

The backend service is configured for continuous deployment to Render as a Web Service:
- **Production Endpoint**: `https://adaa-umsc.onrender.com`
- **Health Probe**: `https://adaa-umsc.onrender.com/health`
- **Infrastructure Blueprint**: `render.yaml`

---

## Documentation

For full architectural designs, database schemas, and API contracts:
- [REST API Reference](../docs/api.md)
- [Database Architecture & Migrations](../docs/database.md)
- [System Architecture](../docs/architecture.md)
- [Deployment Guide](../docs/deployment.md)
