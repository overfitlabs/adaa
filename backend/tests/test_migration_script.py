import pytest
import sqlite3
from pathlib import Path
from datetime import datetime
from app.scripts.migrate_sqlite_to_pg import (
    parse_datetime,
    count_sqlite_rows,
    create_verified_sqlite_backup,
    run_migration,
)
from app.models import Community, CommunityMembership


def test_parse_datetime():
    dt_str = "2026-10-20 09:10:58.768186"
    parsed = parse_datetime(dt_str)
    assert isinstance(parsed, datetime)
    assert parsed.year == 2026
    assert parsed.month == 10
    assert parsed.day == 20

    iso_str = "2026-10-20T14:30:00"
    parsed_iso = parse_datetime(iso_str)
    assert isinstance(parsed_iso, datetime)
    assert parsed_iso.hour == 14

    assert parse_datetime(None) is None
    assert parse_datetime("") is None


def test_count_sqlite_rows(tmp_path):
    test_db = tmp_path / "test_source.db"
    conn = sqlite3.connect(str(test_db))
    cur = conn.cursor()
    cur.execute("CREATE TABLE communities (id TEXT PRIMARY KEY, name TEXT)")
    cur.execute("INSERT INTO communities VALUES ('c1', 'Test Comm')")
    cur.execute("CREATE TABLE wardrobe_items (id TEXT PRIMARY KEY, name TEXT)")
    conn.commit()
    conn.close()

    counts = count_sqlite_rows(test_db)
    assert counts["communities"] == 1
    assert counts["wardrobe_items"] == 0
    assert counts["saved_outfits"] == 0


def test_create_verified_sqlite_backup(tmp_path):
    src_db = tmp_path / "source.db"
    conn = sqlite3.connect(str(src_db))
    cur = conn.cursor()
    cur.execute("CREATE TABLE test_table (id INT, val TEXT)")
    cur.execute("INSERT INTO test_table VALUES (1, 'hello')")
    conn.commit()
    conn.close()

    backup = create_verified_sqlite_backup(src_db)
    assert backup.exists()
    assert backup.stat().st_size > 0

    chk_conn = sqlite3.connect(str(backup))
    res = chk_conn.cursor().execute("PRAGMA integrity_check").fetchone()[0]
    chk_conn.close()
    assert res == "ok"


def test_run_migration_end_to_end(tmp_path):
    src_db = tmp_path / "wardrobe_src.db"
    src_conn = sqlite3.connect(str(src_db))
    cur = src_conn.cursor()
    cur.execute("""
        CREATE TABLE communities (
            id VARCHAR(36) PRIMARY KEY,
            name VARCHAR(100),
            creator_id VARCHAR(36),
            status VARCHAR(30) DEFAULT 'active',
            is_private BOOLEAN DEFAULT 1,
            created_at DATETIME,
            updated_at DATETIME
        )
    """)
    cur.execute("""
        CREATE TABLE community_memberships (
            id VARCHAR(36) PRIMARY KEY,
            community_id VARCHAR(36),
            user_id VARCHAR(36),
            role VARCHAR(30),
            status VARCHAR(30),
            requested_at DATETIME,
            decided_at DATETIME,
            decided_by_id VARCHAR(36),
            created_at DATETIME,
            updated_at DATETIME
        )
    """)
    cur.execute("""
        INSERT INTO communities (id, name, creator_id, is_private, created_at, updated_at)
        VALUES ('comm-1', 'Eco Swap', 'user-1', 1, '2026-10-20 10:00:00', '2026-10-20 10:00:00')
    """)
    cur.execute("""
        INSERT INTO community_memberships (id, community_id, user_id, role, status, requested_at, decided_at, decided_by_id, created_at, updated_at)
        VALUES ('mem-1', 'comm-1', 'user-1', 'owner', 'approved', '2026-10-20 10:00:00', '2026-10-20 10:00:00', 'user-1', '2026-10-20 10:00:00', '2026-10-20 10:00:00')
    """)
    src_conn.commit()
    src_conn.close()

    target_db = tmp_path / "target.db"
    target_url = f"sqlite:///{target_db}"

    # Dry-run test
    dry_results = run_migration(
        source_db_path=src_db,
        target_db_url=target_url,
        dry_run=True,
        migrate_images=False,
    )
    assert dry_results["status"] == "success"
    assert dry_results["source_counts"]["communities"] == 1
    assert dry_results["source_counts"]["community_memberships"] == 1

    # Actual migration
    real_results = run_migration(
        source_db_path=src_db,
        target_db_url=target_url,
        dry_run=False,
        migrate_images=False,
    )
    assert real_results["status"] == "success"
    assert real_results["target_after_counts"]["communities"] == 1
    assert real_results["target_after_counts"]["community_memberships"] == 1

    # Verify target row data
    tgt_conn = sqlite3.connect(str(target_db))
    c = tgt_conn.cursor()
    c.execute("SELECT id, name, is_private FROM communities WHERE id = 'comm-1'")
    comm_row = c.fetchone()
    assert comm_row[0] == "comm-1"
    assert comm_row[1] == "Eco Swap"
    tgt_conn.close()
