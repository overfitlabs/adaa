# adaa | Developer Guide & Local Setup

This guide provides instructions for configuring, developing, and testing the **adaa** platform locally across the FastAPI backend, Flutter mobile client, and Flutter web application.

---

## 1. Prerequisites

Before setting up the repository, verify that your development environment satisfies these requirements:

| Tool | Recommended Version | Verification Command | Notes |
| :--- | :--- | :--- | :--- |
| **Python** | 3.12+ | `python --version` | Virtual environment creation (`venv`) required |
| **Flutter SDK** | 3.27+ | `flutter --version` | Must include Web and Android toolchains |
| **Dart SDK** | 3.6+ | `dart --version` | Bundled with Flutter SDK |
| **Git** | 2.40+ | `git --version` | Core version control |
| **Android SDK** | API 34+ | `flutter doctor` | Required for building the Android APK |
| **Google Chrome** | Latest Stable | `google-chrome --version` | Required for local web debugging |

Run `flutter doctor` to ensure Android licenses and build tools are properly configured:
```bash
flutter doctor -v
```

---

## 2. Repository Layout

```
app/
├── backend/                  # FastAPI service (Python 3.12+)
│   ├── app/
│   │   ├── api/              # RESTful API route controllers
│   │   ├── auth/             # Supabase JWT asymmetric JWKS & HS256 verifier
│   │   ├── config.py         # Pydantic v2 application settings
│   │   ├── database.py       # SQLAlchemy engine & dynamic migrations
│   │   ├── models.py         # SQLAlchemy ORM entity models
│   │   ├── schemas.py        # Pydantic request & response schemas
│   │   ├── scripts/          # Database replication & verification tools
│   │   └── services/         # Gemini Vision, YouCam try-on, storage, stylist
│   ├── tests/                # Pytest automated test suite (105 tests)
│   ├── requirements.txt      # Python runtime dependencies
│   └── .env.example          # Environment template for backend service
├── mobile/                   # Flutter cross-platform client (Android & Web)
│   ├── assets/
│   │   ├── branding/         # Approved logos, icons, and wordmarks
│   │   └── fonts/            # Playfair Display & Plus Jakarta Sans typefaces
│   ├── lib/
│   │   ├── core/             # Auth client, network client, theme, base widgets
│   │   ├── features/         # Screen implementations by domain module
│   │   ├── state/            # ChangeNotifier state management providers
│   │   └── main.dart         # Client application entry point
│   ├── test/                 # Flutter unit & widget test suites
│   ├── web/                  # Web manifest, icons, and HTML entry point
│   └── vercel.json           # Vercel deployment specification for mobile web
├── supabase/
│   └── migrations/           # PostgreSQL migration definitions (0001 to 0005)
├── docs/                     # Technical, architectural, and deployment documentation
├── render.yaml               # Render Cloud Application blueprint
├── vercel.json               # Root monorepo Vercel configuration
└── README.md                 # Project landing page and architectural summary
```

---

## 3. Backend Setup (FastAPI)

### Step 3.1: Virtual Environment Setup

Navigate to the `backend/` directory:

```bash
cd backend
```

Create and activate an isolated Python virtual environment:

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

### Step 3.2: Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 3.3: Environment Configuration

Create a local `.env` configuration file inside `backend/`:

```bash
cp .env.example .env
```

Review the configured values. By default, the application is pre-configured for zero-dependency local development using SQLite and mock AI providers:

```ini
# Application Mode
ENVIRONMENT=development
HOST=0.0.0.0
PORT=8000
DEBUG=true

# Database: SQLite local development database
DATABASE_URL=sqlite:///./wardrobelens.db

# Storage: Local disk storage for offline development
STORAGE_BACKEND=local
STORAGE_DIR=./storage
MAX_UPLOAD_SIZE_MB=15
ALLOWED_EXTENSIONS=jpg,jpeg,png,webp

# Authentication: Supabase Project Reference
SUPABASE_URL=https://gehuuvotncxpkwpvvbbv.supabase.co
SUPABASE_AUDIENCE=authenticated
SUPABASE_JWT_SECRET=

# AI Providers (Defaults to 'mock' for local dev without API credits)
VISION_PROVIDER=mock
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash

TRYON_PROVIDER=mock
YOUCAM_API_KEY=
YOUCAM_BASE_URL=https://yce-api-01.makeupar.com/s2s/v2.0
```

> [!NOTE]
> When `VISION_PROVIDER=mock` and `TRYON_PROVIDER=mock`, the backend generates realistic, high-fidelity responses without consuming Google Gemini or YouCam API quotas.

### Step 3.4: Launch Local Backend

```powershell
uvicorn app.main:app --reload --port 8000
```

Verify that the service is running:
- **Interactive OpenAPI Documentation**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Service Health Probe**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

### Step 3.5: Run Backend Automated Tests

Run the full pytest suite from `backend/`:

```powershell
# Windows
.\.venv\Scripts\pytest.exe -v

# macOS / Linux
pytest -v
```

---

## 4. Mobile & Web Setup (Flutter)

Navigate to the `mobile/` directory:

```bash
cd mobile
```

### Step 4.1: Install Dependencies

```bash
flutter pub get
```

### Step 4.2: Run on Web (Chrome)

Run the client in Chrome, connecting to your local backend:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

To run against the live production backend on Render:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

### Step 4.3: Run on Android (Emulator or Device)

#### Option A: Android Emulator
Standard Android emulators access the host machine via loopback alias `10.0.2.2`:

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

#### Option B: Physical Android Device via USB
When using a physical Android device connected via ADB, establish a reverse TCP tunnel so `127.0.0.1:8000` on the phone routes to your local machine:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d android --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### Step 4.4: Injecting Demo Access Credentials

The web responsive shell offers a one-click demo login option. To enable demo access during local development or staging builds, provide credentials via `--dart-define`:

```powershell
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEMO_EMAIL=demo@adaa.style \
  --dart-define=DEMO_PASSWORD=your_demo_password
```

> [!WARNING]
> Any flags supplied via `--dart-define` to Flutter Web builds become part of the compiled JavaScript bundle. Never supply personal accounts, administrative secrets, or service keys through `--dart-define`.

### Step 4.5: Run Flutter Tests

```powershell
flutter test
```

---

## 5. Environment Variables Reference

### Backend Service (`backend/.env`)

| Variable | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `ENVIRONMENT` | Yes | `development` | Environment tier (`development` or `production`) |
| `PORT` | No | `8000` | HTTP listening port |
| `DEBUG` | No | `true` | Enables detailed logging and stack traces |
| `DATABASE_URL` | Yes | `sqlite:///./wardrobelens.db` | SQLAlchemy connection URI (SQLite or PostgreSQL) |
| `STORAGE_BACKEND` | Yes | `local` | Media storage provider (`local` or `cloudinary`) |
| `STORAGE_DIR` | No | `./storage` | Filesystem path for local uploads |
| `MAX_UPLOAD_SIZE_MB` | No | `15` | Maximum allowed image payload size |
| `ALLOWED_EXTENSIONS` | No | `jpg,jpeg,png,webp` | Permitted upload image file extensions |
| `SUPABASE_URL` | Yes | Project URL | Supabase endpoint for auth validation and JWKS |
| `SUPABASE_AUDIENCE` | No | `authenticated` | Expected audience claim in client JWTs |
| `SUPABASE_JWT_SECRET` | No | `""` | Legacy symmetric secret; optional when JWKS is reachable |
| `VISION_PROVIDER` | Yes | `mock` | Multimodal provider (`gemini` or `mock`) |
| `GEMINI_API_KEY` | If Gemini | `""` | Google AI Studio Gemini API key |
| `GEMINI_MODEL` | No | `gemini-2.5-flash` | Gemini multimodal model name |
| `TRYON_PROVIDER` | Yes | `mock` | Virtual try-on provider (`youcam` or `mock`) |
| `YOUCAM_API_KEY` | If YouCam | `""` | Perfect Corp YouCam S2S API key |
| `YOUCAM_BASE_URL` | No | Perfect Corp URL | YouCam Clothes v2.0 endpoint |
| `CLOUDINARY_CLOUD_NAME`| If Cloudinary | `""` | Cloudinary account cloud identifier |
| `CLOUDINARY_API_KEY` | If Cloudinary | `""` | Cloudinary API access key |
| `CLOUDINARY_API_SECRET`| If Cloudinary | `""` | Cloudinary API access secret |
| `IMAGE_DELIVERY_TTL_SECONDS` | No | `1800` | Expiration lifetime for signed delivery URLs (30 min) |

---

## 6. Common Troubleshooting

### 1. `Connection refused` from Android Emulator
**Symptom**: Android app cannot communicate with `http://127.0.0.1:8000`.  
**Resolution**: The emulator runs inside a virtual network. Specify `--dart-define=API_BASE_URL=http://10.0.2.2:8000`, which the emulator translates to your host machine's loopback interface.

### 2. CORS Errors in Web Browser
**Symptom**: Console reports `Access-Control-Allow-Origin missing`.  
**Resolution**: Ensure `CORSMiddleware` is active in `backend/app/main.py`. If calling a custom backend URL, verify the port matches `8000`.

### 3. Asymmetric JWKS vs Symmetric Secret Validation
**Symptom**: Backend rejects tokens with `401 Unauthorized: Signature verification failed`.  
**Resolution**: Supabase modern projects sign JWTs with asymmetric keys (ES256/RS256). Verify `SUPABASE_URL` is set correctly in `backend/.env` so `PyJWKClient` can retrieve `/.well-known/jwks.json`. Symmetric `SUPABASE_JWT_SECRET` is only required for legacy projects.
