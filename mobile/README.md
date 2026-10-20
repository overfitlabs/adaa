# adaa

Modern Indian fashion sensibility with refined editorial styling. Warm, tactile, confident, understated, and fashion-first personal wardrobe and style intelligence.

## Features

- **Personal Digital Wardrobe**: Catalog, tag, and organize your clothing collection with AI-powered garment attribute detection.
- **AI Outfit Intelligence**: Deconstruct inspiration photos from street style, moodboards, or flat-lays to identify every garment piece and match against your personal closet.
- **Style Circles & Shared Closets**: Create and join private student or designer communities to browse, share, and borrow curated clothing pieces.
- **YouCam Virtual Try-On**: Preview outfit inspirations rendered on user photos with realistic clothing transfer.
- **Capsule & Style Recommendations**: Receive high-low mix suggestions and personalized wardrobe insights.

## Design Identity

- **Brand**: `adaa` (always lowercase)
- **Palette**:
  - Terracotta (`#A05B49`)
  - Espresso (`#342820`)
  - Warm Ivory (`#F5F0E8`)
  - Handloom Sand (`#D6C4A8`)
  - Linen White (`#FFFFFF`)

## Running Locally

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

To run against the production Render API:

```bash
flutter run --dart-define=API_BASE_URL=https://wardrobelens.onrender.com
```
