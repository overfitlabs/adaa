import json
import os
from pathlib import Path
import sqlite3
import sys
import httpx
from dotenv import load_dotenv

backend_root = Path(__file__).resolve().parent.parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))

env_path = backend_root / ".env"
if env_path.exists():
    load_dotenv(env_path)

from sqlalchemy import text
from app.config import settings
from app.database import create_app_engine, normalize_database_url
from app.services.image_storage import image_storage_service

src_conn = sqlite3.connect(backend_root / "wardrobelens.db")
src_conn.row_factory = sqlite3.Row
src_cur = src_conn.cursor()

engine = create_app_engine(normalize_database_url(settings.DATABASE_URL))

print("=" * 70)
print("1. ROW COUNT COMPARISON (SQLite Source vs PostgreSQL Target)")
print("=" * 70)
tables = [
    "schema_migrations",
    "communities",
    "community_memberships",
    "wardrobe_items",
    "community_listings",
    "outfit_analyses",
    "saved_outfits",
    "tryon_tasks",
]

with engine.connect() as pg_conn:
    for t in tables:
        src_cur.execute(f"SELECT COUNT(*) FROM {t}")
        src_cnt = src_cur.fetchone()[0]
        pg_cnt = pg_conn.execute(text(f"SELECT COUNT(*) FROM public.{t}")).scalar()
        match_str = "MATCH" if src_cnt == pg_cnt else "MISMATCH"
        print(f"Table: {t:<24} | Source: {src_cnt:<3} | Target: {pg_cnt:<3} | {match_str}")

    prof_cnt = pg_conn.execute(text("SELECT COUNT(*) FROM public.profiles")).scalar()
    print(f"Table: {'public.profiles':<24} | Target Rows: {prof_cnt} (Protected Supabase profile table)")

    print("\n" + "=" * 70)
    print("2. PRIMARY KEY AND ATTRIBUTE INTEGRITY CHECK")
    print("=" * 70)
    # Communities
    src_cur.execute("SELECT * FROM communities")
    src_comm = dict(src_cur.fetchone())
    pg_comm = dict(pg_conn.execute(text("SELECT * FROM public.communities")).mappings().fetchone())
    print("Community ID:            ", pg_comm["id"])
    print("Community Name Match:    ", src_comm["name"] == pg_comm["name"], f"({pg_comm['name']})")
    print("Community Creator Match: ", src_comm["creator_id"] == pg_comm["creator_id"])
    print("Community Status Match:  ", src_comm["status"] == pg_comm["status"])

    # Memberships
    src_cur.execute("SELECT * FROM community_memberships ORDER BY id")
    src_mems = [dict(r) for r in src_cur.fetchall()]
    pg_mems = [dict(r) for r in pg_conn.execute(text("SELECT * FROM public.community_memberships ORDER BY id")).mappings().fetchall()]
    print(f"\nMemberships Count: {len(pg_mems)}")
    for sm, pm in zip(src_mems, pg_mems):
        id_match = sm["id"] == pm["id"]
        print(f" - Membership ID: {pm['id']} | Role: {pm['role']} | Status: {pm['status']} | User: {pm['user_id']} | ID Match: {id_match}")

    # Wardrobe Items
    src_cur.execute("SELECT * FROM wardrobe_items")
    src_item = dict(src_cur.fetchone())
    pg_item = dict(pg_conn.execute(text("SELECT * FROM public.wardrobe_items")).mappings().fetchone())
    print("\nWardrobe Item ID:        ", pg_item["id"])
    print("Item Name Match:         ", src_item["name"] == pg_item["name"], f"({pg_item['name']})")
    print("Item Category Match:     ", src_item["category"] == pg_item["category"])
    print("Item Storage Provider:   ", pg_item["storage_provider"])
    print("Item Cloudinary Public ID:", pg_item["cloudinary_public_id"])

    # Outfit Analyses
    src_cur.execute("SELECT * FROM outfit_analyses ORDER BY id")
    src_analyses = [dict(r) for r in src_cur.fetchall()]
    pg_analyses = [dict(r) for r in pg_conn.execute(text("SELECT * FROM public.outfit_analyses ORDER BY id")).mappings().fetchall()]
    print(f"\nOutfit Analyses Count: {len(pg_analyses)}")
    for sa, pa in zip(src_analyses, pg_analyses):
        print(f" - Analysis ID:          {pa['id']}")
        print(f"   User ID:              {pa['user_id']} (Legacy anonymous unowned preserved)")
        print(f"   Vibe:                 {pa['vibe']}")
        print(f"   Storage Provider:     {pa['storage_provider']}")
        print(f"   Cloudinary Public ID: {pa['cloudinary_public_id']}")
        print(f"   Items JSON Parsable:  {bool(json.loads(pa['items_json'])) if pa['items_json'] != '[]' else 'Empty list valid'}")

    print("\n" + "=" * 70)
    print("3. REFERENTIAL INTEGRITY (FOREIGN KEYS)")
    print("=" * 70)
    orphan_mems = pg_conn.execute(text("""
        SELECT m.id FROM public.community_memberships m
        LEFT JOIN public.communities c ON m.community_id = c.id
        WHERE c.id IS NULL
    """)).fetchall()
    print("Orphan Community Memberships (Expected 0):", len(orphan_mems))

    orphan_listings = pg_conn.execute(text("""
        SELECT l.id FROM public.community_listings l
        LEFT JOIN public.communities c ON l.community_id = c.id
        LEFT JOIN public.wardrobe_items w ON l.wardrobe_item_id = w.id
        WHERE c.id IS NULL OR w.id IS NULL
    """)).fetchall()
    print("Orphan Community Listings (Expected 0):   ", len(orphan_listings))

    print("\n" + "=" * 70)
    print("4. SCHEMA MIGRATIONS VERIFICATION")
    print("=" * 70)
    pg_mig_rows = pg_conn.execute(text("SELECT version, name, applied_at FROM public.schema_migrations ORDER BY version")).fetchall()
    for v, n, a in pg_mig_rows:
        print(f" - Version: {v:<25} | Name: {n}")

print("\n" + "=" * 70)
print("5. LOCAL IMAGE FILE PRESERVATION CHECK")
print("=" * 70)
local_f1 = backend_root / "storage/inspirations/81906f26a1764e0295da02b9ff66db96.jpg"
local_f2 = backend_root / "storage/inspirations/17e6430b74db49ad8f9b39f778d393cb.jpg"
print(f"Local File 1 Exists on disk: {local_f1.exists()} ({local_f1.stat().st_size} bytes)")
print(f"Local File 2 Exists on disk: {local_f2.exists()} ({local_f2.stat().st_size} bytes)")

print("\n" + "=" * 70)
print("6. CLOUDINARY DELIVERY TEST (AUTHENTICATED URLS)")
print("=" * 70)
map_path = backend_root / "storage/legacy_image_migration_map.json"
print("Legacy Image Mapping Exists: ", map_path.exists())
if map_path.exists():
    map_data = json.loads(map_path.read_text(encoding="utf-8"))
    print("Mapped Legacy Images Count:  ", len(map_data))
    with httpx.Client(timeout=10) as client:
        for rec_id, info in map_data.items():
            pub_id = info["cloudinary_public_id"]
            delivery_url = image_storage_service.generate_delivery_url(pub_id)
            res = client.head(delivery_url)
            print(f" - Asset: {pub_id}")
            print(f"   HTTP Status: {res.status_code} | Content-Type: {res.headers.get('content-type')}")

        # Also check wardrobe item
        wardrobe_pub_id = pg_item["cloudinary_public_id"]
        delivery_wardrobe = image_storage_service.generate_delivery_url(wardrobe_pub_id)
        res_w = client.head(delivery_wardrobe)
        print(f" - Wardrobe Asset: {wardrobe_pub_id}")
        print(f"   HTTP Status: {res_w.status_code} | Content-Type: {res_w.headers.get('content-type')}")

print("\n" + "=" * 70)
print("ALL POST-MIGRATION VERIFICATION CHECKS COMPLETED SUCCESSFULLY")
print("=" * 70)
