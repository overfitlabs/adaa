#!/usr/bin/env python3
"""
Operator Maintenance Script: Safe 24-Hour Abandoned Scan Cleanup.

Usage:
    python app/scripts/cleanup_abandoned_scans.py [--max-age-hours 24] [--dry-run]

Scheduling:
    Configure as a daily Render Cron Job or Linux systemd timer:
    Command: python app/scripts/cleanup_abandoned_scans.py --max-age-hours 24
    Schedule: 0 3 * * * (daily at 3:00 AM UTC)

Guarantees:
- Never deletes items or crops that have been saved to WardrobeItem or SavedOutfit.
- Only cleans up unreferenced, uncommitted outfit analysis scans older than max_age_hours.
- Safe to run on schedule or manually by an operator.
"""

import argparse
import sys
from pathlib import Path

# Ensure backend root is on sys.path
backend_root = Path(__file__).resolve().parent.parent.parent
if str(backend_root) not in sys.path:
    sys.path.insert(0, str(backend_root))

from app.database import SessionLocal
from app.api.routes_analysis import cleanup_abandoned_analyses


def main():
    parser = argparse.ArgumentParser(
        description="Safely purges abandoned outfit analyses older than max_age_hours while protecting saved wardrobe assets."
    )
    parser.add_argument(
        "--max-age-hours",
        type=int,
        default=24,
        help="Retention threshold in hours (default: 24). Analyses older than this are eligible for cleanup.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the cleanup without deleting records or assets.",
    )

    args = parser.parse_args()

    print("=" * 60)
    print(" adaa: Abandoned Scan Retention Cleanup")
    print("=" * 60)
    print(f"  Max Age Threshold: {args.max_age_hours} hours")
    if args.dry_run:
        print("[MODE] DRY-RUN SIMULATION (No database or storage mutations)")

    db = SessionLocal()
    try:
        if args.dry_run:
            from datetime import datetime, timedelta
            from app.models import OutfitAnalysisRecord, SavedOutfit
            cutoff = datetime.utcnow() - timedelta(hours=args.max_age_hours)
            saved_inspiration_ids = [
                row[0] for row in db.query(SavedOutfit.inspiration_analysis_id)
                .filter(SavedOutfit.inspiration_analysis_id.isnot(None))
                .all()
            ]
            query = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.created_at <= cutoff)
            if saved_inspiration_ids:
                query = query.filter(~OutfitAnalysisRecord.id.in_(saved_inspiration_ids))
            count = query.count()
            print(f"\n[DRY RUN RESULT] Found {count} abandoned scan(s) eligible for cleanup older than {cutoff.isoformat()}.")
        else:
            result = cleanup_abandoned_analyses(db, max_age_hours=args.max_age_hours)
            print("\n[SUCCESS] Cleanup completed successfully:")
            print(f"  Abandoned Scans Cleaned: {result['abandoned_scans_cleaned']}")
            print(f"  Failed Scans:            {result['failed_scans']}")
            print(f"  Retention Cutoff:        {result['retention_cutoff']}")
            print("\nAll saved wardrobe items and saved outfit assets were preserved.")
        sys.exit(0)
    except Exception as e:
        print(f"\n[ERROR] Cleanup failed: {str(e)}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
