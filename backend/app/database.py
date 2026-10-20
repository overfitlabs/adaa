import logging
from datetime import datetime
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker
from app.config import settings

logger = logging.getLogger("wardrobelens.database")


def normalize_database_url(url: str) -> str:
    """
    Normalizes PostgreSQL and SQLite URLs for SQLAlchemy compatibility.
    Handles 'postgres://' -> 'postgresql+psycopg2://' rewrite required by SQLAlchemy 2.x,
    and ensures proper dialect prefix for postgresql connections.
    """
    if not url:
        return "sqlite:///./wardrobelens.db"

    clean_url = url.strip()
    if clean_url.startswith("postgres://"):
        clean_url = "postgresql+psycopg2://" + clean_url[len("postgres://"):]
    elif clean_url.startswith("postgresql://") and not clean_url.startswith("postgresql+"):
        clean_url = "postgresql+psycopg2://" + clean_url[len("postgresql://"):]
    return clean_url


def create_app_engine(database_url: str):
    """
    Creates an optimized SQLAlchemy engine configured for the target database dialect.
    Applies connection pooling, liveness pre-pings, and keepalive recycling for PostgreSQL/Supabase,
    and thread isolation flags for SQLite.
    """
    normalized_url = normalize_database_url(database_url)
    is_sqlite = "sqlite" in normalized_url.lower()

    if is_sqlite:
        return create_engine(
            normalized_url,
            connect_args={"check_same_thread": False},
        )
    else:
        return create_engine(
            normalized_url,
            pool_pre_ping=True,      # Tests connection liveness before checkout to prevent dead-pooler socket errors
            pool_size=10,             # Concurrency capacity tailored for Render free tier & Supabase pooler
            max_overflow=15,          # Burst capacity
            pool_recycle=1800,        # Recycle connections every 30 mins to avoid firewall/NAT drops
            pool_timeout=30,          # Fail fast if all pooled connections are saturated
        )


engine = create_app_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


REQUIRED_COLUMNS = {
    "wardrobe_items": [
        ("user_id", "VARCHAR(36)"),
        ("storage_provider", "VARCHAR(30) DEFAULT 'local'"),
        ("cloudinary_public_id", "VARCHAR(255)"),
        ("image_format", "VARCHAR(20)"),
        ("image_version", "VARCHAR(30)"),
        ("is_community_shared", "BOOLEAN DEFAULT 0"),
        ("brand", "VARCHAR(80)"),
        ("size", "VARCHAR(40)"),
        ("condition", "VARCHAR(40)"),
        ("notes", "TEXT"),
    ],
    "outfit_analyses": [
        ("user_id", "VARCHAR(36)"),
        ("storage_provider", "VARCHAR(30) DEFAULT 'local'"),
        ("cloudinary_public_id", "VARCHAR(255)"),
        ("image_format", "VARCHAR(20)"),
        ("image_version", "VARCHAR(30)"),
    ],
    "saved_outfits": [
        ("user_id", "VARCHAR(36)"),
        ("storage_provider", "VARCHAR(30) DEFAULT 'local'"),
        ("cloudinary_public_id", "VARCHAR(255)"),
    ],
    "tryon_tasks": [
        ("user_id", "VARCHAR(36)"),
        ("storage_provider", "VARCHAR(30) DEFAULT 'local'"),
        ("user_image_public_id", "VARCHAR(255)"),
        ("garment_image_public_id", "VARCHAR(255)"),
        ("result_image_public_id", "VARCHAR(255)"),
        ("expires_at", "DATETIME"),
    ],
    "communities": [
        ("status", "VARCHAR(30) DEFAULT 'active'"),
        ("is_private", "BOOLEAN DEFAULT 1"),
    ],
    "community_memberships": [
        ("role", "VARCHAR(30) DEFAULT 'member'"),
        ("status", "VARCHAR(30) DEFAULT 'requested'"),
        ("requested_at", "DATETIME"),
        ("decided_at", "DATETIME"),
        ("decided_by_id", "VARCHAR(36)"),
    ],
    "community_listings": [
        ("status", "VARCHAR(30) DEFAULT 'active'"),
        ("notes", "TEXT"),
    ],
}


def _adapt_column_type(col_type: str, is_sqlite: bool) -> str:
    """Adapts SQLite-style column definitions to PostgreSQL if needed."""
    if is_sqlite:
        return col_type
    pg_type = col_type
    pg_type = pg_type.replace("BOOLEAN DEFAULT 0", "BOOLEAN DEFAULT FALSE")
    pg_type = pg_type.replace("BOOLEAN DEFAULT 1", "BOOLEAN DEFAULT TRUE")
    pg_type = pg_type.replace("DATETIME", "TIMESTAMP")
    return pg_type


def init_db(target_engine=None):
    """
    Initializes application tables and performs safe, tracked, additive migrations.
    Tracks migration state in 'schema_migrations' to guarantee schema tracking without blind recreation.
    Supports both SQLite and PostgreSQL dialects transparently.
    """
    active_engine = target_engine or engine
    is_sqlite = active_engine.dialect.name == "sqlite"

    # Step 1: Create all Base metadata tables (idempotent, skips existing tables)
    Base.metadata.create_all(bind=active_engine)

    # Step 2: Ensure schema_migrations table exists for version tracking
    try:
        with active_engine.connect() as conn:
            if is_sqlite:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        version VARCHAR(50) PRIMARY KEY,
                        name VARCHAR(100) NOT NULL,
                        applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    )
                """))
            else:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS schema_migrations (
                        version VARCHAR(50) PRIMARY KEY,
                        name VARCHAR(100) NOT NULL,
                        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """))
            conn.commit()
    except Exception as e:
        logger.warning("schema_migrations table creation note: %s", str(e))

    # Step 3: Run safe column additions and index creation
    try:
        inspector = inspect(active_engine)
        with active_engine.connect() as conn:
            for table_name, col_defs in REQUIRED_COLUMNS.items():
                if inspector.has_table(table_name):
                    existing_cols = {col["name"] for col in inspector.get_columns(table_name)}
                    for col_name, col_type in col_defs:
                        actual_type = _adapt_column_type(col_type, is_sqlite)
                        if col_name not in existing_cols:
                            sql = f"ALTER TABLE {table_name} ADD COLUMN {col_name} {actual_type}"
                            logger.info("Migrating table %s: %s", table_name, sql)
                            conn.execute(text(sql))
                            existing_cols.add(col_name)

            # Ensure indexes exist for foreign keys and lookup queries
            if inspector.has_table("tryon_tasks"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_tryon_tasks_user_id ON tryon_tasks (user_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_tryon_tasks_expires_at ON tryon_tasks (expires_at)"))
            if inspector.has_table("saved_outfits"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_saved_outfits_user_id ON saved_outfits (user_id)"))
            if inspector.has_table("wardrobe_items"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_wardrobe_items_brand ON wardrobe_items (brand)"))
            if inspector.has_table("communities"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_communities_name ON communities (name)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_communities_creator_id ON communities (creator_id)"))
            if inspector.has_table("community_memberships"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_mem_comm_id ON community_memberships (community_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_mem_user_id ON community_memberships (user_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_mem_status ON community_memberships (status)"))
            if inspector.has_table("community_listings"):
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_list_comm_id ON community_listings (community_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_list_item_id ON community_listings (wardrobe_item_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_list_owner_id ON community_listings (owner_id)"))
                conn.execute(text("CREATE INDEX IF NOT EXISTS ix_comm_list_status ON community_listings (status)"))

            # Record baseline migrations in schema_migrations
            migrations_to_record = [
                ("0001_core_tables", "Core wardrobe and styling tables"),
                ("0002_community_foundation", "Community and shared closet tables"),
                ("0003_postgresql_compat", "PostgreSQL dialect support and indexes"),
            ]
            for version_code, desc in migrations_to_record:
                if is_sqlite:
                    conn.execute(
                        text("INSERT OR IGNORE INTO schema_migrations (version, name) VALUES (:v, :n)"),
                        {"v": version_code, "n": desc},
                    )
                else:
                    conn.execute(
                        text("INSERT INTO schema_migrations (version, name) VALUES (:v, :n) ON CONFLICT (version) DO NOTHING"),
                        {"v": version_code, "n": desc},
                    )

            conn.commit()
    except Exception as e:
        logger.warning("Database safe column check note: %s", str(e))
