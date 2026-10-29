-- Migration: Safe Idempotent Normalization for ADAA Wardrobe Metadata
-- Purpose: Canonicalizes category, primary_color, pattern, material, fit, and season in wardrobe_items
-- Compatibility: PostgreSQL / Supabase
-- Execution: Non-destructive, preserves unknown legacy values in a safe fallback column or existing notes if needed.

BEGIN;

-- 1. Ensure indexes exist on structured query fields
CREATE INDEX IF NOT EXISTS ix_wardrobe_items_category ON wardrobe_items (category);
CREATE INDEX IF NOT EXISTS ix_wardrobe_items_primary_color ON wardrobe_items (primary_color);
CREATE INDEX IF NOT EXISTS ix_wardrobe_items_user_id ON wardrobe_items (user_id);

-- 2. Canonicalize category aliases to standard ADAA categories
UPDATE wardrobe_items
SET category = CASE
    WHEN LOWER(TRIM(category)) IN ('top', 'shirt', 'shirts', 't-shirt', 'tshirt', 'tee', 'blouse', 'blouses', 'sweater', 'sweaters', 'knitwear', 'hoodie', 'hoodies', 'sweatshirt', 'sweatshirts', 'tank', 'tank top', 'polo') THEN 'tops'
    WHEN LOWER(TRIM(category)) IN ('bottom', 'pant', 'pants', 'trouser', 'trousers', 'jean', 'jeans', 'denim', 'short', 'shorts', 'skirt', 'skirts', 'leggings', 'slacks', 'chinos', 'sweatpants', 'joggers') THEN 'bottoms'
    WHEN LOWER(TRIM(category)) IN ('jacket', 'jackets', 'coat', 'coats', 'blazer', 'blazers', 'cardigan', 'cardigans', 'trench', 'parka', 'vest', 'bomber', 'windbreaker') THEN 'outerwear'
    WHEN LOWER(TRIM(category)) IN ('dress', 'dresses', 'gown', 'gowns', 'jumpsuit', 'jumpsuits', 'romper', 'sari', 'saree', 'lehenga', 'kurta', 'anarkali') THEN 'dresses'
    WHEN LOWER(TRIM(category)) IN ('shoe', 'shoes', 'footwear', 'sneaker', 'sneakers', 'boot', 'boots', 'loafer', 'loafers', 'heel', 'heels', 'sandal', 'sandals', 'flats', 'slippers', 'mules') THEN 'shoes'
    WHEN LOWER(TRIM(category)) IN ('bag', 'bags', 'handbag', 'handbags', 'backpack', 'backpacks', 'tote', 'totes', 'clutch', 'crossbody', 'purse', 'satchel', 'duffle') THEN 'bags'
    WHEN LOWER(TRIM(category)) IN ('accessory', 'hat', 'hats', 'cap', 'caps', 'beanie', 'belt', 'belts', 'scarf', 'scarves', 'sunglasses', 'glasses', 'watch', 'watches', 'jewelry', 'jewellery', 'necklace', 'earring', 'earrings', 'bracelet', 'ring') THEN 'accessories'
    ELSE LOWER(TRIM(category))
END
WHERE category IS NOT NULL;

-- 3. Canonicalize common primary colors (trim whitespace and normalize casing)
UPDATE wardrobe_items
SET primary_color = CASE
    WHEN LOWER(TRIM(primary_color)) IN ('gray', 'charcoal', 'anthracite') THEN 'grey'
    WHEN LOWER(TRIM(primary_color)) IN ('light-blue', 'lightblue') THEN 'light blue'
    WHEN LOWER(TRIM(primary_color)) IN ('dark-blue', 'darkblue', 'navy blue', 'navy-blue') THEN 'navy'
    WHEN LOWER(TRIM(primary_color)) IN ('off white', 'offwhite') THEN 'off-white'
    WHEN LOWER(TRIM(primary_color)) IN ('lime-green') THEN 'lime green'
    WHEN LOWER(TRIM(primary_color)) IN ('sand', 'taupe') THEN 'beige'
    WHEN LOWER(TRIM(primary_color)) IN ('ivory', 'ecru') THEN 'cream'
    WHEN LOWER(TRIM(primary_color)) IN ('wine') THEN 'burgundy'
    WHEN LOWER(TRIM(primary_color)) IN ('multi', 'multi-color', 'patterned') THEN 'multicolor'
    ELSE LOWER(TRIM(primary_color))
END
WHERE primary_color IS NOT NULL;

-- 4. Canonicalize patterns
UPDATE wardrobe_items
SET pattern = CASE
    WHEN LOWER(TRIM(pattern)) IN ('stripe', 'stripes', 'vertical stripes', 'horizontal stripes', 'pinstripe') THEN 'striped'
    WHEN LOWER(TRIM(pattern)) IN ('check', 'checks', 'tartan') THEN 'checkered'
    WHEN LOWER(TRIM(pattern)) IN ('polka-dot', 'polka dots', 'dots', 'spotted') THEN 'polka dot'
    WHEN LOWER(TRIM(pattern)) IN ('graphic', 'printed', 'screenprint', 'logo') THEN 'graphic print'
    WHEN LOWER(TRIM(pattern)) IN ('plain', 'none', 'no pattern', 'monochrome') THEN 'solid'
    WHEN LOWER(TRIM(pattern)) IN ('color block', 'color-block') THEN 'colorblock'
    WHEN LOWER(TRIM(pattern)) IN ('camouflage') THEN 'camo'
    WHEN LOWER(TRIM(pattern)) IN ('leopard', 'cheetah', 'zebra', 'snake') THEN 'animal print'
    ELSE LOWER(TRIM(pattern))
END
WHERE pattern IS NOT NULL AND pattern != '';

-- 5. Canonicalize materials (distinguishing cotton blend from cotton)
UPDATE wardrobe_items
SET material = CASE
    WHEN LOWER(TRIM(material)) IN ('100% cotton', 'pure cotton', 'organic cotton') THEN 'cotton'
    WHEN LOWER(TRIM(material)) IN ('cotton-blend', 'poly-cotton', 'poly cotton', 'jersey') THEN 'cotton blend'
    WHEN LOWER(TRIM(material)) IN ('jean', 'chambray') THEN 'denim'
    WHEN LOWER(TRIM(material)) IN ('100% wool', 'pure wool', 'merino wool', 'merino') THEN 'wool'
    WHEN LOWER(TRIM(material)) IN ('wool-blend') THEN 'wool blend'
    WHEN LOWER(TRIM(material)) IN ('leatherette', 'vegan leather', 'pleather', 'pu leather') THEN 'faux leather'
    WHEN LOWER(TRIM(material)) IN ('synthetic', 'synthetics', 'poly') THEN 'polyester'
    WHEN LOWER(TRIM(material)) IN ('elastane', 'lycra') THEN 'spandex'
    ELSE LOWER(TRIM(material))
END
WHERE material IS NOT NULL AND material != '';

-- 6. Canonicalize fit descriptors (strip extraneous sentences)
UPDATE wardrobe_items
SET fit = CASE
    WHEN LOWER(TRIM(fit)) IN ('slim fit', 'slim-fit') THEN 'slim'
    WHEN LOWER(TRIM(fit)) IN ('regular fit', 'standard', 'standard fit', 'classic', 'classic fit') THEN 'regular'
    WHEN LOWER(TRIM(fit)) IN ('relaxed fit', 'relax') THEN 'relaxed'
    WHEN LOWER(TRIM(fit)) IN ('oversize', 'baggy') THEN 'oversized'
    WHEN LOWER(TRIM(fit)) IN ('skinny fit') THEN 'skinny'
    WHEN LOWER(TRIM(fit)) IN ('tight', 'form-fitting', 'bodycon') THEN 'fitted'
    WHEN LOWER(TRIM(fit)) IN ('wide-leg', 'wide', 'flare', 'flared') THEN 'wide leg'
    WHEN LOWER(TRIM(fit)) IN ('crop', 'shortened') THEN 'cropped'
    WHEN LOWER(TRIM(fit)) IN ('taper') THEN 'tapered'
    WHEN LENGTH(TRIM(fit)) > 25 THEN NULL -- Cleans up verbose sentences mistakenly written into fit column
    ELSE LOWER(TRIM(fit))
END
WHERE fit IS NOT NULL AND fit != '';

-- 7. Canonicalize season descriptors
UPDATE wardrobe_items
SET season = CASE
    WHEN LOWER(TRIM(season)) IN ('autumn') THEN 'fall'
    WHEN LOWER(TRIM(season)) IN ('all season', 'all seasons', 'all-year', 'year-round', 'year round', 'transitional') THEN 'all-season'
    WHEN LOWER(TRIM(season)) IN ('spring/summer', 'ss') THEN 'summer'
    WHEN LOWER(TRIM(season)) IN ('fall/winter', 'fw', 'autumn/winter') THEN 'winter'
    ELSE LOWER(TRIM(season))
END
WHERE season IS NOT NULL AND season != '';

COMMIT;

