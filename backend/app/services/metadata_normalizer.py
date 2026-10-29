"""
Canonical metadata definitions and normalization service for ADAA garments.
Provides consistent canonical values, capitalization, and whitespace handling
for structured garment attributes (category, colors, pattern, material, fit, season, formality).

Ensures:
- Consistent lowercase/clean representations for structured filters.
- Distinguishes distinct variants (e.g., 'cotton blend' vs 'cotton').
- Prevents verbose sentence dumps into concise attribute fields (e.g., fit).
- Leaves uncertain/uninferable values as None rather than fabricating guesses.
- Backward compatibility with legacy database values.
"""

import re
from typing import Optional, Dict, Any, Tuple


# --- Canonical Categories ---
CANONICAL_CATEGORIES = {
    "tops",
    "bottoms",
    "outerwear",
    "dresses",
    "shoes",
    "bags",
    "accessories",
    "other",
}

CATEGORY_ALIASES = {
    # Tops
    "top": "tops",
    "shirt": "tops",
    "shirts": "tops",
    "t-shirt": "tops",
    "tshirt": "tops",
    "tee": "tops",
    "blouse": "tops",
    "blouses": "tops",
    "sweater": "tops",
    "sweaters": "tops",
    "knitwear": "tops",
    "hoodie": "tops",
    "hoodies": "tops",
    "sweatshirt": "tops",
    "sweatshirts": "tops",
    "tank": "tops",
    "tank top": "tops",
    "polo": "tops",
    "cardigan top": "tops",
    "camisole": "tops",
    "crop top": "tops",
    # Bottoms
    "bottom": "bottoms",
    "pant": "bottoms",
    "pants": "bottoms",
    "trouser": "bottoms",
    "trousers": "bottoms",
    "jean": "bottoms",
    "jeans": "bottoms",
    "denim": "bottoms",
    "short": "bottoms",
    "shorts": "bottoms",
    "skirt": "bottoms",
    "skirts": "bottoms",
    "leggings": "bottoms",
    "legging": "bottoms",
    "slacks": "bottoms",
    "chinos": "bottoms",
    "sweatpants": "bottoms",
    "joggers": "bottoms",
    # Outerwear
    "jacket": "outerwear",
    "jackets": "outerwear",
    "coat": "outerwear",
    "coats": "outerwear",
    "blazer": "outerwear",
    "blazers": "outerwear",
    "cardigan": "outerwear",
    "cardigans": "outerwear",
    "trench": "outerwear",
    "trench coat": "outerwear",
    "parka": "outerwear",
    "vest": "outerwear",
    "bomber": "outerwear",
    "windbreaker": "outerwear",
    "shacket": "outerwear",
    "overcoat": "outerwear",
    # Dresses
    "dress": "dresses",
    "gown": "dresses",
    "gowns": "dresses",
    "jumpsuit": "dresses",
    "jumpsuits": "dresses",
    "romper": "dresses",
    "sari": "dresses",
    "saree": "dresses",
    "lehenga": "dresses",
    "kurta": "dresses",
    "anarkali": "dresses",
    # Shoes
    "shoe": "shoes",
    "footwear": "shoes",
    "sneaker": "shoes",
    "sneakers": "shoes",
    "boot": "shoes",
    "boots": "shoes",
    "loafer": "shoes",
    "loafers": "shoes",
    "heel": "shoes",
    "heels": "shoes",
    "sandal": "shoes",
    "sandals": "shoes",
    "flats": "shoes",
    "slippers": "shoes",
    "mules": "shoes",
    "oxfords": "shoes",
    # Bags
    "bag": "bags",
    "handbag": "bags",
    "handbags": "bags",
    "backpack": "bags",
    "backpacks": "bags",
    "tote": "bags",
    "totes": "bags",
    "clutch": "bags",
    "crossbody": "bags",
    "purse": "bags",
    "satchel": "bags",
    "duffle": "bags",
    # Accessories
    "accessory": "accessories",
    "hat": "accessories",
    "hats": "accessories",
    "cap": "accessories",
    "caps": "accessories",
    "beanie": "accessories",
    "belt": "accessories",
    "belts": "accessories",
    "scarf": "accessories",
    "scarves": "accessories",
    "sunglasses": "accessories",
    "glasses": "accessories",
    "watch": "accessories",
    "watches": "accessories",
    "jewelry": "accessories",
    "jewellery": "accessories",
    "necklace": "accessories",
    "earring": "accessories",
    "earrings": "accessories",
    "bracelet": "accessories",
    "ring": "accessories",
}


# --- Canonical Colors ---
CANONICAL_COLORS = {
    "black",
    "white",
    "grey",
    "navy",
    "blue",
    "light blue",
    "dark blue",
    "indigo",
    "red",
    "burgundy",
    "maroon",
    "pink",
    "blush",
    "green",
    "olive",
    "sage",
    "emerald",
    "forest green",
    "lime green",
    "mint",
    "brown",
    "tan",
    "beige",
    "camel",
    "khaki",
    "cream",
    "off-white",
    "yellow",
    "mustard",
    "orange",
    "rust",
    "coral",
    "purple",
    "lavender",
    "plum",
    "gold",
    "silver",
    "bronze",
    "copper",
    "metallic",
    "multicolor",
    "neutral",
}

COLOR_ALIASES = {
    "gray": "grey",
    "light-blue": "light blue",
    "lightblue": "light blue",
    "dark-blue": "dark blue",
    "darkblue": "dark blue",
    "navy blue": "navy",
    "navy-blue": "navy",
    "off white": "off-white",
    "offwhite": "off-white",
    "lime-green": "lime green",
    "forest-green": "forest green",
    "charcoal": "grey",
    "anthracite": "grey",
    "taupe": "beige",
    "sand": "beige",
    "ecru": "cream",
    "ivory": "cream",
    "wine": "burgundy",
    "cyan": "blue",
    "turquoise": "blue",
    "teal": "green",
    "multi": "multicolor",
    "multi-color": "multicolor",
    "multi-colour": "multicolor",
    "patterned": "multicolor",
}


# --- Canonical Patterns ---
CANONICAL_PATTERNS = {
    "solid",
    "striped",
    "plaid",
    "checkered",
    "floral",
    "polka dot",
    "graphic print",
    "geometric",
    "animal print",
    "abstract",
    "houndstooth",
    "camo",
    "tie-dye",
    "herringbone",
    "paisley",
    "gingham",
    "colorblock",
    "embroidered",
    "textured",
}

PATTERN_ALIASES = {
    "stripes": "striped",
    "stripe": "striped",
    "vertical stripes": "striped",
    "horizontal stripes": "striped",
    "pinstripe": "striped",
    "pinstriped": "striped",
    "checks": "checkered",
    "check": "checkered",
    "tartan": "plaid",
    "polka-dot": "polka dot",
    "polka dots": "polka dot",
    "dots": "polka dot",
    "spotted": "polka dot",
    "graphic": "graphic print",
    "printed": "graphic print",
    "screenprint": "graphic print",
    "logo": "graphic print",
    "plain": "solid",
    "none": "solid",
    "no pattern": "solid",
    "monochrome": "solid",
    "color block": "colorblock",
    "color-block": "colorblock",
    "hound's tooth": "houndstooth",
    "hound tooth": "houndstooth",
    "camouflage": "camo",
    "leopard": "animal print",
    "cheetah": "animal print",
    "zebra": "animal print",
    "snake": "animal print",
    "snakeskin": "animal print",
    "waffle": "textured",
    "ribbed": "textured",
    "cable knit": "textured",
}


# --- Canonical Materials ---
CANONICAL_MATERIALS = {
    "cotton",
    "cotton blend",
    "denim",
    "wool",
    "wool blend",
    "linen",
    "silk",
    "leather",
    "faux leather",
    "suede",
    "faux suede",
    "cashmere",
    "polyester",
    "nylon",
    "spandex",
    "viscose",
    "rayon",
    "modal",
    "fleece",
    "velvet",
    "corduroy",
    "satin",
    "chiffon",
    "lace",
    "canvas",
    "knit",
    "tweed",
    "down",
    "mesh",
}

MATERIAL_ALIASES = {
    "100% cotton": "cotton",
    "pure cotton": "cotton",
    "organic cotton": "cotton",
    "cotton-blend": "cotton blend",
    "poly-cotton": "cotton blend",
    "poly cotton": "cotton blend",
    "jean": "denim",
    "chambray": "denim",
    "100% wool": "wool",
    "pure wool": "wool",
    "merino wool": "wool",
    "merino": "wool",
    "wool-blend": "wool blend",
    "leatherette": "faux leather",
    "vegan leather": "faux leather",
    "pleather": "faux leather",
    "pu leather": "faux leather",
    "synthetic": "polyester",
    "synthetics": "polyester",
    "poly": "polyester",
    "elastane": "spandex",
    "lycra": "spandex",
    "jersey": "cotton blend",
}


# --- Canonical Fits ---
CANONICAL_FITS = {
    "slim",
    "regular",
    "relaxed",
    "oversized",
    "tailored",
    "skinny",
    "loose",
    "straight",
    "wide leg",
    "tapered",
    "cropped",
    "fitted",
    "athletic",
}

FIT_ALIASES = {
    "slim fit": "slim",
    "slim-fit": "slim",
    "regular fit": "regular",
    "standard": "regular",
    "standard fit": "regular",
    "classic": "regular",
    "classic fit": "regular",
    "relaxed fit": "relaxed",
    "relax": "relaxed",
    "oversize": "oversized",
    "baggy": "oversized",
    "skinny fit": "skinny",
    "tight": "fitted",
    "form-fitting": "fitted",
    "bodycon": "fitted",
    "wide-leg": "wide leg",
    "wide": "wide leg",
    "flare": "wide leg",
    "flared": "wide leg",
    "bootcut": "straight",
    "crop": "cropped",
    "shortened": "cropped",
    "taper": "tapered",
}


# --- Canonical Seasons ---
CANONICAL_SEASONS = {
    "spring",
    "summer",
    "fall",
    "winter",
    "all-season",
}

SEASON_ALIASES = {
    "autumn": "fall",
    "all season": "all-season",
    "all seasons": "all-season",
    "all-year": "all-season",
    "year-round": "all-season",
    "year round": "all-season",
    "transitional": "all-season",
    "spring/summer": "summer",
    "ss": "summer",
    "fall/winter": "winter",
    "fw": "winter",
    "autumn/winter": "winter",
}


# --- Canonical Formality ---
CANONICAL_FORMALITIES = {
    "casual",
    "smart-casual",
    "business-casual",
    "formal",
    "athleisure",
    "cocktail",
    "lounge",
}

FORMALITY_ALIASES = {
    "smart casual": "smart-casual",
    "business casual": "business-casual",
    "black tie": "formal",
    "gala": "formal",
    "evening": "formal",
    "athletic": "athleisure",
    "sportswear": "athleisure",
    "activewear": "athleisure",
    "gym": "athleisure",
    "loungewear": "lounge",
}


def _clean_str(val: Optional[str]) -> Optional[str]:
    """Strips leading/trailing whitespace and excessive internal whitespace."""
    if val is None:
        return None
    s = str(val).strip()
    if not s or s.lower() in ("none", "null", "n/a", "unknown", "undefined"):
        return None
    s = re.sub(r"\s+", " ", s)
    return s


def normalize_category(category: Optional[str]) -> str:
    """
    Normalizes a category string to a canonical ADAA category.
    Defaults to 'other' if unrecognized.
    """
    s = _clean_str(category)
    if not s:
        return "other"
    low = s.lower()
    if low in CANONICAL_CATEGORIES:
        return low
    if low in CATEGORY_ALIASES:
        return CATEGORY_ALIASES[low]
    # Check substring containment
    for alias, canon in CATEGORY_ALIASES.items():
        if alias in low:
            return canon
    return "other"


def normalize_color(color: Optional[str], default_neutral: bool = False) -> Optional[str]:
    """
    Normalizes a color descriptor.
    Preserves distinct shades (e.g. 'lime green', 'forest green', 'off-white').
    Returns lowercase canonical string or cleaned string.
    """
    s = _clean_str(color)
    if not s:
        return "neutral" if default_neutral else None
    low = s.lower()
    if low in CANONICAL_COLORS:
        return low
    if low in COLOR_ALIASES:
        return COLOR_ALIASES[low]
    for alias, canon in COLOR_ALIASES.items():
        if alias in low:
            return canon
    for canon in CANONICAL_COLORS:
        if canon in low:
            return canon
    # If not in canonical sets, return cleaned lowercase if <= 30 chars
    if len(low) <= 30:
        return low
    return "neutral" if default_neutral else None


def normalize_pattern(pattern: Optional[str]) -> Optional[str]:
    """
    Normalizes a pattern string.
    Rejects sentence-length descriptions and uncertain values.
    """
    s = _clean_str(pattern)
    if not s:
        return None
    low = s.lower()
    if low in CANONICAL_PATTERNS:
        return low
    if low in PATTERN_ALIASES:
        return PATTERN_ALIASES[low]
    for alias, canon in PATTERN_ALIASES.items():
        if alias in low:
            return canon
    for canon in CANONICAL_PATTERNS:
        if canon in low:
            return canon
    if len(low) <= 25 and not any(w in low for w in ("look", "garment", "outfit", "style", "wearing")):
        return low
    return None


def normalize_material(material: Optional[str]) -> Optional[str]:
    """
    Normalizes fabric/material composition.
    Preserves distinction between 'cotton blend' and 'cotton'.
    Rejects long sentences or uninferable strings.
    """
    s = _clean_str(material)
    if not s:
        return None
    low = s.lower()
    # Check blends first so 'cotton blend' doesn't accidentally collapse to 'cotton'
    if "blend" in low or "poly-cotton" in low:
        if "wool" in low:
            return "wool blend"
        if "cotton" in low:
            return "cotton blend"
    if low in CANONICAL_MATERIALS:
        return low
    if low in MATERIAL_ALIASES:
        return MATERIAL_ALIASES[low]
    for alias, canon in MATERIAL_ALIASES.items():
        if alias in low:
            return canon
    for canon in CANONICAL_MATERIALS:
        if canon in low:
            return canon
    if len(low) <= 25 and not any(w in low for w in ("look", "garment", "outfit", "style", "wearing", "uncertain")):
        return low
    return None


def normalize_fit(fit: Optional[str]) -> Optional[str]:
    """
    Normalizes a garment fit descriptor (e.g. 'slim', 'relaxed', 'oversized').
    Rejects full sentence descriptions, extracting only valid concise descriptors if present.
    """
    s = _clean_str(fit)
    if not s:
        return None
    low = s.lower()
    if low in CANONICAL_FITS:
        return low
    if low in FIT_ALIASES:
        return FIT_ALIASES[low]
    for alias, canon in FIT_ALIASES.items():
        if re.search(rf"\b{re.escape(alias)}\b", low):
            return canon
    for canon in CANONICAL_FITS:
        if re.search(rf"\b{re.escape(canon)}\b", low):
            return canon
    return None


def normalize_season(season: Optional[str]) -> Optional[str]:
    """Normalizes season descriptor."""
    s = _clean_str(season)
    if not s:
        return None
    low = s.lower()
    if low in CANONICAL_SEASONS:
        return low
    if low in SEASON_ALIASES:
        return SEASON_ALIASES[low]
    for alias, canon in SEASON_ALIASES.items():
        if alias in low:
            return canon
    for canon in CANONICAL_SEASONS:
        if canon in low:
            return canon
    return None


def normalize_formality(formality: Optional[str]) -> Optional[str]:
    """Normalizes formality descriptor."""
    s = _clean_str(formality)
    if not s:
        return None
    low = s.lower()
    if low in CANONICAL_FORMALITIES:
        return low
    if low in FORMALITY_ALIASES:
        return FORMALITY_ALIASES[low]
    for alias, canon in FORMALITY_ALIASES.items():
        if alias in low:
            return canon
    for canon in CANONICAL_FORMALITIES:
        if canon in low:
            return canon
    return None


def normalize_garment_metadata(
    category: Optional[str] = None,
    primary_color: Optional[str] = None,
    secondary_color: Optional[str] = None,
    pattern: Optional[str] = None,
    material: Optional[str] = None,
    fit: Optional[str] = None,
    season: Optional[str] = None,
    formality: Optional[str] = None,
    name: Optional[str] = None,
    sub_category: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Batch normalizes all structured garment attributes and returns a cleaned dictionary.
    """
    clean_cat = normalize_category(category)
    clean_primary = normalize_color(primary_color, default_neutral=True)
    clean_secondary = normalize_color(secondary_color, default_neutral=False)

    # Don't keep secondary color if identical to primary color
    if clean_secondary and clean_primary and clean_secondary == clean_primary:
        clean_secondary = None

    clean_pattern = normalize_pattern(pattern)
    clean_material = normalize_material(material)
    clean_fit = normalize_fit(fit)
    clean_season = normalize_season(season)
    clean_formality = normalize_formality(formality)

    clean_name = _clean_str(name) or "Wardrobe Item"
    clean_sub_category = _clean_str(sub_category)

    return {
        "category": clean_cat,
        "primary_color": clean_primary,
        "secondary_color": clean_secondary,
        "pattern": clean_pattern,
        "material": clean_material,
        "fit": clean_fit,
        "season": clean_season,
        "formality": clean_formality,
        "name": clean_name,
        "sub_category": clean_sub_category,
    }

