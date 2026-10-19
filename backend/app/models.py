import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Text
from app.database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id = Column(String(36), primary_key=True, default=generate_uuid)
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
    tags = Column(Text, nullable=True, default="[]")  # JSON encoded list
    image_path = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class OutfitAnalysisRecord(Base):
    __tablename__ = "outfit_analyses"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    image_path = Column(String(255), nullable=False)
    summary = Column(Text, nullable=True)
    vibe = Column(String(80), nullable=True)
    items_json = Column(Text, nullable=False)  # JSON encoded detected items
    created_at = Column(DateTime, default=datetime.utcnow)


class SavedOutfit(Base):
    __tablename__ = "saved_outfits"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(120), nullable=False)
    occasion = Column(String(60), nullable=True)
    notes = Column(Text, nullable=True)
    image_path = Column(String(255), nullable=True)
    item_ids_json = Column(Text, nullable=False, default="[]")
    inspiration_analysis_id = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class TryOnTaskRecord(Base):
    __tablename__ = "tryon_tasks"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    provider = Column(String(30), nullable=False, default="mock")
    external_task_id = Column(String(100), nullable=True, index=True)
    status = Column(String(30), nullable=False, default="pending", index=True)  # pending, processing, success, failed
    user_image_path = Column(String(255), nullable=False)
    garment_image_path = Column(String(255), nullable=False)
    result_image_url = Column(String(500), nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
