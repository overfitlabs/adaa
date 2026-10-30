import json
import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models import WardrobeItem, SavedOutfit, OutfitAnalysisRecord

logger = logging.getLogger("wardrobelens.demo_restore")

BASELINE_PROFILE = {
    "full_name": "Taylor Swift",
    "bio": "Curated capsule wardrobe showcasing minimalist tailoring, smart casual styling, and evening silhouettes.",
    "tops_size": "M",
    "bottoms_size": "32",
    "shoe_size": "9",
    "preferred_fit": "relaxed",
    "preferred_styles": json.dumps(["minimalist", "smart-casual", "classic"]),
    "show_profile_photo": True,
    "show_bio": True,
    "show_fit_preferences": True,
    "show_preferred_styles": True,
}

BASELINE_ITEMS = [
    {
        "name": "Navy Floral Print Tunic Top",
        "category": "tops",
        "sub_category": "Tunic",
        "primary_color": "Navy",
        "secondary_color": "Floral",
        "pattern": "Floral",
        "material": "Silk",
        "fit": "relaxed",
        "season": "Spring/Summer",
        "formality": "smart-casual",
        "brand": "Reformation",
        "size": "M",
        "condition": "like-new",
        "notes": "Lightweight silk tunic top with micro floral print.",
        "tags": ["silk", "floral", "spring", "smart-casual"],
        "image_path": "wardrobelens/users/ed3ef268-e524-41dd-9ff1-425b9e90d590/wardrobe/5e8b269589af4bd19680b003b433226c",
        "storage_provider": "cloudinary",
    },
    {
        "name": "Lime Green Square-Neck Short-Sleeved Top",
        "category": "tops",
        "sub_category": "Top",
        "primary_color": "Lime Green",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Cotton Rib",
        "fit": "regular",
        "season": "Summer",
        "formality": "casual",
        "brand": "COS",
        "size": "M",
        "condition": "good",
        "notes": "Statement square neckline short-sleeve knit top.",
        "tags": ["cotton", "knit", "summer", "vibrant"],
        "image_path": "wardrobelens/users/ed3ef268-e524-41dd-9ff1-425b9e90d590/wardrobe/a5df5e54ddb24ca6aaf074bed5e594ec",
        "storage_provider": "cloudinary",
    },
    {
        "name": "Crisp White Poplin Button-Down",
        "category": "tops",
        "sub_category": "Shirt",
        "primary_color": "White",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Organic Cotton",
        "fit": "tailored",
        "season": "All-season",
        "formality": "smart-casual",
        "brand": "Everlane",
        "size": "M",
        "condition": "like-new",
        "notes": "Essential crisp white button-down with pointed collar.",
        "tags": ["white-shirt", "classic", "workwear", "minimalist"],
        "image_path": "wardrobe/demo_white_shirt.jpg",
        "storage_provider": "local",
    },
    {
        "name": "Regular denim blue jeans",
        "category": "bottoms",
        "sub_category": "Jeans",
        "primary_color": "Dusty blue",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Denim",
        "fit": "straight",
        "season": "All-season",
        "formality": "casual",
        "brand": "Levi's",
        "size": "32",
        "condition": "good",
        "notes": "Classic mid-rise straight leg jeans in vintage wash.",
        "tags": ["denim", "jeans", "vintage-wash", "casual"],
        "image_path": "wardrobelens/users/ed3ef268-e524-41dd-9ff1-425b9e90d590/wardrobe/5891c302df6e47cd8e3abb3bd1c23429",
        "storage_provider": "cloudinary",
    },
    {
        "name": "High-Waisted Charcoal Pleated Trousers",
        "category": "bottoms",
        "sub_category": "Trousers",
        "primary_color": "Charcoal",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Wool Blend",
        "fit": "relaxed",
        "season": "Autumn/Winter",
        "formality": "formal",
        "brand": "Arket",
        "size": "32",
        "condition": "like-new",
        "notes": "Pleated wide-leg trousers with concealed hook closure.",
        "tags": ["trousers", "pleats", "tailoring", "formal"],
        "image_path": "wardrobe/demo_charcoal_trousers.jpg",
        "storage_provider": "local",
    },
    {
        "name": "Black Single-Breasted Tailored Blazer",
        "category": "outerwear",
        "sub_category": "Blazer",
        "primary_color": "Black",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Wool",
        "fit": "tailored",
        "season": "All-season",
        "formality": "smart-casual",
        "brand": "Theory",
        "size": "M",
        "condition": "like-new",
        "notes": "Timeless single-breasted blazer with structured shoulders.",
        "tags": ["blazer", "black", "tailoring", "capsule"],
        "image_path": "wardrobe/demo_black_blazer.jpg",
        "storage_provider": "local",
    },
    {
        "name": "Black Sleeveless Maxi Dress",
        "category": "other",
        "sub_category": "Dress",
        "primary_color": "Black",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Modal",
        "fit": "relaxed",
        "season": "Summer",
        "formality": "evening",
        "brand": "Aritzia",
        "size": "M",
        "condition": "good",
        "notes": "Effortless column maxi dress with side slit.",
        "tags": ["dress", "maxi", "evening", "minimalist"],
        "image_path": "wardrobelens/users/ed3ef268-e524-41dd-9ff1-425b9e90d590/wardrobe/0b931f06d19e400f8d830eb89866d7b7",
        "storage_provider": "cloudinary",
    },
    {
        "name": "oxidized mirror worked earing",
        "category": "accessories",
        "sub_category": "Jewelry",
        "primary_color": "Silver",
        "secondary_color": "Black",
        "pattern": "Ethnic",
        "material": "Silver Alloy",
        "fit": "standard",
        "season": "All-season",
        "formality": "festive",
        "brand": "Fabindia",
        "size": "OS",
        "condition": "like-new",
        "notes": "Statement oxidized silver mirror-work jhumka earrings.",
        "tags": ["jewelry", "ethnic", "festive", "statement"],
        "image_path": "wardrobelens/users/ed3ef268-e524-41dd-9ff1-425b9e90d590/wardrobe/72d7e8e6c5024a1dae24efe8915ef513",
        "storage_provider": "cloudinary",
    },
    {
        "name": "Structured Italian Leather Tote",
        "category": "accessories",
        "sub_category": "Bag",
        "primary_color": "Cognac",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Full-Grain Leather",
        "fit": "standard",
        "season": "All-season",
        "formality": "smart-casual",
        "brand": "Cuyana",
        "size": "OS",
        "condition": "like-new",
        "notes": "Classic structured work tote with gold-tone hardware.",
        "tags": ["bag", "leather", "workwear", "accessories"],
        "image_path": "wardrobe/demo_leather_tote.jpg",
        "storage_provider": "local",
    },
    {
        "name": "Classic White Leather Court Sneakers",
        "category": "footwear",
        "sub_category": "Sneakers",
        "primary_color": "White",
        "secondary_color": None,
        "pattern": "Solid",
        "material": "Calfskin Leather",
        "fit": "standard",
        "season": "All-season",
        "formality": "casual",
        "brand": "Veja",
        "size": "9",
        "condition": "good",
        "notes": "Low-top minimalist leather tennis sneakers with gum sole.",
        "tags": ["sneakers", "leather", "casual", "minimalist"],
        "image_path": "wardrobe/demo_white_sneakers.jpg",
        "storage_provider": "local",
    },
]

BASELINE_OUTFITS = [
    {
        "name": "Essential Clean Silhouette",
        "occasion": "Smart Casual / Dinner",
        "notes": "Black maxi dress styled with structured blazer and silver earrings.",
        "matched_item_names": [
            "Black Sleeveless Maxi Dress",
            "Black Single-Breasted Tailored Blazer",
            "oxidized mirror worked earing",
        ],
    },
    {
        "name": "Weekend Tailored Ease",
        "occasion": "Weekend / Coffee",
        "notes": "Crisp white button-down with regular denim jeans and leather sneakers.",
        "matched_item_names": [
            "Crisp White Poplin Button-Down",
            "Regular denim blue jeans",
            "Classic White Leather Court Sneakers",
        ],
    },
]


def restore_demo_baseline(
    db: Session,
    target_email: Optional[str] = None,
    target_user_id: Optional[str] = None,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """
    Safely and idempotently restores the curated showcase data for the shared demo account.
    
    Guarantees:
    - Never modifies or clears any other user's profile, items, or outfits.
    - Idempotent: repeated runs converge to the exact same baseline without duplicates.
    - Preserves existing Cloudinary IDs for canonical assets.
    - Safe for live demonstration without data leakage or credential exposure.
    """
    # 1. Resolve demo user
    user_id = target_user_id
    email = target_email

    if not user_id:
        lookup_emails = [email] if email else ["demo@adaa.app", "demo@adaa.style"]
        for le in lookup_emails:
            row = db.execute(
                text("SELECT id, email FROM profiles WHERE email = :email"),
                {"email": le},
            ).mappings().first()
            if row:
                user_id = str(row["id"])
                email = row["email"]
                break

    if not user_id:
        raise ValueError(
            "Demo user profile not found. Please specify target_user_id or valid demo email."
        )

    logger.info("Restoring demo baseline for user_id=%s (email=%s, dry_run=%s)", user_id, email, dry_run)

    report = {
        "status": "dry_run" if dry_run else "success",
        "target_user_id": user_id,
        "target_email": email,
        "profile_restored": False,
        "items_created": 0,
        "items_updated": 0,
        "items_removed": 0,
        "outfits_created": 0,
        "outfits_updated": 0,
        "outfits_removed": 0,
    }

    # 2. Restore Profile Baseline
    update_fields = ", ".join(f"{k} = :{k}" for k in BASELINE_PROFILE.keys())
    profile_sql = text(f"""
        UPDATE profiles
        SET {update_fields}, updated_at = CURRENT_TIMESTAMP
        WHERE id = :uid
    """)
    if not dry_run:
        db.execute(profile_sql, {**BASELINE_PROFILE, "uid": user_id})
    report["profile_restored"] = True

    # 3. Idempotently Reconcile Wardrobe Items
    existing_items = db.query(WardrobeItem).filter(WardrobeItem.user_id == user_id).all()
    existing_by_name = {it.name.strip().lower(): it for it in existing_items}
    baseline_names = {b["name"].strip().lower() for b in BASELINE_ITEMS}

    # Remove extra items created by visitors (strictly where user_id == user_id)
    for it in existing_items:
        if it.name.strip().lower() not in baseline_names:
            if not dry_run:
                db.delete(it)
            report["items_removed"] += 1

    # Insert or update baseline items
    current_item_map: Dict[str, WardrobeItem] = {}
    for b_item in BASELINE_ITEMS:
        key = b_item["name"].strip().lower()
        is_cloud = b_item["storage_provider"] == "cloudinary"
        tags_json = json.dumps(b_item.get("tags", []))

        if key in existing_by_name:
            it = existing_by_name[key]
            if not dry_run:
                it.category = b_item["category"]
                it.sub_category = b_item["sub_category"]
                it.primary_color = b_item["primary_color"]
                it.secondary_color = b_item["secondary_color"]
                it.pattern = b_item["pattern"]
                it.material = b_item["material"]
                it.fit = b_item["fit"]
                it.season = b_item["season"]
                it.formality = b_item["formality"]
                it.brand = b_item["brand"]
                it.size = b_item["size"]
                it.condition = b_item["condition"]
                it.notes = b_item["notes"]
                it.tags = tags_json
                it.storage_provider = b_item["storage_provider"]
                it.image_path = b_item["image_path"]
                if is_cloud:
                    it.cloudinary_public_id = b_item["image_path"]
            current_item_map[b_item["name"]] = it
            report["items_updated"] += 1
        else:
            new_item = WardrobeItem(
                user_id=user_id,
                name=b_item["name"],
                category=b_item["category"],
                sub_category=b_item["sub_category"],
                primary_color=b_item["primary_color"],
                secondary_color=b_item["secondary_color"],
                pattern=b_item["pattern"],
                material=b_item["material"],
                fit=b_item["fit"],
                season=b_item["season"],
                formality=b_item["formality"],
                brand=b_item["brand"],
                size=b_item["size"],
                condition=b_item["condition"],
                notes=b_item["notes"],
                tags=tags_json,
                image_path=b_item["image_path"],
                storage_provider=b_item["storage_provider"],
                cloudinary_public_id=b_item["image_path"] if is_cloud else None,
                is_community_shared=False,
            )
            if not dry_run:
                db.add(new_item)
                db.flush()
            current_item_map[b_item["name"]] = new_item
            report["items_created"] += 1

    # 4. Idempotently Reconcile Saved Outfits
    existing_outfits = db.query(SavedOutfit).filter(SavedOutfit.user_id == user_id).all()
    existing_outfits_by_name = {o.name.strip().lower(): o for o in existing_outfits}
    baseline_outfit_names = {b["name"].strip().lower() for b in BASELINE_OUTFITS}

    for o in existing_outfits:
        if o.name.strip().lower() not in baseline_outfit_names:
            if not dry_run:
                db.delete(o)
            report["outfits_removed"] += 1

    for b_outfit in BASELINE_OUTFITS:
        key = b_outfit["name"].strip().lower()
        matched_ids = [
            current_item_map[n].id
            for n in b_outfit["matched_item_names"]
            if n in current_item_map and hasattr(current_item_map[n], "id")
        ]
        items_json = json.dumps(matched_ids)

        if key in existing_outfits_by_name:
            outfit = existing_outfits_by_name[key]
            if not dry_run:
                outfit.occasion = b_outfit["occasion"]
                outfit.notes = b_outfit["notes"]
                outfit.item_ids_json = items_json
            report["outfits_updated"] += 1
        else:
            new_outfit = SavedOutfit(
                user_id=user_id,
                name=b_outfit["name"],
                occasion=b_outfit["occasion"],
                notes=b_outfit["notes"],
                item_ids_json=items_json,
            )
            if not dry_run:
                db.add(new_outfit)
            report["outfits_created"] += 1

    # 5. Clean up visitor-created scans for demo user
    if not dry_run:
        visitor_analyses = db.query(OutfitAnalysisRecord).filter(
            OutfitAnalysisRecord.user_id == user_id
        ).all()
        for v_scan in visitor_analyses:
            db.delete(v_scan)
        db.commit()

    logger.info("Demo restore complete: %s", report)
    return report
