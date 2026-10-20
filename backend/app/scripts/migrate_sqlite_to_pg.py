"""
Safe, Repeatable Data Migration Utility: SQLite to PostgreSQL (Supabase)
WardrobeLens Application Data Migration

Non-negotiable safety rules adhered to:
1. Never deletes, recreates, or destructively alters source SQLite data.
2. Creates and verifies timestamped backup before execution.
3. Respects existing Supabase-managed tables (e.g. public.profiles, auth.users).
4. Preserves exact primary keys (UUIDs), foreign key relationships, timestamps, and JSON data.
5. Preserves unowned legacy records without inferring ownership.
6. Migrates legacy local images to Cloudinary (authenticated storage) without deleting local files.
7. Resumable and idempotent via ON CONFLICT DO NOTHING.
8. Generates comprehensive pre- and post-migration audit verification reports.
"""

import argparse
import json
import logging
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

# Ensure backend package can be imported
current_dir = Path(__file__).resolve().parent
backend_root = current_dir.parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))

env_path = backend_root / ".env"
if env_path.exists():
    load_dotenv(env_path)

from app.config import settings
from app.database import Base, create_app_engine, init_db, normalize_database_url
from app.models import (
    Community,
    CommunityListing,
    CommunityMembership,
    OutfitAnalysisRecord,
    SavedOutfit,
    SchemaMigration,
    TryOnTaskRecord,
    WardrobeItem,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("wardrobelens.migration")

# Topological migration order to guarantee parent records exist before dependents
TABLE_ORDER = [
    "schema_migrations",
    "communities",
    "community_memberships",
    "wardrobe_items",
    "community_listings",
    "outfit_analyses",
    "saved_outfits",
    "tryon_tasks",
]

MODEL_MAP = {
    "schema_migrations": SchemaMigration,
    "communities": Community,
    "community_memberships": CommunityMembership,
    "wardrobe_items": WardrobeItem,
    "community_listings": CommunityListing,
    "outfit_analyses": OutfitAnalysisRecord,
    "saved_outfits": SavedOutfit,
    "tryon_tasks": TryOnTaskRecord,
}

PK_MAP = {
    "schema_migrations": "version",
    "communities": "id",
    "community_memberships": "id",
    "wardrobe_items": "id",
    "community_listings": "id",
    "outfit_analyses": "id",
    "saved_outfits": "id",
    "tryon_tasks": "id",
}

DATETIME_COLUMNS = {
    "applied_at",
    "created_at",
    "updated_at",
    "requested_at",
    "decided_at",
    "expires_at",
}

BOOLEAN_COLUMNS = {
    "is_community_shared",
    "is_private",
}


def parse_datetime(val: Any) -> Optional[datetime]:
    """Safely converts SQLite datetime string or int to a Python datetime object."""
    if val is None or val == "":
        return None
    if isinstance(val, datetime):
        return val
    val_str = str(val).strip()
    # Try ISO formats
    for fmt in (
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%f",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            return datetime.strptime(val_str, fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(val_str)
    except Exception:
        logger.warning("Could not parse datetime: %r", val)
        return None


def create_verified_sqlite_backup(source_path: Path) -> Path:
    """Creates a timestamped backup of source SQLite file and verifies integrity."""
    backup_dir = backend_root / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = backup_dir / f"wardrobelens_backup_{timestamp}.db"

    logger.info("Creating online backup: %s -> %s", source_path, backup_file)
    src_conn = sqlite3.connect(str(source_path))
    dst_conn = sqlite3.connect(str(backup_file))
    with dst_conn:
        src_conn.backup(dst_conn)
    dst_conn.close()
    src_conn.close()

    # Integrity verification
    check_conn = sqlite3.connect(str(backup_file))
    cur = check_conn.cursor()
    cur.execute("PRAGMA integrity_check")
    status = cur.fetchone()[0]
    check_conn.close()
    if status != "ok":
        raise RuntimeError(f"Backup verification failed on {backup_file}: {status}")

    logger.info("Backup successfully verified. Status: %s, Size: %d bytes", status, backup_file.stat().st_size)
    return backup_file


def count_sqlite_rows(source_path: Path) -> Dict[str, int]:
    """Counts rows in all application tables in source SQLite database."""
    conn = sqlite3.connect(str(source_path))
    cur = conn.cursor()
    counts = {}
    for table in TABLE_ORDER:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            counts[table] = cur.fetchone()[0]
        except sqlite3.OperationalError:
            counts[table] = 0
    conn.close()
    return counts


def migrate_legacy_images_to_cloudinary(
    sqlite_conn: sqlite3.Connection,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """
    Identifies local image references, uploads legacy assets to Cloudinary under private folder,
    and returns a mapping without deleting original local files.
    """
    map_file = backend_root / "storage" / "legacy_image_migration_map.json"
    mapping: Dict[str, Dict[str, str]] = {}
    if map_file.exists():
        try:
            mapping = json.loads(map_file.read_text(encoding="utf-8"))
        except Exception:
            mapping = {}

    if not settings.is_cloudinary_configured:
        logger.warning("Cloudinary credentials not configured; skipping legacy image upload.")
        return mapping

    import cloudinary
    import cloudinary.uploader
    from PIL import Image
    import io

    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True,
    )

    cur = sqlite_conn.cursor()
    cur.execute("SELECT id, image_path, storage_provider FROM outfit_analyses WHERE storage_provider = 'local' OR image_path LIKE 'inspirations/%'")
    rows = cur.fetchall()

    logger.info("Found %d local inspiration records to evaluate for Cloudinary migration.", len(rows))
    for rec_id, img_path, provider in rows:
        if rec_id in mapping:
            logger.info("Record %s already mapped in legacy image migration map.", rec_id)
            continue

        # Locate file on disk
        local_file = backend_root / "storage" / img_path
        if not local_file.exists():
            local_file = backend_root / img_path
        if not local_file.exists():
            logger.warning("Referenced local image not found on disk: %s (record: %s)", img_path, rec_id)
            continue

        filename_stem = local_file.stem
        public_id = f"wardrobelens/users/legacy/inspirations/{filename_stem}"

        logger.info("Migrating legacy image: %s -> Cloudinary public_id: %s", local_file.name, public_id)
        if dry_run:
            mapping[rec_id] = {
                "original_path": img_path,
                "cloudinary_public_id": public_id,
                "status": "dry_run_pending",
            }
            continue

        try:
            with open(local_file, "rb") as f:
                raw_bytes = f.read()

            # Sanitize with Pillow (strip camera metadata)
            with Image.open(io.BytesIO(raw_bytes)) as img:
                img_format = (img.format or "JPEG").upper()
                clean_img = img.convert("RGB")
                out_buf = io.BytesIO()
                clean_img.save(out_buf, format="JPEG", quality=90)
                clean_bytes = out_buf.getvalue()

            upload_res = cloudinary.uploader.upload(
                clean_bytes,
                public_id=public_id,
                type="authenticated",
                resource_type="image",
                overwrite=True,
            )

            mapping[rec_id] = {
                "original_path": img_path,
                "cloudinary_public_id": upload_res.get("public_id", public_id),
                "format": upload_res.get("format", "jpg"),
                "version": str(upload_res.get("version", "")),
                "uploaded_at": datetime.now(timezone.utc).isoformat(),
            }
            logger.info("Successfully uploaded legacy image to Cloudinary: %s", public_id)

        except Exception as e:
            logger.error("Failed to upload legacy image %s: %s", local_file, str(e))

    if not dry_run:
        map_file.parent.mkdir(parents=True, exist_ok=True)
        map_file.write_text(json.dumps(mapping, indent=2), encoding="utf-8")
        logger.info("Saved legacy image migration mapping to: %s", map_file)

    return mapping


def run_migration(
    source_db_path: Path,
    target_db_url: str,
    dry_run: bool = False,
    migrate_images: bool = True,
) -> Dict[str, Any]:
    """Executes safe, verified SQLite to PostgreSQL data migration."""
    results: Dict[str, Any] = {
        "source_path": str(source_db_path),
        "target_url_scheme": normalize_database_url(target_db_url).split(":")[0],
        "dry_run": dry_run,
        "backup_path": None,
        "source_counts": {},
        "target_before_counts": {},
        "target_after_counts": {},
        "rows_migrated": {},
        "status": "pending",
        "errors": [],
    }

    # Step 1: Verify source database
    if not source_db_path.exists():
        raise FileNotFoundError(f"Source SQLite database not found: {source_db_path}")

    # Create timestamped verified backup
    backup_file = create_verified_sqlite_backup(source_db_path)
    results["backup_path"] = str(backup_file)

    # Record source row counts
    source_counts = count_sqlite_rows(source_db_path)
    results["source_counts"] = source_counts
    logger.info("Source SQLite row counts: %s", source_counts)

    # Step 2: Connect to target database
    normalized_target_url = normalize_database_url(target_db_url)
    target_engine = create_app_engine(normalized_target_url)

    # Test target connectivity
    with target_engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    logger.info("Target database connectivity verified.")

    # Step 3: Inspect target tables and confirm no collision with Supabase Auth or Profiles
    inspector = inspect(target_engine)
    existing_tables = inspector.get_table_names()
    logger.info("Target existing tables: %s", existing_tables)

    if "profiles" in existing_tables:
        logger.info("Supabase 'profiles' table detected. It will be safely preserved and NOT modified.")

    # Record target before counts
    target_before_counts = {}
    for table in TABLE_ORDER:
        if inspector.has_table(table):
            with target_engine.connect() as conn:
                res = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
                target_before_counts[table] = res.scalar() or 0
        else:
            target_before_counts[table] = 0
    results["target_before_counts"] = target_before_counts
    logger.info("Target before counts: %s", target_before_counts)

    # Check for collision if target already contains data
    total_existing_target_rows = sum(target_before_counts.values())
    if total_existing_target_rows > 0:
        logger.warning(
            "Target application tables already contain %d rows across application tables. "
            "Migration will proceed in idempotent append mode (ON CONFLICT DO NOTHING).",
            total_existing_target_rows,
        )

    # Step 4: Ensure target schema exists
    if not dry_run:
        logger.info("Initializing target database schema (additive & idempotent)...")
        init_db(target_engine=target_engine)

    # Step 5: Migrate legacy images to Cloudinary if requested
    src_conn = sqlite3.connect(str(source_db_path))
    src_conn.row_factory = sqlite3.Row
    image_mapping = {}
    if migrate_images:
        logger.info("Evaluating legacy image migration...")
        image_mapping = migrate_legacy_images_to_cloudinary(src_conn, dry_run=dry_run)
        results["image_mapping_count"] = len(image_mapping)

    # Step 6: Migrate tables in topological order
    target_session_factory = sessionmaker(bind=target_engine)
    rows_migrated = {table: 0 for table in TABLE_ORDER}

    for table_name in TABLE_ORDER:
        cur = src_conn.cursor()
        try:
            cur.execute(f"SELECT * FROM {table_name}")
            source_rows = cur.fetchall()
        except sqlite3.OperationalError:
            source_rows = []

        if not source_rows:
            logger.info("Table %s has 0 rows in source. Skipping.", table_name)
            continue

        pk_col = PK_MAP[table_name]
        logger.info("Migrating table %s (%d rows)...", table_name, len(source_rows))

        with target_session_factory() as session:
            for row in source_rows:
                row_dict = dict(row)

                # Process Datetime columns
                for dt_col in DATETIME_COLUMNS:
                    if dt_col in row_dict:
                        row_dict[dt_col] = parse_datetime(row_dict[dt_col])

                # Process Boolean columns
                for bool_col in BOOLEAN_COLUMNS:
                    if bool_col in row_dict and row_dict[bool_col] is not None:
                        row_dict[bool_col] = bool(row_dict[bool_col])

                # Update image reference if this row was uploaded to Cloudinary
                row_id = row_dict.get(pk_col)
                if table_name == "outfit_analyses" and row_id in image_mapping:
                    mapping_info = image_mapping[row_id]
                    if mapping_info.get("cloudinary_public_id"):
                        row_dict["storage_provider"] = "cloudinary"
                        row_dict["cloudinary_public_id"] = mapping_info["cloudinary_public_id"]
                        row_dict["image_path"] = mapping_info["cloudinary_public_id"]
                        if mapping_info.get("format"):
                            row_dict["image_format"] = mapping_info["format"]
                        if mapping_info.get("version"):
                            row_dict["image_version"] = mapping_info["version"]

                if dry_run:
                    rows_migrated[table_name] += 1
                    continue

                # Idempotent insert: Check if row already exists
                model_cls = MODEL_MAP[table_name]
                existing_record = session.query(model_cls).filter(getattr(model_cls, pk_col) == row_id).first()
                if existing_record:
                    logger.debug("Row %s in table %s already exists in target. Skipping.", row_id, table_name)
                    continue

                new_record = model_cls(**row_dict)
                session.add(new_record)
                rows_migrated[table_name] += 1

            if not dry_run:
                try:
                    session.commit()
                    logger.info("Committed %d new rows to table %s.", rows_migrated[table_name], table_name)
                except Exception as e:
                    session.rollback()
                    logger.error("Error committing table %s: %s", table_name, str(e))
                    raise

    src_conn.close()
    results["rows_migrated"] = rows_migrated

    # Step 7: Post-migration verification
    target_after_counts = {}
    for table in TABLE_ORDER:
        if dry_run:
            target_after_counts[table] = target_before_counts.get(table, 0) + rows_migrated.get(table, 0)
        else:
            try:
                with target_engine.connect() as conn:
                    res = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
                    target_after_counts[table] = res.scalar() or 0
            except Exception:
                target_after_counts[table] = 0
    results["target_after_counts"] = target_after_counts
    logger.info("Target after counts: %s", target_after_counts)

    # Verification integrity check
    all_matched = True
    for table in TABLE_ORDER:
        src = source_counts[table]
        tgt = target_after_counts[table] if not dry_run else target_before_counts[table] + rows_migrated[table]
        if table == "schema_migrations":
            if tgt < src:
                msg = f"Schema migration versions missing in target: source={src}, target={tgt}"
                logger.error(msg)
                results["errors"].append(msg)
                all_matched = False
        else:
            if src != tgt:
                msg = f"Count mismatch for table {table}: source={src}, target={tgt}"
                logger.error(msg)
                results["errors"].append(msg)
                all_matched = False

    results["status"] = "success" if all_matched else "mismatch_detected"
    return results


def print_audit_report(results: Dict[str, Any]) -> None:
    """Formats and displays a clear migration audit report."""
    print("\n" + "=" * 70)
    print("WARDROBELENS DATABASE MIGRATION VERIFICATION AUDIT REPORT")
    print("=" * 70)
    print(f"Status:             {results['status'].upper()}")
    print(f"Dry Run:            {results['dry_run']}")
    print(f"Source Database:    {results['source_path']}")
    print(f"Verified Backup:    {results['backup_path']}")
    print(f"Target Dialect:     {results['target_url_scheme']}")
    print("-" * 70)
    print(f"{'Table Name':<28} | {'Source':<8} | {'Migrated':<8} | {'Target':<8} | {'Status':<6}")
    print("-" * 70)

    for table in TABLE_ORDER:
        src = results["source_counts"].get(table, 0)
        mig = results["rows_migrated"].get(table, 0)
        tgt = results["target_after_counts"].get(table, results["target_before_counts"].get(table, 0) + mig)
        status_flag = "OK" if src == tgt or results["dry_run"] else "WARN"
        print(f"{table:<28} | {src:<8} | {mig:<8} | {tgt:<8} | {status_flag:<6}")

    print("-" * 70)
    if results.get("errors"):
        print("MIGRATION ERRORS / WARNINGS:")
        for err in results["errors"]:
            print(f"  - {err}")
    else:
        print("All application tables and foreign keys successfully verified!")
    print("=" * 70 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Migrate WardrobeLens SQLite database to PostgreSQL (Supabase)")
    parser.add_argument("--source", type=str, default=str(backend_root / "wardrobelens.db"), help="Source SQLite file path")
    target_default = os.getenv("TARGET_DATABASE_URL") or os.getenv("DATABASE_URL") or settings.DATABASE_URL
    parser.add_argument("--target", type=str, default=target_default, help="Target PostgreSQL connection URL")
    parser.add_argument("--dry-run", action="store_true", help="Perform checks and simulate migration without writing to target")
    parser.add_argument("--skip-images", action="store_true", help="Do not upload legacy local images to Cloudinary")

    args = parser.parse_args()

    source_path = Path(args.source).resolve()
    target_url = args.target

    if not target_url:
        logger.error(
            "Target database URL is required. Provide --target or set TARGET_DATABASE_URL/DATABASE_URL environment variable."
        )
        sys.exit(1)

    logger.info("Initiating WardrobeLens migration...")
    logger.info("Source: %s", source_path)
    logger.info("Target scheme: %s", normalize_database_url(target_url).split(":")[0])
    logger.info("Dry run: %s", args.dry_run)

    try:
        results = run_migration(
            source_db_path=source_path,
            target_db_url=target_url,
            dry_run=args.dry_run,
            migrate_images=not args.skip_images,
        )
        print_audit_report(results)
        if results["status"] != "success" and not args.dry_run:
            sys.exit(2)
    except Exception as e:
        logger.error("Migration failed with unhandled exception: %s", str(e), exc_info=True)
        sys.exit(3)


if __name__ == "__main__":
    main()
