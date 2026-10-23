# adaa | REST API Reference

The **adaa** backend service exposes a high-performance RESTful API powering wardrobe digitizing, multimodal visual styling, virtual try-on, and campus community sharing.

- **Production API URL**: `https://adaa-umsc.onrender.com`
- **Local Development URL**: `http://127.0.0.1:8000`
- **Interactive OpenAPI Documentation**: `GET /docs` (Swagger UI)
- **Machine-Readable OpenAPI Specification**: `GET /openapi.json`

---

## 1. Authentication & Security

All private endpoints require a valid Supabase Auth JSON Web Token (JWT) transmitted via the standard HTTP `Authorization` header:

```http
Authorization: Bearer <SUPABASE_JWT_ACCESS_TOKEN>
```

### Authorization Error Codes

| Status Code | Description | Reason |
| :--- | :--- | :--- |
| `401 Unauthorized` | Missing or invalid bearer token | Token is missing, expired, or failed signature check |
| `403 Forbidden` | Insufficient permissions | Accessing another user's private garment or unapproved community |
| `404 Not Found` | Entity not found | Target item, request, or community does not exist |
| `422 Unprocessable` | Validation error | Pydantic v2 schema validation failure on request payload |

---

## 2. Health & Service Liveness

### `GET /health`
Liveness probe designed for orchestrators (e.g. Render, Kubernetes). Validates active database connectivity without exposing connection secrets.

**Response (`200 OK`):**
```json
{
  "status": "healthy",
  "service": "WardrobeLens Backend",
  "database": "connected",
  "environment": "production",
  "vision_provider": "gemini",
  "tryon_provider": "mock",
  "storage_backend": "cloudinary"
}
```

---

## 3. Digital Wardrobe (`/api/wardrobe`)

### `POST /api/wardrobe/detect-item`
Extracts fashion attributes from a raw garment photograph using multimodal AI (Google Gemini 2.5 Flash). Does not save to the database; returns structured metadata for user review.

- **Content-Type**: `multipart/form-data`
- **Parameters**: `file` (UploadFile, image/jpeg, image/png, image/webp)

**Response (`200 OK`):**
```json
{
  "category": "Tops",
  "sub_category": "Blouse",
  "primary_color": "Forest Green",
  "secondary_color": "Cream",
  "pattern": "Floral",
  "material": "Silk",
  "fit": "Relaxed",
  "season": "Spring/Summer",
  "formality": "Smart Casual",
  "confidence": 0.94,
  "temp_image_path": "storage/wardrobe/temp_uuid.jpg"
}
```

### `POST /api/wardrobe/items`
Commits a verified garment into the user's digital wardrobe.

- **Content-Type**: `application/json`
- **Request Body**:
```json
{
  "name": "Emerald Silk Blouse",
  "category": "Tops",
  "sub_category": "Blouse",
  "primary_color": "Forest Green",
  "secondary_color": "Cream",
  "pattern": "Floral",
  "material": "Silk",
  "fit": "Relaxed",
  "season": "Spring/Summer",
  "formality": "Smart Casual",
  "brand": "Sézane",
  "size": "M",
  "condition": "Excellent",
  "image_path": "storage/wardrobe/temp_uuid.jpg",
  "tags": ["silk", "vintage", "evening"]
}
```

**Response (`201 Created`):**
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "user_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "name": "Emerald Silk Blouse",
  "category": "Tops",
  "primary_color": "Forest Green",
  "image_url": "https://res.cloudinary.com/.../image.webp",
  "created_at": "2026-10-23T18:00:00Z"
}
```

### `GET /api/wardrobe/items`
Retrieves all garments owned by the authenticated user.

- **Query Parameters**:
  - `category` *(optional)*: Filter by category (e.g., `Tops`, `Bottoms`, `Outerwear`)
  - `brand` *(optional)*: Filter by brand name

### `GET /api/wardrobe/categories`
Returns aggregate item counts grouped across standard closet categories.

---

## 4. Outfit Inspiration & Matching (`/api/analysis`, `/api/matching`)

### `POST /api/analysis/analyze-image`
Processes an inspiration photograph (e.g. editorial shoot, street style) and deconstructs every visible fashion piece.

- **Content-Type**: `multipart/form-data`
- **Parameters**: `file` (UploadFile)

**Response (`200 OK`):**
```json
{
  "id": "e9124b61-464a-4a22-83e7-1428a9b23b44",
  "summary": "Sophisticated autumn ensemble with wool overcoat and leather boots",
  "vibe": "Minimalist Chic",
  "items": [
    {
      "category": "Outerwear",
      "sub_category": "Trench Coat",
      "primary_color": "Camel",
      "material": "Wool Blend"
    },
    {
      "category": "Footwear",
      "sub_category": "Ankle Boots",
      "primary_color": "Black",
      "material": "Leather"
    }
  ]
}
```

### `POST /api/matching/match-outfit`
Executes multi-attribute similarity scoring between inspiration items and pieces in the user's digital wardrobe.

- **Request Body**:
```json
{
  "inspiration_items": [
    { "category": "Tops", "primary_color": "White", "material": "Cotton" }
  ]
}
```

---

## 5. AI Stylist & Curated Lookbooks (`/api/recommendations`)

### `POST /api/recommendations/generate`
Generates personalized lookbooks based on occasion, weather conditions, and closet inventory.

- **Request Body**:
```json
{
  "occasion": "Casual Office",
  "weather": "Mild & Sunny (21°C)",
  "preferred_styles": ["Smart Casual", "Minimalist"]
}
```

**Response (`200 OK`):**
```json
{
  "recommendations": [
    {
      "id": "rec_01",
      "title": "Tailored Everyday Editorial",
      "occasion": "Casual Office",
      "styling_notes": "Pair the crisp poplin shirt with relaxed pleated trousers and loafers.",
      "match_score": 0.92,
      "items": [
        { "id": "item_1", "name": "Classic Oxford Shirt", "category": "Tops" },
        { "id": "item_2", "name": "Wide Pleated Trousers", "category": "Bottoms" }
      ]
    }
  ]
}
```

---

## 6. Virtual Try-On (`/api/tryon`)

### `POST /api/tryon/tasks`
Submits an asynchronous virtual try-on simulation job pairing a silhouette/model image with a wardrobe garment.

- **Status Code**: `202 Accepted`
- **Request Body**:
```json
{
  "user_image_path": "storage/tryon/model_pose.jpg",
  "garment_image_path": "storage/wardrobe/blouse.jpg",
  "garment_category": "Tops"
}
```

**Response (`202 Accepted`):**
```json
{
  "task_id": "tryon_7a2b8e3c",
  "status": "pending",
  "provider": "youcam",
  "created_at": "2026-10-23T18:15:00Z"
}
```

### `GET /api/tryon/tasks/{task_id}`
Polls task status (`pending`, `processing`, `success`, `failed`). When `success`, returns `result_image_url`.

---

## 7. Campus Communities & Shared Closets (`/api/communities`)

### `GET /api/communities`
Lists active fashion communities.

### `POST /api/communities`
Creates a new fashion community / style circle.

### `POST /api/communities/{id}/join`
Submits a membership request to join a community.

### `POST /api/communities/{id}/members/{user_id}/approve`
Community owner approves a pending applicant.

### `GET /api/communities/shared-closet`
Retrieves garments listed for borrowing across all communities joined by the authenticated user.

### `POST /api/communities/{id}/listings`
Lists a wardrobe item into the community's shared closet.

---

## 8. Garment Borrowing Requests (`/api/requests`)

### `POST /api/communities/{id}/listings/{listing_id}/requests`
Submits a request to borrow an available community garment.

- **Request Body**:
```json
{
  "message": "Would love to wear this for campus formal on Saturday!",
  "start_date": "2026-10-25T18:00:00Z",
  "end_date": "2026-10-26T12:00:00Z"
}
```

### `GET /api/requests/incoming`
Lists all borrow requests received for garments owned by the user.

### `GET /api/requests/outgoing`
Lists all borrow requests initiated by the user.

### `PATCH /api/requests/{id}/status`
Transitions the status of a borrow request (`accepted`, `declined`, `cancelled`, `completed`).

---

## 9. User Profiles & Privacy (`/api/users`)

### `GET /api/users/me`
Retrieves the user's full private profile, sizing specifications, and privacy settings.

### `PATCH /api/users/me/profile`
Updates personal sizing and fit preferences:
```json
{
  "full_name": "Elena Rostova",
  "bio": "Minimalist capsule curator & design student.",
  "tops_size": "M",
  "bottoms_size": "US 6 / 28",
  "shoe_size": "EU 39",
  "preferred_fit": "Relaxed"
}
```

### `PATCH /api/users/me/privacy`
Configures field-level privacy visibility toggles:
```json
{
  "show_profile_photo": true,
  "show_bio": true,
  "show_age": false,
  "show_phone": false,
  "show_email": false,
  "show_fit_preferences": true,
  "show_preferred_styles": true
}
```

### `GET /api/users/{user_id}/public-profile`
Retrieves another user's community-facing profile with unshared fields strictly scrubbed according to their privacy flags.

---

## 10. Activity & Notifications (`/api/notifications`)

### `GET /api/notifications`
Returns recent in-app activity notifications.

### `GET /api/notifications/unread-count`
Returns unread count for badge indicators: `{"unread_count": 3}`.

### `PATCH /api/notifications/{id}/read`
Marks a specific notification as read.

### `POST /api/notifications/read-all`
Marks all notifications as read.
