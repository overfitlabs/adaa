# adaa 👗✨
*your style, smarter*

adaa is an AI-powered personal wardrobe studio and fashion-sharing platform. It catalogs garment photos with automatic attribute recognition, decodes outfit inspirations, curates personalized daily lookbooks, provides photorealistic virtual try-on, and empowers campus communities to share and borrow curated pieces safely.

---

## Architecture Overview

adaa is structured as a unified repository:

- **Mobile & Web Client (`/mobile`)**: Flutter application targeting **Android** and **Web** (with desktop responsive presentation shell), built with clean separation between UI components, state management (ChangeNotifier providers), and networking clients.
- **Backend Service (`/backend`)**: High-performance Python FastAPI service with SQLAlchemy ORM (SQLite / PostgreSQL), Gemini 2.5 Flash multimodal vision analysis, YouCam AI clothing virtual try-on integration, and Starlette/Pydantic v2 schemas.
- **Authentication & Database (`/supabase`)**: Supabase Auth (JWT with PKCE) and PostgreSQL database migrations for robust session isolation and field-level privacy controls.

```
app/
├── backend/
│   ├── app/
│   │   ├── api/                    # RESTful endpoints (analysis, wardrobe, matching, outfits, tryon, communities, users)
│   │   ├── models.py               # SQLAlchemy ORM database models
│   │   ├── schemas.py              # Pydantic v2 validation models
│   │   ├── config.py               # Application settings & environment configuration
│   │   ├── database.py             # Database session and engine lifecycle
│   │   └── services/               # Gemini Vision, YouCam try-on, matching engine, storage
│   ├── tests/                      # Automated pytest suite
│   ├── requirements.txt            # Python dependencies
│   └── .env.example                # Template of backend environment variables
├── mobile/
│   ├── assets/
│   │   └── branding/               # Approved adaa wordmarks, icons, and logos
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/             # Supabase & Demo configuration
│   │   │   ├── theme/              # High-fashion editorial theme (Warm Ivory, Forest, Gold)
│   │   │   ├── network/            # HTTP ApiClient with session lifecycle handling
│   │   │   ├── widgets/            # Wordmark, responsive desktop shell, image loaders
│   │   │   └── models/             # Dart data models
│   │   ├── features/
│   │   │   ├── splash/             # Native & Flutter launch splash
│   │   │   ├── auth/               # Strict Supabase authentication & session isolation
│   │   │   ├── home/               # Editorial greeting, wardrobe capsule, studio quick tiles
│   │   │   ├── wardrobe/           # Digital closet, category chips, 4/5 garment cards
│   │   │   ├── styling/            # AI Stylist, occasion lookbooks, recommendation engine
│   │   │   ├── outfits/            # Saved looks gallery, curations & try-on links
│   │   │   ├── tryon/              # Virtual try-on workflow & asynchronous polling
│   │   │   ├── communities/        # Campus fashion circles & shared closets
│   │   │   ├── requests/           # Garment borrow request lifecycle & decision tracking
│   │   │   └── profile/            # User profile, sizing preferences & privacy controls
│   │   ├── state/                  # Providers (Auth, Wardrobe, Stylist, Outfits, Communities)
│   │   └── main.dart
│   ├── test/                       # Flutter unit and widget test suites
│   ├── web/                        # Web manifest, favicon, and HTML entry point
│   └── vercel.json                 # Vercel web deployment configuration
├── vercel.json                     # Root Vercel monorepo deployment configuration
├── render.yaml                     # Render cloud service deployment specification
└── README.md
```

---

## Live Deployments & APIs

- **Backend API**: `https://adaa-umsc.onrender.com`
- **Web App (Vercel)**: Deployed via Vercel with output directory `mobile/build/web/`
- **Interactive Web Experience**: On desktop browsers, visitors experience a two-panel editorial shell with an interactive smartphone frame running the live Flutter app, plus instant one-click demo login.

---

## Quick Start & Local Setup

### 1. Prerequisites

- **Python 3.12+**
- **Flutter SDK 3.27+** (`flutter doctor` should verify Chrome and Android toolchains)
- **Git**
- **Android Studio / Command Line Tools** (for Android APK builds)

---

### 2. Backend Service Setup

```powershell
# Navigate to backend
cd backend

# Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1   # Windows PowerShell
# source .venv/bin/activate    # macOS / Linux

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Run locally
uvicorn app.main:app --reload --port 8000
```

---

### 3. Flutter Mobile & Web Setup

```powershell
# Navigate to mobile
cd mobile

# Resolve dependencies
flutter pub get

# Run on Chrome (Web) against production API
flutter run -d chrome --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com

# Run on connected Android device / emulator
flutter run -d android --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

---

## Production Builds

### Android Release APK

```powershell
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

### Flutter Web Release (Vercel)

```powershell
cd mobile
flutter build web --release \
  --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com \
  --dart-define=DEMO_EMAIL=YOUR_DEMO_EMAIL \
  --dart-define=DEMO_PASSWORD=YOUR_DEMO_PASSWORD
```

Output: `mobile/build/web/`

> **Security Note**: Build-time variables injected via `--dart-define` into Flutter Web become inspectable in client-side JavaScript bundles. The demo account must only contain curated, non-sensitive showcase data. Never supply personal or administrative credentials.

---

## Vercel Web Deployment

When deploying via the Vercel CLI or Git integration:

```powershell
# From mobile/ directory:
cd mobile
vercel deploy              # Preview deployment
vercel deploy --prod       # Production deployment
```

Vercel is pre-configured with `mobile/vercel.json` (and root `vercel.json`) pointing to `build/web` with SPA rewrite rules.
