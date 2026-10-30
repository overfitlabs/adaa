#!/usr/bin/env python3
"""
Operator Maintenance Script: Safe Demo Account Baseline Restore.

Usage:
    python app/scripts/restore_demo_baseline.py [--dry-run] [--email demo@adaa.app]

Security & Architecture:
- Scoped strictly to the target demo account (user_id).
- NEVER alters or clears any real users' data, wardrobe items, or profiles.
- Idempotent: repeated runs converge to the same 10-piece baseline without duplicate rows.
- No secrets, credentials, or tokens are printed or required beyond standard backend env.
"""

import argparse
import sys
import json
from pathlib import Path

# Ensure backend root is on sys.path
backend_root = Path(__file__).resolve().parent.parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))

from app.database import SessionLocal
from app.services.demo_restore_service import restore_demo_baseline


def main():
    parser = argparse.ArgumentParser(
        description="Safely and idempotently restores the curated showcase data for the shared demo account."
    )
    parser.add_argument(
        "--email",
        type=str,
        default=None,
        help="Target demo account email (defaults to demo@adaa.app or demo@adaa.style).",
    )
    parser.add_argument(
        "--user-id",
        type=str,
        default=None,
        help="Explicit user UUID of the demo account.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the restoration without committing changes to the database.",
    )

    args = parser.parse_args()

    print("=" * 60)
    print(" adaa: Shared Demo Account Baseline Restore")
    print("=" * 60)
    if args.dry_run:
        print("[MODE] DRY-RUN SIMULATION (No database writes will occur)")

    db = SessionLocal()
    try:
        report = restore_demo_baseline(
            db,
            target_email=args.email,
            target_user_id=args.user_id,
            dry_run=args.dry_run,
        )
        print("\n[SUCCESS] Restoration completed successfully:")
        print(f"  Target User ID:   {report['target_user_id']}")
        print(f"  Target Email:     {report['target_email']}")
        print(f"  Profile Restored: {report['profile_restored']}")
        print(f"  Wardrobe Items:   {report['items_created']} created, {report['items_updated']} updated, {report['items_removed']} removed")
        print(f"  Curated Outfits:  {report['outfits_created']} created, {report['outfits_updated']} updated, {report['outfits_removed']} removed")
        print("\nAll real users and non-demo assets were preserved without modification.")
        sys.exit(0)
    except Exception as e:
        print(f"\n[ERROR] Demo baseline restore failed: {str(e)}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
