import os
import sqlite3
import pytest
from sqlalchemy import create_engine
from app.database import init_db, REQUIRED_COLUMNS


def test_migrations_fresh_and_idempotent(tmp_path):
    test_db = tmp_path / "test_migration.db"
    db_url = f"sqlite:///{test_db}"

    from app import database
    orig_engine = database.engine
    orig_url = database.settings.DATABASE_URL
    try:
        database.engine = create_engine(db_url, connect_args={"check_same_thread": False})
        database.settings.DATABASE_URL = db_url

        # 1. First run creates tables and columns
        database.init_db()

        conn = sqlite3.connect(str(test_db))
        cursor = conn.cursor()
        for table, cols in REQUIRED_COLUMNS.items():
            cursor.execute(f"PRAGMA table_info({table})")
            existing_cols = {row[1] for row in cursor.fetchall()}
            for col_name, _ in cols:
                assert col_name in existing_cols, f"{col_name} should be present in {table}"

        # 2. Insert test unowned legacy record
        cursor.execute(
            "INSERT INTO outfit_analyses (id, image_path, items_json) VALUES (?, ?, ?)",
            ("legacy-uuid-1", "inspirations/legacy.jpg", "[]")
        )
        conn.commit()

        # 3. Second run must be completely idempotent without corrupting data
        database.init_db()

        cursor.execute("SELECT id, user_id, storage_provider FROM outfit_analyses WHERE id = 'legacy-uuid-1'")
        row = cursor.fetchone()
        assert row is not None
        assert row[0] == "legacy-uuid-1"
        assert row[1] is None
        assert row[2] == "local"
        conn.close()

    finally:
        database.engine = orig_engine
        database.settings.DATABASE_URL = orig_url
