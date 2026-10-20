import io
import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from pathlib import Path
from app.services.vision_provider import GeminiVisionProvider


def test_analyze_outfit_image_and_history(client, sample_image_bytes):
    from app.schemas import DetectedFashionItem, StyleAttributes
    sample_item = DetectedFashionItem(
        id="item-test-1",
        category="jackets",
        sub_category="Blazer",
        name="Navy Wool Blazer",
        primary_color="Navy",
        attributes=StyleAttributes(material="wool", formality="smart-casual"),
    )
    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Classic tailored outfit", "Smart Casual", [sample_item])
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 200
        data = response.json()
        assert "analysis_id" in data
        assert "summary" in data
        assert "vibe_or_style" in data
        assert len(data["items"]) >= 1

        analysis_id = data["analysis_id"]

        # Retrieve by ID
        get_res = client.get(f"/api/analysis/{analysis_id}")
        assert get_res.status_code == 200
        assert get_res.json()["analysis_id"] == analysis_id

        # List history
        list_res = client.get("/api/analysis")
        assert list_res.status_code == 200
        assert any(a["analysis_id"] == analysis_id for a in list_res.json())


def test_analyze_outfit_image_timeout_handling(client, sample_image_bytes):
    files = {"file": ("timeout_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=TimeoutError("Gemini AI vision analysis timed out after 40s. The service may be under heavy load.")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 504
        assert "timed out" in response.json()["detail"].lower()


def test_analyze_outfit_image_auth_failure_handling(client, sample_image_bytes):
    files = {"file": ("auth_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=PermissionError("Gemini API authentication failed. Please verify your GEMINI_API_KEY.")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 401
        assert "authentication failed" in response.json()["detail"].lower()


def test_analyze_outfit_image_unavailable_handling(client, sample_image_bytes):
    files = {"file": ("unavailable_test.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            side_effect=RuntimeError("Gemini model is currently experiencing high demand. Please try again shortly. (status 503)")
        )
        mock_get_provider.return_value = mock_provider

        response = client.post("/api/analysis/analyze-image", files=files)
        assert response.status_code == 503
        assert "high demand" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_gemini_vision_provider_markdown_fences_and_parsing(tmp_path):
    # Create test image file
    from PIL import Image
    test_img_path = tmp_path / "test_garment.jpg"
    Image.new("RGB", (100, 100), color="blue").save(test_img_path)

    provider = GeminiVisionProvider(api_key="mock-key-for-unit-test", model_name="gemini-2.5-flash", timeout_seconds=5)

    mock_gemini_json = {
        "summary": "Crisp minimalist outfit",
        "vibe": "Minimalist Sartorial",
        "items": [
            {
                "category": "jackets",
                "sub_category": "Blazer",
                "name": "Navy Wool Blazer",
                "primary_color": "Navy",
                "secondary_color": None,
                "attributes": {
                    "pattern": "solid",
                    "material": "wool",
                    "fit": "tailored",
                    "formality": "smart-casual"
                },
                "confidence": 0.98,
                "bounding_box_description": "Upper body outer garment"
            }
        ]
    }
    # Wrap in markdown fences as LLMs frequently do
    wrapped_text = f"```json\n{json.dumps(mock_gemini_json)}\n```"

    mock_response = MagicMock()
    mock_response.text = wrapped_text

    with patch("google.genai.Client") as mock_client_cls:
        mock_client = MagicMock()
        mock_aio = MagicMock()
        mock_models = MagicMock()
        mock_models.generate_content = AsyncMock(return_value=mock_response)
        mock_aio.models = mock_models
        mock_client.aio = mock_aio
        mock_client_cls.return_value = mock_client

        summary, vibe, items = await provider.analyze_outfit_image(test_img_path)

        assert summary == "Crisp minimalist outfit"
        assert vibe == "Minimalist Sartorial"
        assert len(items) == 1
        assert items[0].name == "Navy Wool Blazer"
        assert items[0].category == "jackets"
        assert items[0].primary_color == "Navy"
        assert items[0].attributes.material == "wool"
