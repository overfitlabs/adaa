# WardrobeLens 👗🔍

WardrobeLens is an AI-powered personal fashion assistant that decodes outfit photos, matches garments against your personal digital wardrobe, detects missing pieces, suggests personalized styling combinations, and provides photorealistic virtual try-on powered by Perfect Corp's YouCam S2S API.

---

## Architecture Overview

WardrobeLens is built as a unified monorepo:

- **Mobile Application (`/mobile`)**: Flutter (targeting Android first, with iOS & Web support), structured by feature with clean boundaries between UI, business logic, networking, and state management.
- **Backend Service (`/backend`)**: Python with FastAPI, SQLAlchemy ORM (SQLite for local self-contained storage), Pillow image validation, Gemini 2.5 Flash for multimodal vision analysis, YouCam AI Clothes Virtual Try-On integration, and Pytest.

```
app/
├── backend/
│   ├── .venv/                      # Python virtual environment (gitignored)
│   ├── app/
│   │   ├── api/                    # RESTful endpoints (analysis, wardrobe, matching, outfits, tryon, recommendations)
│   │   ├── models.py               # SQLAlchemy ORM models (WardrobeItem, OutfitAnalysis, SavedOutfit, TryOnTask)
│   │   ├── schemas.py              # Pydantic v2 validation models
│   │   ├── config.py               # Environment configuration
│   │   ├── database.py             # SQLite database session and engine management
│   │   └── services/
│   │       ├── vision_provider.py  # Gemini 2.5 Flash + Mock vision providers
│   │       ├── matching_engine.py  # Multi-attribute garment matching engine
│   │       ├── tryon_provider.py   # Official YouCam Virtual Try-On + Mock providers
│   │       └── storage_service.py  # Local secure file storage and integrity verification
│   ├── tests/                      # Pytest automated test suite
│   ├── requirements.txt            # Manifest of Python dependencies
│   ├── .env.example                # Template of backend environment variables
│   └── pytest.ini
├── mobile/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── theme/              # High-fashion editorial theme and color system
│   │   │   ├── network/            # Http ApiClient with timeout and error extraction
│   │   │   └── models/             # Dart data models
│   │   ├── features/
│   │   │   ├── home/               # Outfit photo inspiration upload & quick actions
│   │   │   ├── analysis/           # Breakdown of detected garments with attribute editing
│   │   │   ├── wardrobe/           # Digital closet, category filtering, search, AI auto-detection
│   │   │   ├── matching/           # Completeness score, exact vs approx matches, missing pieces
│   │   │   ├── outfits/            # Curated looks gallery and outfit builder
│   │   │   ├── tryon/              # YouCam virtual try-on workflow & asynchronous polling
│   │   │   └── styling/            # Capsule recommendations & style guidance
│   │   ├── state/                  # ChangeNotifier providers (Wardrobe, Analysis, TryOn, Outfits)
│   │   └── main.dart
│   ├── test/                       # Flutter unit and widget tests
│   └── pubspec.yaml
├── .gitignore
└── README.md
```

---

## Prerequisites

Before starting, ensure the following developer tools are installed:

- **Python 3.12+**
- **Flutter SDK 3.27+** (`flutter doctor` should verify Android and Chrome toolchains)
- **Git**
- **Android Studio / Command Line Tools** (with Android SDK 34+ or physical device with USB debugging enabled)

---

## 1. Backend Setup

### A. Create and Activate Virtual Environment

From the project root:

**Windows (PowerShell):**
```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

**macOS / Linux:**
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
```

### B. Install Dependencies

```bash
pip install -r requirements.txt
```

### C. Configure Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` to supply credentials:

```ini
# Environment
ENVIRONMENT=development
HOST=0.0.0.0
PORT=8000
DEBUG=true

# Vision AI Provider (gemini | mock)
VISION_PROVIDER=gemini
GEMINI_API_KEY=your_google_gemini_api_key_here
GEMINI_MODEL=gemini-2.5-flash

# YouCam / Perfect Corp Virtual Try-On API (youcam | mock)
TRYON_PROVIDER=youcam
YOUCAM_API_KEY=your_youcam_api_key_here
YOUCAM_BASE_URL=https://yce-api-01.makeupar.com/s2s/v2.0

# Database & Local File Storage
DATABASE_URL=sqlite:///./wardrobelens.db
STORAGE_DIR=./storage
MAX_UPLOAD_SIZE_MB=15
ALLOWED_EXTENSIONS=jpg,jpeg,png,webp
```

> **Note on Mock Providers**: If you don't have a Gemini API key or YouCam API key yet, leave `VISION_PROVIDER=mock` and `TRYON_PROVIDER=mock`. High-fidelity mock services will run without requiring external keys or making paid calls.

### D. Run Backend Tests

```bash
pytest -v
```

### E. Start Backend Server

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API documentation will be available at:
- Swagger UI: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

---

## 2. Mobile App Setup (Flutter)

### A. Install Flutter Dependencies

From the project root:

```bash
cd mobile
flutter pub get
```

### B. Run Flutter Automated Tests & Analysis

```bash
flutter analyze
flutter test
```

### C. Run Mobile App

#### Running on Android Emulator / Physical Device:
```bash
flutter run
```
*Note: The app automatically detects the Android emulator environment and maps API requests to `http://10.0.2.2:8000`.*

#### Running on Web / Desktop for Development:
```bash
flutter run -d chrome
```

---

## Core Features & Workflow

1. **AI Outfit Breakdown**: Upload any outfit photo (influencer shot, street style, mannequin, or flat-lay on a bed). WardrobeLens uses Gemini 2.5 Flash to identify tops, bottoms, jackets, footwear, and accessories with detailed cuts, fabrics, colors, and formality tags.
2. **Interactive Item Cards**: Inspect and edit detected information, correct shades or silhouettes, and re-trigger matching.
3. **Digital Wardrobe**: Photograph your clothes. AI pre-fills garment attributes. Search by color, material, or category tag. Everything persists in local SQLite storage.
4. **Intelligent Closet Matching**: Compares inspiration pieces against your wardrobe using a weighted multi-factor scoring algorithm (category compatibility, color harmony, and style attributes).
   - **Exact Match** ($\ge 85\%$ score)
   - **Approximate Match** ($\ge 45\%$ score) with top alternatives
   - **Missing Pieces** clearly identified so you know what piece to shop or substitute
5. **Saved Outfits & Looks**: Group wardrobe pieces into saved looks for occasions (work, dinners, weekend leisure) and save inspiration replicas.
6. **YouCam Virtual Try-On**:
   - Integrates Perfect Corp's official YouCam S2S API (`/file`, `/task/clothes-vto`, and polling `/task/{task_id}`).
   - Upload your own portrait photo and preview any inspiration look or wardrobe piece realistically draped on your body.
7. **Styling & Capsule Recommendations**: Algorithmic suggestions for high-low mixes (outerwear + casual base), tonal/monochrome combinations, and capsule foundation planning.

---

## Privacy & Security

- **Local Storage First**: Photos are stored locally in `./storage` and served with path sanitization to prevent directory traversal.
- **Payload Verification**: All uploads are verified for image integrity using Pillow before processing.
- **Zero Credential Exposure**: API keys reside solely on the FastAPI backend in `.env` and are never embedded into mobile code.
