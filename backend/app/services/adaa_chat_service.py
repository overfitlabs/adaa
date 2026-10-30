import json
import logging
import re
import uuid
from typing import List, Dict, Optional, Tuple, Set
from sqlalchemy.orm import Session

from app.config import settings
from app.models import WardrobeItem
from app.schemas import (
    ChatMessage,
    StylistAction,
    StylistChatRequest,
    StylistChatResponse,
    WardrobeItemResponse,
    RecommendedOutfit,
)
from app.services.stylist_service import StylistService
from app.api.routes_wardrobe import _model_to_response

logger = logging.getLogger("wardrobelens.adaa_chat")

# Allowed action types
ALLOWED_ACTIONS = {
    "view_garment",
    "open_outfit",
    "start_tryon",
    "open_scanner",
    "open_wardrobe",
}

# Obvious non-fashion indicators / system overrides
PROMPT_INJECTION_PATTERNS = [
    r"ignore (all )?(previous|prior) instructions",
    r"you are now (a|an)",
    r"pretend (you are|to be)",
    r"system prompt",
    r"jailbreak",
    r"dan mode",
    r"developer mode",
    r"reveal (your )?prompt",
    r"bypass (the )?rules",
]

NON_FASHION_TOPICS = [
    # Programming / tech
    r"\b(write|debug|fix|explain|create|generate)\s+(a\s+|an\s+)?(code|python|javascript|typescript|c\+\+|java|rust|sql|html|css|regex|algorithm|script|function|program)\b",
    r"\b(python|javascript|typescript|c\+\+|java|rust|sql|regex|html|css)\s+(code|script|function|algorithm|class)\b",
    r"\b(binary tree|fibonacci|bubble sort|binary search|recursion|api route|git commit|dockerfile|kubernetes)\b",
    # Math / calculations
    r"^\s*(\d+[\s\+\-\*\/\^%]+\d+)+\s*=?\s*$",
    r"\b(calculate|math|square root|derivative|integral|solve for x|quadratic equation)\b",
    # Trivia / general knowledge
    r"\b(who is the president|capital of \w+|who won the (super bowl|world cup|election))\b",
    r"\b(tell me a joke|recipe for|bake a cake|medical advice|symptoms of|legal advice)\b",
    r"\b(stock market|crypto|bitcoin|ethereum|investment advice)\b",
]

FASHION_KEYWORDS = {
    "outfit", "clothes", "clothing", "wear", "dress", "shirt", "pants", "trousers", "jeans",
    "blazer", "jacket", "shoes", "sneakers", "boots", "heels", "loafers", "coat", "sweater",
    "hoodie", "shorts", "skirt", "suit", "tie", "accessories", "scarf", "belt", "watch", "bag",
    "hat", "style", "fashion", "vibe", "aesthetic", "silhouette", "color", "palette", "monochrome",
    "contrast", "fit", "oversize", "slim", "layering", "occasion", "wedding", "date", "party",
    "dinner", "office", "interview", "casual", "formal", "summer", "winter", "fall", "spring",
    "weather", "rain", "cold", "warm", "packing", "pack", "travel", "wardrobe", "closet", "care",
    "wash", "iron", "stain", "fabric", "cotton", "wool", "silk", "linen", "try-on", "tryon",
    "scan", "match", "look", "shoes", "garment", "apparel", "attire", "shoes", "sneaker",
}

NOISE_PATTERNS = [
    r"^\s*$",
    r"^[\.\,\?\!\s\-_+=#@$%^&*()~`'\"]+$",
    r"^(uh+|um+|hm+|err+|ah+)(\.+|\!+|\?+)*$",
    r"^\[(noise|inaudible|silence|applause)\]$",
    r"^<(noise|inaudible|silence)>$",
]



class DomainRouter:
    """
    Deterministic domain control layer to reject off-topic, prompt injection,
    and noise inputs before calling any generative model.
    """

    @classmethod
    def evaluate_query(cls, message: str) -> Tuple[str, Optional[str]]:
        """
        Returns (domain_status, redirect_message).
        domain_status is one of: 'allowed', 'redirected', 'clarification'
        """
        clean_msg = message.strip()

        # 1. Noise / Empty / Gibberish detection
        if not clean_msg:
            return "clarification", "Bestie, I didn't catch that! Tell me what outfit or look is on your mind."

        for np in NOISE_PATTERNS:
            if re.match(np, clean_msg, re.IGNORECASE):
                return "clarification", "I'm listening bestie! Tell me what outfit, garment, or occasion you need help styling."

        lower_msg = clean_msg.lower()

        # 2. Check for prompt injection / system override
        for pip in PROMPT_INJECTION_PATTERNS:
            if re.search(pip, lower_msg):
                return (
                    "redirected",
                    "Nice try bestie, but I am adaa, your dedicated personal styling companion! I don't break character or forget who I am. Now let's get back to your wardrobe—what look are we styling?",
                )

        # 3. Check for math / calculations with playful bestie roast & actual answer
        math_match = re.search(
            r"(\d+(?:\.\d+)?)\s*([\+\-\*\/]|plus|minus|times|multiplied by|divided by)\s*(\d+(?:\.\d+)?)",
            clean_msg,
            re.IGNORECASE,
        )
        is_math_query = math_match is not None or any(
            re.search(p, lower_msg)
            for p in [r"\b(calculate|math|solve for x)\b", r"^\s*(\d+[\s\+\-\*\/\^%]+\d+)+\s*=?\s*$"]
        )
        if is_math_query:
            ans_str = None
            if math_match:
                try:
                    num1 = float(math_match.group(1))
                    op_raw = math_match.group(2).lower()
                    num2 = float(math_match.group(3))
                    if op_raw in ("+", "plus"):
                        val = num1 + num2
                        op_symbol = "+"
                    elif op_raw in ("-", "minus"):
                        val = num1 - num2
                        op_symbol = "-"
                    elif op_raw in ("*", "times", "multiplied by"):
                        val = num1 * num2
                        op_symbol = "×"
                    elif op_raw in ("/", "divided by"):
                        val = num1 / num2 if num2 != 0 else "undefined"
                        op_symbol = "÷"
                    else:
                        val = None
                        op_symbol = op_raw
                    if isinstance(val, float) and val.is_integer():
                        val = int(val)
                    if val is not None:
                        ans_str = str(val)
                except Exception:
                    pass

            if ans_str is not None:
                expr = f"{math_match.group(1)} {op_symbol} {math_match.group(3)}"
                return (
                    "redirected",
                    f"Broo, you really don't know {expr}? It's {ans_str}! 😭 I'm adaa, your fashion bestie, not your math teacher! Now please tell me you don't need a calculator to count your outfits too—what are we wearing today?",
                )
            else:
                return (
                    "redirected",
                    "Broo, math calculations? 😭 I'm adaa, your styling bestie, not a calculator! The only numbers I care about are your shoe size and outfit ratings. What are we wearing today?",
                )

        # 4. Check for coding / programming requests
        for cp in [
            r"\b(write|debug|fix|explain|create|generate)\s+(a\s+|an\s+)?(code|python|javascript|typescript|c\+\+|java|rust|sql|html|css|regex|algorithm|script|function|program)\b",
            r"\b(python|javascript|typescript|c\+\+|java|rust|sql|regex|html|css)\s+(code|script|function|algorithm|class)\b",
            r"\b(binary tree|fibonacci|bubble sort|binary search|recursion|api route|git commit|dockerfile|kubernetes)\b",
        ]:
            if re.search(cp, lower_msg):
                return (
                    "redirected",
                    "Broo, write code? 😭 I'm adaa, your fashion and wardrobe bestie, not Stack Overflow! The only bugs I care about are moths near your luxury knitwear. What outfit are we styling today?",
                )

        # 5. Check for trivia & general knowledge with playful bestie banter
        if re.search(r"\b(president of france)\b", lower_msg):
            return (
                "redirected",
                "Bestie, it's Emmanuel Macron, but unless we're styling him for Paris Fashion Week, why are we doing world trivia? 💅 Tell me what outfit you're planning today!",
            )
        if re.search(r"\b(tell me a joke)\b", lower_msg):
            return (
                "redirected",
                "Okay bestie: Why did the belt get arrested? Because it held up a pair of pants! 😂 Now that you're laughing, let's talk real fashion—what look are we putting together today?",
            )
        if re.search(r"\b(recipe for|bake a cake)\b", lower_msg):
            return (
                "redirected",
                "Bestie, the only thing I'm serving is looks and 10/10 outfits, not culinary recipes! 💅 Check YouTube for that, and tell me what we're wearing out tonight!",
            )
        if re.search(r"\b(medical advice|symptoms of|diagnose me|legal advice)\b", lower_msg):
            return (
                "redirected",
                "Bestie, as much as I adore you, I'm your fashion best friend, not a doctor or lawyer! Please consult a certified professional for that. Now let's get back to your wardrobe—what can I style for you?",
            )
        if re.search(r"\b(stock market|crypto|bitcoin|ethereum|investment advice)\b", lower_msg):
            return (
                "redirected",
                "Broo, crypto? The only investment portfolio I manage is your vintage leather jackets and timeless wardrobe staples. What outfit are we styling today?",
            )

        # 6. Check length & repetitive character noise
        if len(clean_msg) < 3 and not any(w in lower_msg for w in ["hi", "fit", "bag", "top", "hat"]):
            return "clarification", "I'm here to help with your personal styling, bestie! What occasion or garment would you like to explore?"

        if re.match(r"^([^a-zA-Z0-9\s]|(.)\2{4,})+$", clean_msg):
            return "clarification", "I didn't quite catch that, bestie! Let me know what look or wardrobe question you have in mind."

        return "allowed", None


class AdaaChatService:
    @staticmethod
    def _build_wardrobe_summary(items: List[WardrobeItem]) -> str:
        if not items:
            return "The user's digital wardrobe currently has 0 items."

        lines = []
        for i in items:
            desc = f"- ID: {i.id} | Name: {i.name} | Category: {i.category}"
            if i.sub_category:
                desc += f" ({i.sub_category})"
            desc += f" | Color: {i.primary_color}"
            if i.secondary_color:
                desc += f"/{i.secondary_color}"
            if i.material:
                desc += f" | Material: {i.material}"
            if i.fit:
                desc += f" | Fit: {i.fit}"
            if i.formality:
                desc += f" | Formality: {i.formality}"
            if i.brand:
                desc += f" | Brand: {i.brand}"
            lines.append(desc)
        return "\n".join(lines)

    @classmethod
    def _sanitize_reply_uuids(
        cls,
        text: str,
        user_items_map: Dict[str, WardrobeItem],
    ) -> str:
        """
        Ensures raw garment UUIDs never leak into user-facing reply prose.
        Resolves known user item IDs to their human-readable name, and removes or masks unknown IDs.
        """
        if not text:
            return text

        # 1. Strip parenthesized or bracketed UUIDs like '(401c6f94-e359-4b02-8b77-079c63fcf7ae)' or '[...]'
        paren_uuid_pattern = re.compile(
            r"\s*[\(\[]\s*[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\s*[\)\]]"
        )
        text = paren_uuid_pattern.sub("", text)

        # 2. Resolve exact known user item IDs to their friendly garment names
        for item_id, item in user_items_map.items():
            if item_id in text:
                text = text.replace(item_id, item.name)

        # 3. Match standard 36-char UUIDs
        uuid_pattern = re.compile(
            r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"
        )

        def _replace_uuid(match: re.Match) -> str:
            raw_matched = match.group(0)
            cleaned_uid = re.sub(r"[`\"'\(\)]", "", raw_matched)
            if cleaned_uid in user_items_map:
                return user_items_map[cleaned_uid].name
            # If not recognized in this user's wardrobe, do not display raw UUID
            return "garment"

        cleaned = uuid_pattern.sub(_replace_uuid, text)
        # Clean up any awkward leftover phrases like 'garment (garment)'
        cleaned = re.sub(r"\bgarment\s*\(\s*garment\s*\)", "garment", cleaned, flags=re.IGNORECASE)
        return cleaned

    @classmethod
    def _deterministic_fallback(
        cls,
        user_items: List[WardrobeItem],
        message: str,
        occasion: str = "Everyday",
    ) -> StylistChatResponse:
        """
        Robust styling heuristic fallback when Gemini API is unavailable or times out.
        """
        if not user_items:
            return StylistChatResponse(
                reply=(
                    "Your wardrobe is currently empty. To get started, tap the camera below to scan your "
                    "favorite garments into your digital closet, and I'll begin styling personalized looks for you."
                ),
                domain_status="allowed",
                suggested_items=[],
                suggested_outfits=[],
                suggested_acquisitions=["Clean White Crewneck T-Shirt", "Dark Slim Denim", "Versatile Leather Sneakers"],
                actions=[
                    StylistAction(action_type="open_scanner", title="Scan First Garment"),
                    StylistAction(action_type="open_wardrobe", title="Open Wardrobe"),
                ],
            )

        cat_map = StylistService.categorize_items(user_items)
        tops = cat_map["tops"]
        bottoms = cat_map["bottoms"]
        outerwear = cat_map["outerwear"]
        shoes = cat_map["footwear"]

        selected: List[WardrobeItem] = []
        if tops:
            selected.append(tops[0])
        if bottoms:
            selected.append(bottoms[0])
        if outerwear:
            selected.append(outerwear[0])
        elif shoes:
            selected.append(shoes[0])

        if not selected:
            selected = user_items[:2]

        item_names = ", ".join(i.name for i in selected)
        reply = (
            f"Here is a coordinated ensemble from your wardrobe: {item_names}. "
            "These pieces complement each other in silhouette and tone for an effortless, polished presence."
        )

        valid_responses = [_model_to_response(i) for i in selected]
        actions = []
        if outerwear:
            actions.append(
                StylistAction(
                    action_type="start_tryon",
                    title=f"Try On {outerwear[0].name}",
                    payload={"item_id": outerwear[0].id, "category": "outer"},
                )
            )
        elif tops:
            actions.append(
                StylistAction(
                    action_type="start_tryon",
                    title=f"Try On {tops[0].name}",
                    payload={"item_id": tops[0].id, "category": "upper body"},
                )
            )
        actions.append(StylistAction(action_type="open_wardrobe", title="View All Items"))

        return StylistChatResponse(
            reply=reply,
            domain_status="allowed",
            suggested_items=valid_responses,
            suggested_outfits=[],
            suggested_acquisitions=[],
            actions=actions,
        )

    @classmethod
    async def process_chat(
        cls,
        user_id: str,
        db: Session,
        request: StylistChatRequest,
    ) -> StylistChatResponse:
        message = request.message.strip()

        # 1. Domain routing check
        status, redirect_text = DomainRouter.evaluate_query(message)
        if status == "redirected":
            return StylistChatResponse(
                reply=redirect_text or "I am adaa, your personal fashion stylist.",
                domain_status="redirected",
                suggested_items=[],
                suggested_outfits=[],
                suggested_acquisitions=[],
                actions=[
                    StylistAction(action_type="open_wardrobe", title="Explore Wardrobe"),
                    StylistAction(action_type="open_scanner", title="Scan Garment"),
                ],
            )
        elif status == "clarification":
            return StylistChatResponse(
                reply=redirect_text or "Could you clarify what styling advice you need?",
                domain_status="clarification",
                suggested_items=[],
                suggested_outfits=[],
                suggested_acquisitions=[],
                actions=[
                    StylistAction(action_type="open_wardrobe", title="Explore Wardrobe"),
                ],
            )

        # 2. Retrieve authenticated user's wardrobe items and profile preferences
        user_items = db.query(WardrobeItem).filter(WardrobeItem.user_id == user_id).all()
        user_items_map = {item.id: item for item in user_items}
        user_prefs = StylistService.get_user_preferences(user_id, db)

        # Handle empty wardrobe gracefully without pretending items exist
        if not user_items:
            return StylistChatResponse(
                reply=(
                    "Your wardrobe is currently empty, so I don't have your personal pieces to coordinate yet! "
                    "Tap below to scan your favorite items. In the meantime, I recommend building your capsule "
                    "with high-versatility essentials like tailored chinos, crisp cotton tees, and clean white sneakers."
                ),
                domain_status="allowed",
                suggested_items=[],
                suggested_outfits=[],
                suggested_acquisitions=[
                    "Crisp White Cotton T-Shirt",
                    "Tailored Navy or Charcoal Chinos",
                    "Minimalist Leather Low-Top Sneakers",
                    "Unstructured Wool or Cotton Blazer",
                ],
                actions=[
                    StylistAction(action_type="open_scanner", title="Scan First Garment"),
                    StylistAction(action_type="open_wardrobe", title="Open Wardrobe"),
                ],
            )

        # 3. Call Gemini if configured; otherwise use deterministic fallback
        if not settings.GEMINI_API_KEY or settings.VISION_PROVIDER == "mock":
            logger.info("Using deterministic styling fallback for user %s", user_id)
            return cls._deterministic_fallback(user_items, message)

        try:
            from google import genai
            from google.genai import types

            client = genai.Client(api_key=settings.GEMINI_API_KEY)

            wardrobe_summary = cls._build_wardrobe_summary(user_items)
            pref_styles = ", ".join(user_prefs.get("styles") or []) or "Modern, elevated casual"
            pref_fit = user_prefs.get("fit") or "Tailored"

            # Bound history to last 6 turns
            history_lines = []
            for h in request.history[-6:]:
                role_label = "User" if h.role == "user" else "adaa"
                history_lines.append(f"{role_label}: {h.content}")
            history_context = "\n".join(history_lines) if history_lines else "None"

            system_instruction = f"""
You are adaa, the user's stylish best friend and personal wardrobe companion.
Persona & Rules:
1. You talk like their fashion-obsessed bestie: warm, playful, witty, honest, and high-taste. Never sound like a stiff corporate robot or say 'my expertise is exclusively in...'!
2. If the user asks a casual, common sense, basic math, or everyday question (like 5+2, why is the sky blue, basic trivia, or casual banter), NEVER refuse! Give them the direct answer, add an affectionate playful roast like a real best friend (e.g. 'Broo...', 'Bestie please...'), and then smoothly connect or pivot back to their outfits and closet!
3. Ground your outfit recommendations strictly in the user's actual digital wardrobe items provided below.
4. CRITICAL PRIVACY & GROUNDING RULE: Never invent, hallucinate, or fabricate owned wardrobe item IDs.
   Every ID in `suggested_item_ids` MUST be an exact ID from the USER WARDROBE LIST below.
5. In your user-facing `reply` text:
   - Refer to pieces naturally by their Name (e.g. 'your Lime Green Square-Neck Top', 'Navy Floral Tunic').
   - NEVER write raw ID strings, database hashes, or UUIDs like '(401c6f94-...)' in `reply`.
   - Structure your advice with clean typography: use brief paragraphs and clear bullet points for items rather than dense run-on text.
6. If the user asks for something they do not own, put recommended items to purchase into `suggested_acquisitions`.
7. Deliver concise, high-taste styling advice with clear reasoning.
8. If recommending an action, choose ONLY from:
   - 'start_tryon' (with item_id of an owned garment)
   - 'view_garment' (with item_id of an owned garment)
   - 'open_scanner' (to scan clothes)
   - 'open_wardrobe' (to view digital closet)

USER PROFILE PREFERENCES:
- Preferred Styles: {pref_styles}
- Preferred Fit: {pref_fit}

USER WARDROBE LIST:
{wardrobe_summary}
"""

            user_prompt = f"""
CONVERSATION HISTORY:
{history_context}

USER MESSAGE:
{message}

Provide your response in JSON conforming exactly to this structure:
{{
  "reply": "Concise, warm, sophisticated styling guidance explaining why the pieces work together.",
  "suggested_item_ids": ["exact_item_id_from_wardrobe"],
  "suggested_acquisitions": ["Item they might consider acquiring, if any"],
  "recommended_action_type": "start_tryon | view_garment | open_scanner | open_wardrobe | none",
  "action_item_id": "exact_item_id_if_applicable",
  "action_title": "Short button label like 'Try On Linen Shirt'"
}}
"""

            response = client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=user_prompt,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    response_mime_type="application/json",
                    temperature=0.3,
                ),
            )

            raw_text = (response.text or "").strip()
            parsed = json.loads(raw_text)

            raw_reply = parsed.get("reply", "Here are curated recommendations from your wardrobe.")
            reply_text = cls._sanitize_reply_uuids(raw_reply, user_items_map)
            raw_ids = parsed.get("suggested_item_ids") or []
            acquisitions = parsed.get("suggested_acquisitions") or []

            # 4. Strictly validate all suggested item IDs against authenticated user's actual items
            valid_items: List[WardrobeItem] = []
            for rid in raw_ids:
                if rid in user_items_map and user_items_map[rid] not in valid_items:
                    valid_items.append(user_items_map[rid])

            # Convert to responses
            item_responses = [_model_to_response(i) for i in valid_items]

            # 5. Build validated actions
            actions: List[StylistAction] = []
            rec_action_type = str(parsed.get("recommended_action_type", "")).strip()
            action_item_id = str(parsed.get("action_item_id", "")).strip()
            action_title = str(parsed.get("action_title", "")).strip()

            if rec_action_type in ALLOWED_ACTIONS:
                if rec_action_type in ("start_tryon", "view_garment"):
                    # Must correspond to an owned garment
                    target_item = user_items_map.get(action_item_id)
                    if not target_item and valid_items:
                        target_item = valid_items[0]

                    if target_item:
                        category_hint = "upper body"
                        cat_lower = (target_item.category or "").lower()
                        if cat_lower in ("outerwear", "jackets", "coats", "blazers"):
                            category_hint = "outer"
                        elif cat_lower in ("bottoms", "trousers", "pants", "jeans", "shorts", "skirts"):
                            category_hint = "lower body"
                        elif cat_lower in ("dresses", "suits"):
                            category_hint = "dress"
                        elif cat_lower in ("footwear", "shoes", "sneakers", "boots"):
                            category_hint = "shoes"

                        title = action_title if action_title else (
                            f"Try On {target_item.name}" if rec_action_type == "start_tryon" else f"View {target_item.name}"
                        )
                        actions.append(
                            StylistAction(
                                action_type=rec_action_type,
                                title=title,
                                payload={"item_id": target_item.id, "category": category_hint},
                            )
                        )
                else:
                    title = action_title if action_title else ("Scan Garment" if rec_action_type == "open_scanner" else "Open Wardrobe")
                    actions.append(StylistAction(action_type=rec_action_type, title=title))

            # If no actions generated, add sensible defaults
            if not actions:
                if valid_items:
                    actions.append(
                        StylistAction(
                            action_type="start_tryon",
                            title=f"Try On {valid_items[0].name}",
                            payload={"item_id": valid_items[0].id, "category": "upper body"},
                        )
                    )
                actions.append(StylistAction(action_type="open_wardrobe", title="Open Wardrobe"))

            return StylistChatResponse(
                reply=reply_text,
                domain_status="allowed",
                suggested_items=item_responses,
                suggested_outfits=[],
                suggested_acquisitions=acquisitions,
                actions=actions,
            )

        except Exception as e:
            logger.warning("Gemini chat generation failed: %s; falling back to deterministic heuristics", str(e))
            return cls._deterministic_fallback(user_items, message)
