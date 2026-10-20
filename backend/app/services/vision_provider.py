import abc
import asyncio
import json
import logging
import re
import time
import uuid
from pathlib import Path
from typing import List, Tuple
from app.config import settings
from app.schemas import DetectedFashionItem, StyleAttributes

logger = logging.getLogger("wardrobelens.vision")


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
    def __init__(self, api_key: str, model_name: str = "gemini-2.5-flash", timeout_seconds: int = 40):
        self.api_key = api_key
        self.model_name = model_name
        self.timeout_seconds = timeout_seconds

    async def analyze_outfit_image(
        self, image_path: Path
    ) -> Tuple[str, str, List[DetectedFashionItem]]:
        from google import genai
        from google.genai import types
        from google.genai.errors import APIError
        from PIL import Image

        start_time = time.time()
        logger.info(
            "GeminiVisionProvider: Initiating analysis with model '%s' (timeout: %ds)",
            self.model_name,
            self.timeout_seconds,
        )

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
      "bounding_box_description": "Upper body outer layer",
      "box_2d": [150, 150, 650, 850]
    }
  ]
}
Note: box_2d is [ymin, xmin, ymax, xmax] with coordinates normalized from 0 to 1000.
"""

        # Preprocess and resize image if necessary to prevent large payload network bottlenecks
        with Image.open(image_path) as raw_img:
            if raw_img.mode != "RGB":
                pil_img = raw_img.convert("RGB")
            else:
                pil_img = raw_img.copy()

            orig_w, orig_h = pil_img.size
            max_dim = 1600
            if max(orig_w, orig_h) > max_dim:
                pil_img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
                logger.info(
                    "Resized image for Gemini inference from %dx%d to %dx%d",
                    orig_w,
                    orig_h,
                    pil_img.width,
                    pil_img.height,
                )

        try:
            # Asynchronous non-blocking call with explicit timeout
            coro = client.aio.models.generate_content(
                model=self.model_name,
                contents=[pil_img, prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.2,
                ),
            )
            response = await asyncio.wait_for(coro, timeout=self.timeout_seconds)
        except asyncio.TimeoutError:
            elapsed = time.time() - start_time
            logger.error("GeminiVisionProvider: Call timed out after %.2fs", elapsed)
            raise TimeoutError(
                f"Gemini AI vision analysis timed out after {self.timeout_seconds}s. The service may be under heavy load."
            )
        except APIError as e:
            elapsed = time.time() - start_time
            logger.error("GeminiVisionProvider: APIError (%s) after %.2fs: %s", getattr(e, "code", "UNKNOWN"), elapsed, str(e))
            status_code = getattr(e, "code", None)
            if status_code in (401, 403):
                raise PermissionError("Gemini API authentication failed. Please verify your GEMINI_API_KEY.")
            elif status_code == 429:
                raise RuntimeError("Gemini API quota or rate limit exceeded. Please try again later.")
            elif status_code == 503:
                raise RuntimeError("Gemini model is currently experiencing high demand. Please try again shortly.")
            raise RuntimeError(f"Gemini API error: {str(e)}")
        except Exception as e:
            elapsed = time.time() - start_time
            logger.error("GeminiVisionProvider: Unexpected error after %.2fs: %s", elapsed, str(e), exc_info=True)
            raise RuntimeError(f"Unexpected vision provider failure: {str(e)}")

        raw_text = response.text or ""
        # Strip markdown code blocks if the model wrapped output in ```json ... ```
        cleaned_text = raw_text.strip()
        if cleaned_text.startswith("```"):
            cleaned_text = re.sub(r"^```(?:json)?\s*", "", cleaned_text, flags=re.IGNORECASE)
            cleaned_text = re.sub(r"\s*```$", "", cleaned_text)

        try:
            parsed = json.loads(cleaned_text)
        except json.JSONDecodeError as e:
            logger.error("GeminiVisionProvider: Failed to parse JSON response: %s", str(e))
            raise ValueError(f"Failed to parse structured JSON response from Gemini model: {str(e)}")

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
            raw_box = item_data.get("box_2d")
            box_2d = None
            if isinstance(raw_box, (list, tuple)) and len(raw_box) == 4:
                try:
                    box_2d = [int(v) for v in raw_box]
                except (ValueError, TypeError):
                    box_2d = None

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
                box_2d=box_2d,
            )
            items.append(item)

        elapsed = time.time() - start_time
        logger.info(
            "GeminiVisionProvider: Analysis completed successfully in %.2fs (detected %d items, vibe='%s')",
            elapsed,
            len(items),
            vibe,
        )
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
                    box_2d=[150, 200, 750, 800],
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
                    box_2d=[500, 250, 950, 750],
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
                    box_2d=[150, 150, 650, 850],
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
                    box_2d=[250, 250, 600, 750],
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
                    box_2d=[550, 250, 920, 750],
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
                    box_2d=[850, 280, 980, 720],
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
                    box_2d=[400, 100, 650, 300],
                ),
            ]
            summary = "Sophisticated minimalist ensemble balancing a structured navy blazer with clean white base and charcoal trousers."
            vibe = "Minimalist Sartorial"

        return summary, vibe, items


def get_vision_provider() -> VisionProvider:
    if settings.VISION_PROVIDER.lower() == "gemini":
        if settings.GEMINI_API_KEY:
            logger.info("Vision provider configured: GeminiVisionProvider (model=%s, timeout=%ds)", settings.GEMINI_MODEL, settings.VISION_TIMEOUT_SECONDS)
            return GeminiVisionProvider(
                api_key=settings.GEMINI_API_KEY,
                model_name=settings.GEMINI_MODEL,
                timeout_seconds=settings.VISION_TIMEOUT_SECONDS,
            )
        else:
            logger.warning("VISION_PROVIDER is 'gemini' but GEMINI_API_KEY is missing! Falling back to MockVisionProvider.")
    else:
        logger.info("Vision provider configured: MockVisionProvider (VISION_PROVIDER='%s')", settings.VISION_PROVIDER)
    return MockVisionProvider()
