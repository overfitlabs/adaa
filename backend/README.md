# adaa Backend API 👗⚡

FastAPI backend service powering the `adaa` wardrobe intelligence, AI styling, and campus fashion sharing platform.

---

## Capabilities

- **AI Fashion Analysis**: Integrates Google Gemini 2.5 Flash for multimodal garment recognition, category classification, color palette detection, and fabric tagging.
- **YouCam Virtual Try-On**: Asynchronous job submission and polling against Perfect Corp's YouCam S2S API for realistic digital clothing visualization.
- **Garment Matching Engine**: Attribute similarity matrix matching inspiration outfit pieces against personal closet items.
- **Campus Shared Closets**: Community creation, member approval/rejection lifecycle, shared listings, and borrow requests with status tracking.
- **Privacy & Security**: Supabase JWT authentication verifier, strict session isolation, and field-level public profile filtering.

---

## Local Setup

### 1. Virtual Environment

From the `backend/` directory:

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
pip install -r requirements.txt
```

### 3. Environment Configuration

Create a `.env` file in `backend/` based on `.env.example`:

```ini
# Application
ENVIRONMENT=development
PORT=8000

# Database
DATABASE_URL=sqlite:///./wardrobelens.db

# Storage
STORAGE_DIR=./storage
MAX_UPLOAD_SIZE_MB=10

# Supabase Auth
SUPABASE_URL=https://gehuuvotncxpkwpvvbbv.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key

# Multimodal AI Providers
GEMINI_API_KEY=your_gemini_api_key

# Virtual Try-On Providers
YOUCAM_API_KEY=your_youcam_api_key
```

### 4. Run Development Server

```powershell
uvicorn app.main:app --reload --port 8000
```

The interactive OpenAPI documentation will be available at:
`http://127.0.0.1:8000/docs`

---

## Automated Tests

Run the test suite using pytest:

```powershell
.\.venv\Scripts\pytest.exe
```

All 105 tests cover community management, borrowing requests, image storage validation, JWT authentication, and privacy filters.

---

## Deployment

The backend service is continuously deployed to Render at:
`https://adaa-umsc.onrender.com`
