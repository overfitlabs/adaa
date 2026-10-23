<p align="center">
  <img src="assets/branding/brand_name_tagline_logo_web.png" alt="adaa - your style, smarter" width="280" />
</p>

<p align="center">
  <strong>Cross-Platform Mobile & Web Client</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27%2B-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.6%2B-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Targets-Android%20%7C%20Web-1E382B?style=flat-square" alt="Targets" />
  <img src="https://img.shields.io/badge/Design-Editorial%20Warm%20Ivory-D49B4B?style=flat-square" alt="Design" />
</p>

---

## Overview

The `adaa` client is a cross-platform application built with **Flutter 3.27+** and **Dart 3.6+**, engineered for Android and modern web browsers. It embodies an editorial high-fashion aesthetic pairing warm ivory, deep forest green, and champagne gold accents.

---

## Core Features

- **Smart Digital Closet**: 4/5 aspect ratio cards with garment category chips, detailed attribute views, and custom tags.
- **Garment Digitization**: In-app camera and gallery capture, coupled with the review screen (`ItemReviewScreen`) for verifying AI-extracted fashion attributes.
- **AI Stylist & Lookbooks**: Occasion lookbook generation, weather-calibrated styling advice, and piece matching scores.
- **Inspiration Matching**: Match street style or mood-board images against owned wardrobe inventory.
- **Virtual Try-On Simulation**: Realistic silhouette preview workflow powered by the YouCam AI Clothes pipeline with asynchronous status polling.
- **Campus Style Circles**: Shared closets, community member verification, and structured garment borrow requests.
- **User Sizing & Privacy**: Sizing preferences across tops, bottoms, and footwear with field-level visibility controls.
- **Desktop Responsive Presentation Shell**: Luxury dual-panel web shell hosting an interactive smartphone frame with an auto-advancing feature carousel and instant demo access.

---

## Getting Started

### Prerequisites

- **Flutter SDK 3.27+** (`flutter doctor` should report no issues)
- **Android SDK 34+** (for Android APK builds)
- **Google Chrome** (for Web development)

### Install Dependencies

```powershell
flutter pub get
```

### Run Locally

**On Chrome (Web):**
```powershell
# Connect to local backend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Connect to production backend
flutter run -d chrome --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

**On Android Device / Emulator:**
```powershell
# Standard Android emulator
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical device via USB (with reverse TCP bridge)
adb reverse tcp:8000 tcp:8000
flutter run -d android --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

---

## Production Builds

### 1. Android Release APK

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com
```

- **Output APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Installation via ADB**:
  ```powershell
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```

### 2. Flutter Web Release (Vercel)

```powershell
flutter build web --release \
  --dart-define=API_BASE_URL=https://adaa-umsc.onrender.com \
  --dart-define=DEMO_EMAIL=demo@adaa.style \
  --dart-define=DEMO_PASSWORD=your_demo_password
```

- **Output Directory**: `build/web/`

> [!WARNING]
> Build-time variables injected via `--dart-define` into Flutter Web builds become inspectable in client-side JavaScript bundles. The demo account must only contain curated, non-sensitive showcase data. Never supply personal or administrative credentials.

---

## Automated Tests

Run the Flutter unit and widget test suite:

```powershell
flutter test
```

---

## Architecture & Documentation

For in-depth documentation on state management, routing, and network protocol handling:
- [System Architecture](../docs/architecture.md)
- [Developer Guide & Local Setup](../docs/development.md)
- [REST API Reference](../docs/api.md)
- [Deployment & Operations](../docs/deployment.md)
