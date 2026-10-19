import abc
import json
import uuid
from pathlib import Path
from typing import List, Tuple
from app.config import settings
from app.schemas import DetectedFashionItem, StyleAttributes


class VisionProvider(abc.ABC):
    @abc.abstractmethod
    async def analyze_outfit_image(
        self, image_path: Path
    ) -> Tuple[str, str, List[DetectedFashionItem]]:
        """
        Analyze an outfit image.
        Returns: (summary, vibe, list of detected items)
        """
        pass


class GeminiVisionProvider(VisionProvider):
    def __init__(self, api_key: str, model_name: str = "gemini-2.5-flash"):
        self.api_key = api_key
        self.model_name = model_name

    async def analyze_outfit_image(
        self, image_path: Path
    ) -> Tuple[str, str, List[DetectedFashionItem]]:
        from google import genai
        from google.genai import types
        from PIL import Image

        client = genai.Client(api_key=self.api_key)

        prompt = """
You are an expert fashion stylist and garment analyst.
Examine this image carefully. Note that it may contain a person wearing an outfit, a mannequin, a flat-lay of clothes on a bed/surface, or individual garments and accessories.

Identify every distinct visible clothing piece and accessory. Include:
- tops, shirts, t-shirts, sweaters
- trousers, jeans, pants, shorts, skirts
- jackets, coats, blazers, cardigans
- footwear (sneakers, boots, loafers, heels)
- bags, backpacks, clutches
- watches, jewelry, belts, sunglasses, hats, scarves

For each item, provide:
1. category (one of: tops, shirts, trousers, jeans, jackets, footwear, bags, watches, jewelry, hats, sunglasses, other)
2. sub_category (e.g. 'Oversized Double-Breasted Blazer', 'Straight Leg Denim Jeans')
3. descriptive name
4. primary_color (e.g. 'navy', 'cream', 'charcoal', 'olive', 'black')
5. secondary_color (if any)
6. style attributes: pattern, material, fit, formality (casual, smart-casual, formal, athleisure), season, neckline_or_collar
7. position/layer description

Provide your response in strictly valid JSON format matching this schema:
{
  "summary": "Concise 1-2 sentence aesthetic breakdown of the outfit",
  "vibe": "e.g. Scandinavian Minimalist, Smart Casual, Streetwear, Parisian Chic",
  "items": [
    {
      "category": "jackets",
      "sub_category": "Blazer",
      "name": "Navy Wool Tailored Blazer",
      "primary_color": "Navy",
      "secondary_color": null,
      "attributes": {
        "pattern": "solid",
        "material": "wool",
        "fit": "tailored",
        "formality": "smart-casual",
        "season": "all-season",
        "neckline_or_collar": "notch lapel"
      },
      "confidence": 0.95,
      "bounding_box_description": "Upper body outer layer"
    }
  ]
}
"""

        with Image.open(image_path) as pil_img:
            # Call Gemini with structured JSON configuration
            response = client.models.generate_content(
                model=self.model_name,
                contents=[pil_img, prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.2,
                ),
            )

        parsed = json.loads(response.text)
        summary = parsed.get("summary", "Complete curated outfit.")
        vibe = parsed.get("vibe", "Contemporary Chic")
        items = []

        for item_data in parsed.get("items", []):
            attr_dict = item_data.get("attributes", {})
            attributes = StyleAttributes(
                pattern=attr_dict.get("pattern"),
                material=attr_dict.get("material"),
                fit=attr_dict.get("fit"),
                formality=attr_dict.get("formality"),
                season=attr_dict.get("season"),
                neckline_or_collar=attr_dict.get("neckline_or_collar"),
            )
            item = DetectedFashionItem(
                id=str(uuid.uuid4()),
                category=item_data.get("category", "other").lower(),
                sub_category=item_data.get("sub_category"),
                name=item_data.get("name", "Fashion Item"),
                primary_color=item_data.get("primary_color", "Neutral"),
                secondary_color=item_data.get("secondary_color"),
                attributes=attributes,
                confidence=float(item_data.get("confidence", 0.9)),
                bounding_box_description=item_data.get("bounding_box_description"),
            )
            items.append(item)

        return summary, vibe, items


class MockVisionProvider(VisionProvider):
    """
    High-fidelity mock provider for automated tests, offline development,
    and when live credentials are not yet configured.
    Generates realistic, varied, structured fashion breakdowns.
    """

    async def analyze_outfit_image(
        self, image_path: Path
    ) -> Tuple[str, str, List[DetectedFashionItem]]:
        filename = image_path.name.lower()

        # Provide context-sensitive mock items based on file name or generic smart look
        if "top" in filename or "shirt" in filename:
            items = [
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="shirts",
                    sub_category="Oxford Shirt",
                    name="Classic White Button-Down Oxford",
                    primary_color="White",
                    secondary_color=None,
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="cotton",
                        fit="regular",
                        formality="smart-casual",
                        season="all-season",
                        neckline_or_collar="button-down collar",
                    ),
                    confidence=0.96,
                    bounding_box_description="Upper body core garment",
                )
            ]
            summary = "A timeless white oxford button-down shirt ideal for layering or crisp standalone wear."
            vibe = "Smart Casual / Clean Prep"
        elif "pant" in filename or "jean" in filename or "trousers" in filename:
            items = [
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="jeans",
                    sub_category="Straight Leg Jeans",
                    name="Classic Indigo Straight-Leg Jeans",
                    primary_color="Indigo",
                    secondary_color="Blue",
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="denim",
                        fit="straight",
                        formality="casual",
                        season="all-season",
                    ),
                    confidence=0.94,
                    bounding_box_description="Lower body garment",
                )
            ]
            summary = "High-rise indigo denim with subtle whiskering and tailored straight-leg cut."
            vibe = "Effortless Everyday"
        else:
            # Full outfit breakdown: Jacket, Top, Bottom, Footwear, Accessory
            items = [
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="jackets",
                    sub_category="Blazer",
                    name="Relaxed Navy Wool-Blend Blazer",
                    primary_color="Navy",
                    secondary_color="Black",
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="wool",
                        fit="relaxed",
                        formality="smart-casual",
                        season="fall/winter",
                        neckline_or_collar="notch lapel",
                    ),
                    confidence=0.95,
                    bounding_box_description="Upper body outer layer",
                ),
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="tops",
                    sub_category="T-Shirt",
                    name="Essential Crewneck White T-Shirt",
                    primary_color="White",
                    secondary_color=None,
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="cotton",
                        fit="regular",
                        formality="casual",
                        season="all-season",
                        neckline_or_collar="crew neck",
                    ),
                    confidence=0.92,
                    bounding_box_description="Upper body base layer",
                ),
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="trousers",
                    sub_category="Pleated Trousers",
                    name="Tailored Charcoal Grey Trousers",
                    primary_color="Charcoal",
                    secondary_color=None,
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="wool",
                        fit="relaxed",
                        formality="smart-casual",
                        season="all-season",
                    ),
                    confidence=0.93,
                    bounding_box_description="Lower body trousers",
                ),
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="footwear",
                    sub_category="Loafers",
                    name="Chunky Black Leather Loafers",
                    primary_color="Black",
                    secondary_color=None,
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="leather",
                        fit="standard",
                        formality="smart-casual",
                        season="all-season",
                    ),
                    confidence=0.91,
                    bounding_box_description="Footwear",
                ),
                DetectedFashionItem(
                    id=str(uuid.uuid4()),
                    category="bags",
                    sub_category="Crossbody Bag",
                    name="Minimalist Black Leather Crossbody",
                    primary_color="Black",
                    secondary_color="Silver",
                    attributes=StyleAttributes(
                        pattern="solid",
                        material="leather",
                        formality="casual",
                    ),
                    confidence=0.88,
                    bounding_box_description="Side accessory",
                ),
            ]
            summary = "Sophisticated minimalist ensemble balancing a structured navy blazer with clean white base and charcoal trousers."
            vibe = "Minimalist Sartorial"

        return summary, vibe, items


def get_vision_provider() -> VisionProvider:
    if settings.VISION_PROVIDER.lower() == "gemini" and settings.GEMINI_API_KEY:
        return GeminiVisionProvider(
            api_key=settings.GEMINI_API_KEY,
            model_name=settings.GEMINI_MODEL,
        )
    return MockVisionProvider()
