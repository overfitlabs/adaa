# adaa | Architecture & System Design

This document details the software architecture, component relationships, data pipelines, and security mechanisms governing **adaa** across both client and server environments.

---

## 1. System Overview

adaa is designed as a modular, decoupled fashion intelligence platform. It pairs a cross-platform client with an asynchronous FastAPI microservice, backed by Supabase for identity and transactional persistence, Cloudinary for authenticated media delivery, and Google Gemini 2.5 Flash for multimodal vision comprehension.

```mermaid
graph TB
    subgraph ClientTier["Client Tier (Flutter 3.27+)"]
        MobileApp["Android Mobile App (Release APK)"]
        WebApp["Web Application (Single-Page App on Vercel)"]
        DesktopShell["Responsive Presentation Shell (Dual-Panel Desktop)"]
    end

    subgraph EdgeTier["Edge & Gateway Tier"]
        VercelCDN["Vercel Global Edge Network (SPA Rewrites)"]
        RenderService["Render Web Service (FastAPI / Uvicorn ASGI)"]
    end

    subgraph ServiceTier["Backend Application Services (Python 3.12+)"]
        Router["FastAPI Application Gateway & Router (app/api)"]
        AuthModule["Supabase JWT Verifier (JWKS / Asymmetric + HS256)"]
        
        subgraph CoreServices["Domain Services"]
            VisionSvc["Vision Provider (Gemini 2.5 Flash / Mock)"]
            StylistSvc["Stylist Engine (Occasion & Climate Curations)"]
            MatchingSvc["Matching Engine (Attribute Similarity Matrix)"]
            TryOnSvc["Virtual Try-On Provider (YouCam S2S / Mock)"]
            StorageSvc["Image Storage Service (Cloudinary / Local Protected)"]
            NotifySvc["Notification Service (Event Deduplication)"]
        end
    end

    subgraph IdentityTier["Identity & Persistence (Supabase / PostgreSQL)"]
        SupaAuth["Supabase Auth (PKCE / JWT / Email / OAuth)"]
        PostgresDB[("PostgreSQL Database (Supabase / AWS us-east-1)")]
        RLSPolicies["Row-Level Security & Anti-Escalation Triggers"]
    end

    subgraph StorageTier["Media Storage Tier"]
        CloudinaryCDN["Cloudinary Media Cloud (Authenticated Uploads & Signed URLs)"]
        LocalDisk[("Protected Local Disk Storage (/storage)")]
    end

    subgraph ExternalAITier["External AI & Fashion APIs"]
        GeminiAPI["Google Gemini 2.5 Flash Vision API"]
        YouCamAPI["Perfect Corp YouCam Clothes S2S API v2.0"]
    end

    %% Client Interactions
    WebApp --> VercelCDN
    DesktopShell --> WebApp
    MobileApp --> RenderService
    WebApp --> RenderService
    MobileApp --> SupaAuth
    WebApp --> SupaAuth

    %% Edge & Backend
    RenderService --> Router
    Router --> AuthModule
    AuthModule -.->|Token Validation| SupaAuth
    Router --> CoreServices

    %% Core Services to Providers
    VisionSvc --> GeminiAPI
    TryOnSvc --> YouCamAPI
    StorageSvc --> CloudinaryCDN
    StorageSvc --> LocalDisk
    
    %% Persistence
    CoreServices --> PostgresDB
    PostgresDB --- RLSPolicies
```

---

## 2. Frontend Architecture (Flutter)

The client application is built with **Flutter 3.27+** and **Dart 3.6+**. It uses a layered architecture separating visual presentation, reactive state management via `ChangeNotifier` providers, network protocol clients, and local session management.

### Component Structure

```mermaid
graph TD
    Entry["main.dart (Initialization & Global Providers)"] --> App["AdaaApp (Material 3 Theme Configuration)"]
    App --> Shell["WebResponsiveShell (Desktop Shell / Fullscreen Mobile)"]
    Shell --> Gate["AuthGate (Session Routing & State Recovery)"]

    Gate -->|Unauthenticated| AuthScreen["features/auth (Sign In / Register / Demo Access)"]
    Gate -->|Authenticated| HomeScreen["features/home (Studio Hub & Daily Capsule)"]

    subgraph Providers["State Management Layer (Provider / ChangeNotifier)"]
        AuthP["AuthProvider"]
        WardrobeP["WardrobeProvider"]
        StylistP["StylistProvider"]
        OutfitsP["OutfitsProvider"]
        TryOnP["TryOnProvider"]
        CommP["CommunityProvider"]
        ProfileP["ProfileProvider"]
        NotifyP["NotificationProvider"]
        AnalysisP["AnalysisProvider"]
    end

    subgraph FeatureModules["Feature Modules (lib/features)"]
        F_Wardrobe["wardrobe/ (Closet Grid, Detail, Add Garment)"]
        F_Analysis["analysis/ (Garment Review & Breakdown)"]
        F_Styling["styling/ (Occasion Lookbooks & Weather Edits)"]
        F_Matching["matching/ (Inspiration Piece Matrix)"]
        F_Outfits["outfits/ (Saved Ensembles & Creation Studio)"]
        F_TryOn["tryon/ (Virtual Try-On Simulation)"]
        F_Comm["communities/ (Style Circles & Shared Closets)"]
        F_Req["requests/ (Borrow Request Workflow)"]
        F_Profile["profile/ (Sizing Preferences & Privacy Controls)"]
        F_Notify["notifications/ (Activity Feed & Unread Badges)"]
    end

    subgraph CoreFoundation["Core Infrastructure (lib/core)"]
        NetClient["network/api_client.dart (HTTP Session & Error Resilience)"]
        NetEndpoints["network/api_endpoints.dart (Route Declarations & URL Resolution)"]
        AuthSvc["auth/supabase_auth_service.dart (Supabase Client Wrapper)"]
        SessionMgr["auth/session_manager.dart (Secure Token Lifecycle)"]
        ThemeTokens["theme/ (AppColors, AppTypography, AppTheme)"]
    end

    HomeScreen --> FeatureModules
    FeatureModules --> Providers
    Providers --> NetClient
    NetClient --> NetEndpoints
    AuthP --> AuthSvc
    AuthSvc --> SessionMgr
```

### State Management & Lifecycle

- **Session Isolation**: Each provider responds to authentication lifecycle events emitted by `AuthProvider`. When a user signs out, providers reset their in-memory models to eliminate state contamination across distinct accounts.
- **Network Resilience**: `ApiClient` automatically extracts the active Supabase JWT from `SessionManager` and attaches it as an `Authorization: Bearer <TOKEN>` header.
- **Dynamic Endpoint Probing**: In local environments, `ApiEndpoints` automatically resolves target backend addresses depending on whether the application runs on Web (`127.0.0.1:8000`), an Android Emulator (`10.0.2.2:8000`), or a physical mobile device with `adb reverse` bridge.

---

## 3. Backend Architecture (FastAPI)

The backend service is built with **FastAPI** and **Pydantic v2**, following a clean layered service pattern.

```mermaid
graph LR
    subgraph Ingress["Ingress Layer"]
        CORS["FastAPI CORSMiddleware"]
        StaticProt["Protected Storage Routes (/storage)"]
        HealthRoute["Health Probes (/health)"]
    end

    subgraph Routers["API Routers (app/api)"]
        R_Auth["routes_auth.py"]
        R_Wardrobe["routes_wardrobe.py"]
        R_Analysis["routes_analysis.py"]
        R_Matching["routes_matching.py"]
        R_Outfits["routes_outfits.py"]
        R_Stylist["routes_recommendations.py"]
        R_TryOn["routes_tryon.py"]
        R_Comm["routes_communities.py"]
        R_Requests["routes_requests.py"]
        R_Users["routes_users.py"]
        R_Notify["routes_notifications.py"]
    end

    subgraph Security["Security & Authentication"]
        JWKSDecoder["SupabaseJWTVerifier (JWKS Asymmetric / HS256)"]
        UserDep["get_current_user / get_optional_current_user"]
        PrivacyFilter["Field-Level Profile Privacy Sanitizer"]
    end

    subgraph DomainServices["Service Layer (app/services)"]
        VisionProv["VisionProvider (GeminiVisionProvider)"]
        StylistEngine["StylistService (Rule-Based & Generative)"]
        MatchEngine["MatchingEngine (Jaccard / Color Proximity)"]
        TryOnProv["TryOnProvider (YouCam S2S / Mock)"]
        ImgStorage["ImageStorageService (Cloudinary Signed Delivery)"]
        NotifSvc["NotificationService (Event Deduplication)"]
    end

    subgraph Persistence["Persistence Layer"]
        Engine["SQLAlchemy Engine (Connection Pooling & Pre-Ping)"]
        Models["SQLAlchemy Declarative Models (app/models.py)"]
        MigrationMgr["Database Migration Engine (init_db)"]
    end

    CORS --> Routers
    Routers --> Security
    Security --> DomainServices
    DomainServices --> Persistence
```

### Key Subsystems

1. **Dual Database Dialect Support**:
   - **PostgreSQL (Supabase)**: Configured for production deployment with connection pooling (`pool_size=10`, `max_overflow=15`), connection liveness testing (`pool_pre_ping=True`), and connection recycling (`pool_recycle=1800`) to avoid dropped sockets behind cloud NAT/firewalls.
   - **SQLite**: Seamlessly supported for zero-dependency local development and testing with thread safety flags (`check_same_thread=False`).
2. **Zero-Trust Media Access**:
   - User photos are **never** mounted via open static file servers.
   - Cloudinary assets are delivered through signed URLs with time-to-live restrictions (`IMAGE_DELIVERY_TTL_SECONDS=1800`).
   - Local storage fallbacks enforce ownership validation and path traversal checks within `routes_storage.py`.
3. **Graceful Provider Fallbacks**:
   - Multimodal vision defaults to Gemini 2.5 Flash when `GEMINI_API_KEY` is present, falling back to a structured mock provider if unconfigured.
   - Virtual Try-On invokes YouCam S2S when configured, or transparently falls back to an asynchronous simulation provider for offline development.

---

## 4. Key Request Flows

### A. Garment Digitization & Ingestion Flow

This sequence demonstrates how a physical garment photo is captured, processed by Gemini 2.5 Flash, reviewed by the user, and committed to the digital closet.

```mermaid
sequenceDiagram
    autonumber
    actor User as User / Stylist
    participant Client as Flutter Client (mobile)
    participant API as FastAPI Backend (Render)
    participant Storage as Cloudinary / Local Storage
    participant Gemini as Google Gemini 2.5 Flash
    participant DB as PostgreSQL Database

    User->>Client: Selects or captures garment photo
    Client->>API: POST /api/wardrobe/detect-item (Multipart Form)
    Note over Client,API: Authorization: Bearer <Supabase JWT>
    
    API->>API: Verify JWT signature & extract user UUID
    API->>Storage: Upload raw photo & compute public identifier
    Storage-->>API: Return media reference (path / public_id)
    
    API->>Gemini: analyze_single_garment(image_bytes)
    Note over API,Gemini: Extract category, subcategory, colors, fabric, pattern, fit
    Gemini-->>API: Structured JSON attribute payload
    
    API-->>Client: HTTP 200: DetectedFashionItem schema
    Client->>User: Displays ItemReviewScreen (User can edit attributes)
    
    User->>Client: Confirms attributes & assigns name/brand
    Client->>API: POST /api/wardrobe/items (JSON payload)
    API->>DB: INSERT INTO wardrobe_items
    DB-->>API: Record committed
    API-->>Client: HTTP 201: WardrobeItemResponse
    Client->>User: Garment appears in 4/5 Aspect Ratio Closet Grid
```

---

### B. Campus Style Circle & Garment Borrowing Flow

This sequence traces the lifecycle of sharing a wardrobe piece within a trusted style circle and requesting to borrow it.

```mermaid
sequenceDiagram
    autonumber
    actor Owner as Garment Owner
    actor Borrower as Borrower
    participant Client as Flutter Client
    participant API as FastAPI Backend
    participant DB as PostgreSQL Database
    participant Notif as Notification Engine

    Owner->>Client: Selects wardrobe item -> "Share to Community"
    Client->>API: POST /api/communities/{id}/listings
    API->>DB: INSERT INTO community_listings (status='active')
    DB-->>API: Listing created
    API-->>Client: Listing active
    
    Borrower->>Client: Browses Community Shared Closet
    Client->>API: GET /api/communities/shared-closet
    API->>DB: Query active listings for joined communities
    DB-->>API: Return available garments
    API-->>Client: Render shared pieces
    
    Borrower->>Client: Submits Borrow Request (Dates + Message)
    Client->>API: POST /api/communities/{id}/listings/{lid}/requests
    API->>DB: Verify no duplicate pending request (Unique Constraint)
    API->>DB: INSERT INTO item_requests (status='pending')
    API->>Notif: Trigger in-app notification for Owner
    DB-->>API: Request created
    API-->>Client: Request confirmed
    
    Owner->>Client: Opens Notifications or Incoming Requests
    Client->>API: PATCH /api/requests/{req_id}/status (status='accepted')
    API->>DB: UPDATE item_requests SET status='accepted'
    API->>Notif: Trigger notification for Borrower
    DB-->>API: Status updated
    API-->>Client: Request accepted
```

---

### C. Authentication & Session Recovery Flow

This sequence illustrates how user sessions are established, restored across application restarts, and securely validated against the backend.

```mermaid
sequenceDiagram
    autonumber
    actor User as User
    participant App as Flutter App Launch
    participant Session as SessionManager
    participant SupaSDK as Supabase Auth SDK
    participant API as FastAPI Backend
    participant JWKS as Supabase JWKS Endpoint

    App->>Session: init() -> Retrieve persisted tokens from secure storage
    alt Valid cached session exists
        Session->>SupaSDK: Validate session freshness
        SupaSDK-->>Session: Session active (JWT access token)
        Session-->>App: Emit AuthState.authenticated
    else No session or token expired
        App->>User: Present AuthScreen / AuthDialog
        User->>SupaSDK: Sign In (Email/Password or Demo Mode)
        SupaSDK-->>Session: Return fresh SupabaseSession (Access Token + Refresh Token)
        Session-->>App: Emit AuthState.authenticated
    end

    App->>API: Authenticated API Request (Header: Bearer <JWT>)
    API->>API: Check token header & extract key ID (kid)
    alt Asymmetric Verification (RS256/ES256)
        API->>JWKS: Fetch / verify public key from /.well-known/jwks.json (Cached)
        JWKS-->>API: Public Key
    else Symmetric Verification (HS256 Legacy)
        API->>API: Verify token with SUPABASE_JWT_SECRET
    end
    API->>API: Validate claims (aud='authenticated', exp, iss)
    API->>API: Inject AuthenticatedUser(id, email, role)
    API-->>App: HTTP 200: Protected Resource Response
```

---

## 5. Security & Privacy Model

| Defense Layer | Implementation Strategy |
| :--- | :--- |
| **Authentication** | Supabase Auth issuing cryptographic JWTs. Verified on backend via asymmetric JWKS or HS256 secret. |
| **Session Isolation** | Multi-account safety: in-memory state in Flutter is cleared on logout; backend database queries strictly partition records by `user_id = current_user.id`. |
| **Column Anti-Escalation** | PostgreSQL trigger `protect_profile_fields()` blocks client modifications to `id`, `email`, `created_at`, and `is_student_verified`. |
| **Field-Level Privacy** | User profile visibility controls (`show_email`, `show_phone`, `show_age`, `show_fit_preferences`) ensure unshared fields are stripped before transmitting public profiles. |
| **Zero Public Media Buckets** | Cloudinary media delivered with signed authentication tokens; local files guarded against directory traversal attacks (`Path.resolve()`). |
| **Deduplication Constraints** | Unique SQL partial indexes prevent duplicate pending borrow requests and idempotent notification delivery. |
