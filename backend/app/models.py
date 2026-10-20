import uuid
from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from app.database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=True, index=True)
    name = Column(String(120), nullable=False)
    category = Column(String(50), nullable=False, index=True)
    sub_category = Column(String(50), nullable=True)
    primary_color = Column(String(40), nullable=False, index=True)
    secondary_color = Column(String(40), nullable=True)
    pattern = Column(String(40), nullable=True)
    material = Column(String(50), nullable=True)
    fit = Column(String(40), nullable=True)
    season = Column(String(30), nullable=True)
    formality = Column(String(40), nullable=True)
    brand = Column(String(80), nullable=True, index=True)
    size = Column(String(40), nullable=True)
    condition = Column(String(40), nullable=True)
    notes = Column(Text, nullable=True)
    tags = Column(Text, nullable=True, default="[]")  # JSON encoded list
    image_path = Column(String(255), nullable=False)
    storage_provider = Column(String(30), nullable=False, default="local", server_default="local")  # "local" | "cloudinary"
    cloudinary_public_id = Column(String(255), nullable=True)
    image_format = Column(String(20), nullable=True)
    image_version = Column(String(30), nullable=True)
    is_community_shared = Column(Boolean, nullable=False, default=False, server_default="0")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class OutfitAnalysisRecord(Base):
    __tablename__ = "outfit_analyses"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=True, index=True)
    image_path = Column(String(255), nullable=False)
    storage_provider = Column(String(30), nullable=False, default="local", server_default="local")
    cloudinary_public_id = Column(String(255), nullable=True)
    image_format = Column(String(20), nullable=True)
    image_version = Column(String(30), nullable=True)
    summary = Column(Text, nullable=True)
    vibe = Column(String(80), nullable=True)
    items_json = Column(Text, nullable=False)  # JSON encoded detected items
    created_at = Column(DateTime, default=datetime.utcnow)


class SavedOutfit(Base):
    __tablename__ = "saved_outfits"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=True, index=True)
    name = Column(String(120), nullable=False)
    occasion = Column(String(60), nullable=True)
    notes = Column(Text, nullable=True)
    image_path = Column(String(255), nullable=True)
    storage_provider = Column(String(30), nullable=False, default="local", server_default="local")
    cloudinary_public_id = Column(String(255), nullable=True)
    item_ids_json = Column(Text, nullable=False, default="[]")
    inspiration_analysis_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class TryOnTaskRecord(Base):
    __tablename__ = "tryon_tasks"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=True, index=True)
    provider = Column(String(30), nullable=False, default="mock")
    external_task_id = Column(String(100), nullable=True, index=True)
    status = Column(String(30), nullable=False, default="pending", index=True)  # pending, processing, success, failed
    user_image_path = Column(String(255), nullable=False)
    garment_image_path = Column(String(255), nullable=False)
    storage_provider = Column(String(30), nullable=False, default="local", server_default="local")
    user_image_public_id = Column(String(255), nullable=True)
    garment_image_public_id = Column(String(255), nullable=True)
    result_image_public_id = Column(String(255), nullable=True)
    result_image_url = Column(String(500), nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True, index=True)


class Community(Base):
    __tablename__ = "communities"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False, index=True)
    description = Column(Text, nullable=True)
    creator_id = Column(String(36), nullable=False, index=True)
    status = Column(String(30), nullable=False, default="active", server_default="active", index=True)  # active, archived
    is_private = Column(Boolean, nullable=False, default=True, server_default="1")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    memberships = relationship("CommunityMembership", back_populates="community", cascade="all, delete-orphan")
    listings = relationship("CommunityListing", back_populates="community", cascade="all, delete-orphan")


class CommunityMembership(Base):
    __tablename__ = "community_memberships"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    community_id = Column(String(36), ForeignKey("communities.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), nullable=False, index=True)
    role = Column(String(30), nullable=False, default="member", server_default="member")  # owner, admin, member
    status = Column(String(30), nullable=False, default="requested", server_default="requested", index=True)  # requested, approved, rejected, removed
    requested_at = Column(DateTime, default=datetime.utcnow)
    decided_at = Column(DateTime, nullable=True)
    decided_by_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("community_id", "user_id", name="uq_community_user_membership"),
    )

    community = relationship("Community", back_populates="memberships")


class CommunityListing(Base):
    __tablename__ = "community_listings"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    community_id = Column(String(36), ForeignKey("communities.id", ondelete="CASCADE"), nullable=False, index=True)
    wardrobe_item_id = Column(String(36), ForeignKey("wardrobe_items.id", ondelete="CASCADE"), nullable=False, index=True)
    owner_id = Column(String(36), nullable=False, index=True)
    status = Column(String(30), nullable=False, default="active", server_default="active", index=True)  # active, unlisted
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("community_id", "wardrobe_item_id", name="uq_community_wardrobe_item_listing"),
    )

    community = relationship("Community", back_populates="listings")
    wardrobe_item = relationship("WardrobeItem")


class SchemaMigration(Base):
    __tablename__ = "schema_migrations"

    version = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False)
    applied_at = Column(DateTime, default=datetime.utcnow)
