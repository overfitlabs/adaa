import json
import pytest
from sqlalchemy import text
from app.models import WardrobeItem, SavedOutfit
from app.services.demo_restore_service import restore_demo_baseline, BASELINE_ITEMS, BASELINE_PROFILE


def test_demo_baseline_restore_lifecycle_and_idempotence(db_session):
    demo_uid = "isolated-demo-user-123"
    real_uid = "real-user-456"

    # 1. Create profiles table and isolated test profiles
    db_session.execute(text("""
        CREATE TABLE IF NOT EXISTS profiles (
            id VARCHAR(36) PRIMARY KEY,
            email TEXT,
            full_name TEXT,
            avatar_url TEXT,
            bio TEXT,
            age INTEGER,
            phone_number TEXT,
            tops_size VARCHAR(30),
            bottoms_size VARCHAR(30),
            shoe_size VARCHAR(30),
            preferred_fit VARCHAR(30),
            preferred_styles TEXT DEFAULT '[]',
            show_profile_photo BOOLEAN NOT NULL DEFAULT 1,
            show_bio BOOLEAN NOT NULL DEFAULT 1,
            show_age BOOLEAN NOT NULL DEFAULT 0,
            show_phone BOOLEAN NOT NULL DEFAULT 0,
            show_email BOOLEAN NOT NULL DEFAULT 0,
            show_fit_preferences BOOLEAN NOT NULL DEFAULT 0,
            show_preferred_styles BOOLEAN NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """))

    # Demo user with visitor-mutated sizing
    db_session.execute(text("""
        INSERT INTO profiles (id, email, full_name, tops_size, bottoms_size, preferred_fit)
        VALUES (:id, 'demo@adaa.test', 'Modified Visitor Name', 'XXL', '44', 'oversized')
    """), {"id": demo_uid})

    # Real user who must NEVER be touched
    db_session.execute(text("""
        INSERT INTO profiles (id, email, full_name, tops_size, bottoms_size, preferred_fit)
        VALUES (:id, 'realuser@adaa.test', 'Real Person', 'S', '28', 'slim')
    """), {"id": real_uid})

    # Add real user's private wardrobe item
    real_item = WardrobeItem(
        id="real-item-999",
        user_id=real_uid,
        name="Real User Private Silk Dress",
        category="other",
        primary_color="Red",
        image_path="wardrobe/real_user_dress.jpg",
    )
    db_session.add(real_item)

    # Add visitor's junk item on demo user
    visitor_junk_item = WardrobeItem(
        id="demo-junk-item-001",
        user_id=demo_uid,
        name="Visitor Test Spam Item",
        category="tops",
        primary_color="Neon",
        image_path="wardrobe/junk.jpg",
    )
    db_session.add(visitor_junk_item)
    db_session.commit()

    # 2. Test Dry Run first
    dry_report = restore_demo_baseline(db_session, target_user_id=demo_uid, dry_run=True)
    assert dry_report["status"] == "dry_run"
    assert dry_report["items_created"] == len(BASELINE_ITEMS)
    assert dry_report["items_removed"] == 1  # The visitor junk item

    # Verify dry run did NOT touch database
    prof = db_session.execute(text("SELECT tops_size FROM profiles WHERE id = :id"), {"id": demo_uid}).mappings().first()
    assert prof["tops_size"] == "XXL"
    assert db_session.query(WardrobeItem).filter(WardrobeItem.id == "demo-junk-item-001").first() is not None

    # 3. Execute Real Baseline Restore
    report1 = restore_demo_baseline(db_session, target_user_id=demo_uid, dry_run=False)
    assert report1["status"] == "success"
    assert report1["profile_restored"] is True
    assert report1["items_created"] == len(BASELINE_ITEMS)
    assert report1["items_removed"] == 1

    # Verify demo profile sizing restored to baseline
    prof_restored = db_session.execute(text("SELECT full_name, tops_size, bottoms_size, preferred_fit FROM profiles WHERE id = :id"), {"id": demo_uid}).mappings().first()
    assert prof_restored["full_name"] == BASELINE_PROFILE["full_name"]
    assert prof_restored["tops_size"] == "M"
    assert prof_restored["bottoms_size"] == "32"
    assert prof_restored["preferred_fit"] == "relaxed"

    # Verify junk item is gone and exactly 10 baseline items exist for demo user
    demo_items = db_session.query(WardrobeItem).filter(WardrobeItem.user_id == demo_uid).all()
    assert len(demo_items) == len(BASELINE_ITEMS)
    assert not any(it.name == "Visitor Test Spam Item" for it in demo_items)

    # 4. Verify Real User was 100% untouched
    real_prof = db_session.execute(text("SELECT full_name, tops_size FROM profiles WHERE id = :id"), {"id": real_uid}).mappings().first()
    assert real_prof["full_name"] == "Real Person"
    assert real_prof["tops_size"] == "S"
    real_item_check = db_session.query(WardrobeItem).filter(WardrobeItem.id == "real-item-999").first()
    assert real_item_check is not None
    assert real_item_check.name == "Real User Private Silk Dress"

    # 5. Idempotence Check: Run restore again
    report2 = restore_demo_baseline(db_session, target_user_id=demo_uid, dry_run=False)
    assert report2["items_created"] == 0
    assert report2["items_removed"] == 0
    assert report2["items_updated"] == len(BASELINE_ITEMS)

    # Total items remains exactly 10
    demo_items_round2 = db_session.query(WardrobeItem).filter(WardrobeItem.user_id == demo_uid).all()
    assert len(demo_items_round2) == len(BASELINE_ITEMS)
