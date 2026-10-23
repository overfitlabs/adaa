# adaa Mobile & Web Application 👗✨
*your style, smarter*

The `adaa` client is a cross-platform Flutter application targeting **Android** and **Web**, designed with an editorial, fashion-forward aesthetic (warm ivory, deep forest, and champagne gold).

---

## Features

- **Personal Digital Wardrobe**: Catalog, tag, and organize garments with AI-detected attributes, category chips, and 4/5 aspect ratio cards.
- **AI Stylist & Outfit Generation**: Weather-calibrated lookbook curations with occasion filters and piece matching scores.
- **Virtual Try-On**: Realistic silhouette lookbook previews powered by YouCam AI Clothes API.
- **Campus Shared Closets**: Browse, list, and request to borrow garments within verified student and creator communities.
- **Responsive Desktop Web Presentation**: On wide desktop screens, visitors experience an editorial two-panel shell with an auto-advancing feature carousel, one-click demo login, and a centered realistic smartphone frame hosting the real, interactive Flutter app.
- **Native Android Launch Experience**: Configured native launch drawables (`launch_background.xml`), adaptive launcher icons, and Flutter launch splash screen.

---

## Getting Started

### Prerequisites

- Flutter SDK 3.27+ (`flutter doctor` should report no issues)
- Android SDK 34+ (for Android builds)
- Google Chrome (for Web development)

### Install Dependencies

```powershell
flutter pub get
```

### Run Locally

**On Chrome (Web):**
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

**On Android:**
```powershell
flutter run -d android --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

---

## Production Builds

### 1. Android Release APK

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

- **Output APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Installation**:
  ```powershell
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```

### 2. Flutter Web Release (Vercel)

```powershell
flutter build web --release \
  --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com \
  --dart-define=DEMO_EMAIL=YOUR_DEMO_EMAIL \
  --dart-define=DEMO_PASSWORD=YOUR_DEMO_PASSWORD
```

- **Output Directory**: `build/web/`

> **Security Warning**: Values injected via `--dart-define` into Flutter Web builds are compiled into the client-side JavaScript artifact and are publicly inspectable. Ensure `DEMO_EMAIL` and `DEMO_PASSWORD` belong to a dedicated public demo account containing showcase data only. Never inject administrative credentials or personal account secrets.

---

## Vercel Deployment

The web build is served on Vercel using `mobile/vercel.json`:

```json
{
  "outputDirectory": "build/web",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

### Deployment Commands

**Preview Deployment:**
```powershell
vercel deploy
```

**Production Deployment:**
```powershell
vercel deploy --prod
```
