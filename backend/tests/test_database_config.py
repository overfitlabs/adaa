import pytest
from unittest.mock import MagicMock, patch
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool
from app.database import normalize_database_url, create_app_engine, init_db, Base
from app.models import SchemaMigration
from app.main import app
from fastapi.testclient import TestClient


def test_normalize_database_url_sqlite():
    url = "sqlite:///./wardrobelens.db"
    assert normalize_database_url(url) == url


def test_normalize_database_url_postgres_scheme():
    url = "postgres://postgres.gehuuvotncxpkwpvvbbv:secretpassword@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require"
    expected = "postgresql+psycopg2://postgres.gehuuvotncxpkwpvvbbv:secretpassword@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require"
    assert normalize_database_url(url) == expected


def test_normalize_database_url_postgresql_scheme():
    url = "postgresql://user:pass@ep-xyz.supabase.co:5432/postgres"
    expected = "postgresql+psycopg2://user:pass@ep-xyz.supabase.co:5432/postgres"
    assert normalize_database_url(url) == expected


def test_normalize_database_url_already_psycopg2():
    url = "postgresql+psycopg2://user:pass@ep-xyz.supabase.co:5432/postgres"
    assert normalize_database_url(url) == url


def test_create_app_engine_pooling_and_prepings():
    # SQLite test engine
    sqlite_engine = create_app_engine("sqlite:///:memory:")
    assert sqlite_engine.dialect.name == "sqlite"

    # PostgreSQL configuration options
    with patch("app.database.create_engine") as mock_create_engine:
        pg_url = "postgresql+psycopg2://user:pass@aws-0-us-east-1.pooler.supabase.com:6543/postgres"
        create_app_engine(pg_url)
        mock_create_engine.assert_called_once()
        kwargs = mock_create_engine.call_args.kwargs
        assert kwargs.get("pool_pre_ping") is True
        assert kwargs.get("pool_recycle") == 1800
        assert kwargs.get("pool_size") == 10
        assert kwargs.get("max_overflow") == 15
        assert kwargs.get("pool_timeout") == 30


def test_schema_migration_version_tracking():
    # Test on an in-memory SQLite engine
    test_engine = create_engine("sqlite:///:memory:")
    init_db(target_engine=test_engine)

    from sqlalchemy.orm import sessionmaker
    TestSession = sessionmaker(bind=test_engine)
    with TestSession() as session:
        # Verify schema_migrations table was created
        migration = SchemaMigration(version="0001_initial", name="initial_schema")
        session.add(migration)
        session.commit()

        queried = session.query(SchemaMigration).filter_by(version="0001_initial").first()
        assert queried is not None
        assert queried.name == "initial_schema"
        assert queried.applied_at is not None


def test_health_check_endpoint_resilient(client):
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"
    assert "password" not in res.text.lower()
    assert "secret" not in res.text.lower()


def test_health_check_endpoint_database_disconnected(client):
    """
    Verifies that when database connectivity fails (e.g. PostgreSQL pooler timeout/outage):
    1. Returns HTTP 503 Service Unavailable.
    2. Reports status: 'unhealthy' and database: 'disconnected'.
    3. Does NOT leak connection strings, passwords, or raw SQL traceback details.
    """
    from sqlalchemy.exc import OperationalError
    from app.database import get_db

    def broken_db():
        mock_session = MagicMock()
        mock_session.execute.side_effect = OperationalError("connection refused", {}, None)
        yield mock_session

    app.dependency_overrides[get_db] = broken_db
    try:
        res = client.get("/health")
        assert res.status_code == 503
        data = res.json()
        assert data["status"] == "unhealthy"
        assert data["database"] == "disconnected"
        assert "password" not in res.text.lower()
        assert "connection refused" not in res.text.lower()
        assert "traceback" not in res.text.lower()
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_init_db_schema_isolation_does_not_touch_profiles():
    """
    Verifies that Base.metadata.create_all and init_db do not manage, alter, or drop
    Supabase-managed tables such as 'public.profiles' or 'auth.users'.
    """
    # Check that 'profiles' is NOT registered in SQLAlchemy application Base metadata
    registered_tables = set(Base.metadata.tables.keys())
    assert "profiles" not in registered_tables
    assert "users" not in registered_tables
    assert "auth_users" not in registered_tables

    # Verify only application-owned tables are registered
    expected_app_tables = {
        "wardrobe_items",
        "outfit_analyses",
        "saved_outfits",
        "tryon_tasks",
        "communities",
        "community_memberships",
        "community_listings",
        "schema_migrations",
    }
    assert registered_tables == expected_app_tables

