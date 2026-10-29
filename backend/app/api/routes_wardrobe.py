import json
import logging
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import WardrobeItem, Community, CommunityListing
from app.schemas import (
    WardrobeItemResponse,
    WardrobeItemUpdate,
    DetectedFashionItem,
    CommunityListingResponse,
    BulkWardrobeItemsRequest,
    BulkWardrobeItemsResponse,
    BulkWardrobeItemResult,
)
from app.services.image_storage import image_storage_service
from app.services.vision_provider import get_vision_provider
from app.auth.supabase_auth import get_optional_current_user, get_current_user, AuthenticatedUser

logger = logging.getLogger("wardrobelens.routes_wardrobe")

router = APIRouter(prefix="/api/wardrobe", tags=["Digital Wardrobe"])


def _model_to_response(item: WardrobeItem) -> WardrobeItemResponse:
    tags = json.loads(item.tags) if item.tags else []

    if getattr(item, "storage_provider", "local") == "cloudinary" and getattr(item, "cloudinary_public_id", None):
        image_url = image_storage_service.generate_delivery_url(
            item.cloudinary_public_id,
            storage_provider="cloudinary",
            ttl_seconds=settings.IMAGE_DELIVERY_TTL_SECONDS,
        )
    elif item.image_path.startswith("http://") or item.image_path.startswith("https://"):
        image_url = item.image_path
    else:
        clean_path = item.image_path.lstrip("/")
        if clean_path.startswith("storage/"):
            clean_path = clean_path[len("storage/"):]
        image_url = f"/storage/{clean_path}"

    return WardrobeItemResponse(
        id=item.id,
        user_id=item.user_id,
        name=item.name,
        category=item.category,
        sub_category=item.sub_category,
        primary_color=item.primary_color,
        secondary_color=item.secondary_color,
        pattern=item.pattern,
        material=item.material,
        fit=item.fit,
        season=item.season,
        formality=item.formality,
        brand=getattr(item, "brand", None),
        size=getattr(item, "size", None),
        condition=getattr(item, "condition", None),
        notes=getattr(item, "notes", None),
        tags=tags,
        image_path=item.image_path,
        image_url=image_url,
        storage_provider=getattr(item, "storage_provider", "local"),
        is_community_shared=getattr(item, "is_community_shared", False),
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.post("/detect-item")
async def detect_wardrobe_item_from_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    """
    Analyzes a photo of a single wardrobe garment to pre-fill metadata
    (category, colors, material, pattern, fit) before saving.
    When USE_MEDIAFLOWS is enabled, routes through the MediaFlows pipeline with Gemini fallback.
    Cleans up any temporary staging files immediately to prevent orphaned disk assets.
    """
    if settings.USE_MEDIAFLOWS:
        from app.api.routes_analysis import analyze_outfit_image, _execute_direct_gemini_fallback
        from app.models import OutfitAnalysisRecord
        import asyncio
        import time

        analysis_res = await analyze_outfit_image(file=file, db=db, current_user=current_user)
        if getattr(analysis_res, "status", "completed") in ("pending", "processing"):
            scan_id = analysis_res.analysis_id
            start_wait = time.time()
            while time.time() - start_wait < settings.MEDIAFLOWS_TIMEOUT_SECONDS:
                await asyncio.sleep(1.0)
                db.expire_all()
                rec = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == scan_id).first()
                if rec and rec.status == "completed":
                    items_list = json.loads(rec.items_json) if rec.items_json else []
                    primary_item = items_list[0] if items_list else None
                    return {
                        "detected_item": primary_item,
                        "detected_vibe": rec.vibe,
                    }
                elif rec and rec.status == "failed":
                    break

            # Fallback if webhook timed out or failed
            rec = db.query(OutfitAnalysisRecord).filter(OutfitAnalysisRecord.id == scan_id).first()
            if rec and rec.status != "completed":
                try:
                    await _execute_direct_gemini_fallback(rec, db)
                    items_list = json.loads(rec.items_json) if rec.items_json else []
                    return {
                        "detected_item": items_list[0] if items_list else None,
                        "detected_vibe": rec.vibe,
                    }
                except Exception as fb_err:
                    logger.warning("MediaFlows fallback failed in detect-item: %s", str(fb_err))

        primary_item = analysis_res.items[0] if analysis_res.items else None
        return {
            "detected_item": primary_item.model_dump() if hasattr(primary_item, "model_dump") else primary_item,
            "detected_vibe": analysis_res.vibe_or_style,
        }

    raw_bytes = await file.read()
    clean_bytes, ext, _, _ = image_storage_service.validate_and_sanitize_image(file, raw_bytes)

    temp_filename = f"detect_staging_{uuid.uuid4().hex}.{ext}"
    temp_dir = settings.storage_path / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_path = temp_dir / temp_filename

    try:
        with open(temp_path, "wb") as f:
            f.write(clean_bytes)

        vision = get_vision_provider()
        summary, vibe, items = await vision.analyze_outfit_image(temp_path)
        primary_item = items[0] if items else None
        return {
            "detected_item": primary_item,
            "detected_vibe": vibe,
        }
    except Exception as e:
        logger.error("Wardrobe item detection failed: %s", str(e), exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Detection failed: {str(e)}",
        )
    finally:
        if temp_path.is_file():
            try:
                temp_path.unlink()
            except Exception:
                pass


@router.post("/items", response_model=WardrobeItemResponse, status_code=status.HTTP_201_CREATED)
async def create_wardrobe_item(
    name: str = Form(...),
    category: str = Form(...),
    primary_color: str = Form(...),
    sub_category: Optional[str] = Form(None),
    secondary_color: Optional[str] = Form(None),
    pattern: Optional[str] = Form(None),
    material: Optional[str] = Form(None),
    fit: Optional[str] = Form(None),
    season: Optional[str] = Form(None),
    formality: Optional[str] = Form(None),
    brand: Optional[str] = Form(None),
    size: Optional[str] = Form(None),
    condition: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    tags: Optional[str] = Form("[]"),  # JSON array string or comma separated
    image_path: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    if not file and not image_path:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either an image file or an existing image_path must be provided.",
        )

    # Parse tags
    parsed_tags = []
    if tags:
        try:
            parsed_tags = json.loads(tags)
            if not isinstance(parsed_tags, list):
                parsed_tags = [str(tags)]
        except Exception:
            parsed_tags = [t.strip() for t in tags.split(",") if t.strip()]

    user_id = current_user.id if current_user else None
    uploaded_meta = None

    if file:
        uploaded_meta = await image_storage_service.upload(
            file,
            user_id=user_id,
            subfolder="wardrobe",
        )
        final_image_path = uploaded_meta.public_id
        final_storage_provider = uploaded_meta.storage_provider
        final_cloudinary_id = uploaded_meta.public_id if uploaded_meta.storage_provider == "cloudinary" else None
        final_format = uploaded_meta.format
        final_version = uploaded_meta.version
    else:
        # Fallback for manual or test fixture image_path
        final_image_path = image_path
        final_storage_provider = "local"
        final_cloudinary_id = None
        final_format = image_path.split(".")[-1] if "." in image_path else "jpg"
        final_version = None

    item = WardrobeItem(
        user_id=user_id,
        name=name.strip(),
        category=category.strip().lower(),
        sub_category=sub_category.strip() if sub_category else None,
        primary_color=primary_color.strip(),
        secondary_color=secondary_color.strip() if secondary_color else None,
        pattern=pattern.strip() if pattern else None,
        material=material.strip() if material else None,
        fit=fit.strip() if fit else None,
        season=season.strip() if season else None,
        formality=formality.strip() if formality else None,
        brand=brand.strip() if brand else None,
        size=size.strip() if size else None,
        condition=condition.strip() if condition else None,
        notes=notes.strip() if notes else None,
        tags=json.dumps(parsed_tags),
        image_path=final_image_path,
        storage_provider=final_storage_provider,
        cloudinary_public_id=final_cloudinary_id,
        image_format=final_format,
        image_version=final_version,
        is_community_shared=False,  # Private by default
    )

    try:
        db.add(item)
        db.commit()
        db.refresh(item)
    except Exception as e:
        db.rollback()
        # Clean up newly uploaded image to prevent orphaned assets on failed DB writes
        if uploaded_meta:
            image_storage_service.delete(
                uploaded_meta.public_id,
                storage_provider=uploaded_meta.storage_provider,
            )
        logger.error("Failed to persist wardrobe item: %s", str(e), exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error saving wardrobe item: {str(e)}",
        )

    return _model_to_response(item)


@router.post("/items/bulk", response_model=BulkWardrobeItemsResponse, status_code=status.HTTP_201_CREATED)
def bulk_create_wardrobe_items(
    payload: BulkWardrobeItemsRequest,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    """
    Bulk saves multiple wardrobe items extracted from an outfit capture.
    - Each item becomes its own independent WardrobeItem record.
    - Idempotent deduplication prevents double-creation on client retry.
    - Granular per-item success/failure reporting.
    """
    user_id = current_user.id if current_user else None
    results: List[BulkWardrobeItemResult] = []
    saved_count = 0
    failed_count = 0
    created_in_this_batch_ids = set()

    for item_data in payload.items:
        client_id = item_data.client_id
        try:
            # Clean image path (strip any leading slashes or /storage/ prefix)
            raw_img = (item_data.image_path or "").strip().lstrip("/")
            if raw_img.startswith("storage/"):
                raw_img = raw_img[len("storage/"):]

            # Check for recent duplicate (identical name, category, and real image_path for this user)
            existing = None
            if raw_img and raw_img != "wardrobe/placeholder.jpg":
                q = db.query(WardrobeItem).filter(
                    WardrobeItem.name == item_data.name.strip(),
                    WardrobeItem.category == item_data.category.strip().lower(),
                    (WardrobeItem.image_path == raw_img)
                    | (WardrobeItem.image_path == f"/{raw_img}")
                    | (WardrobeItem.image_path == f"storage/{raw_img}"),
                )
                if user_id:
                    q = q.filter(WardrobeItem.user_id == user_id)
                else:
                    q = q.filter(WardrobeItem.user_id.is_(None))

                # Never suppress separate items that were created earlier within this same batch
                if created_in_this_batch_ids:
                    q = q.filter(~WardrobeItem.id.in_(created_in_this_batch_ids))

                existing = q.first()

            if existing:
                results.append(
                    BulkWardrobeItemResult(
                        client_id=client_id,
                        success=True,
                        item=_model_to_response(existing),
                    )
                )
                saved_count += 1
                continue

            final_image_path = raw_img or "wardrobe/placeholder.jpg"
            is_cloudinary = settings.is_cloudinary_configured and settings.STORAGE_BACKEND == "cloudinary"
            final_storage_provider = "cloudinary" if is_cloudinary else "local"
            final_cloudinary_id = final_image_path if is_cloudinary else None
            ext = final_image_path.split(".")[-1] if "." in final_image_path else "jpg"

            new_item = WardrobeItem(
                user_id=user_id,
                name=item_data.name.strip(),
                category=item_data.category.strip().lower(),
                sub_category=item_data.sub_category.strip() if item_data.sub_category else None,
                primary_color=item_data.primary_color.strip(),
                secondary_color=item_data.secondary_color.strip() if item_data.secondary_color else None,
                pattern=item_data.pattern.strip() if item_data.pattern else None,
                material=item_data.material.strip() if item_data.material else None,
                fit=item_data.fit.strip() if item_data.fit else None,
                season=item_data.season.strip() if item_data.season else None,
                formality=item_data.formality.strip() if item_data.formality else None,
                brand=item_data.brand.strip() if item_data.brand else None,
                size=item_data.size.strip() if item_data.size else None,
                condition=item_data.condition.strip() if item_data.condition else None,
                notes=item_data.notes.strip() if item_data.notes else None,
                tags=json.dumps(item_data.tags or []),
                image_path=final_image_path,
                storage_provider=final_storage_provider,
                cloudinary_public_id=final_cloudinary_id,
                image_format=ext,
                image_version=None,
                is_community_shared=False,
            )
            db.add(new_item)
            db.commit()
            db.refresh(new_item)
            created_in_this_batch_ids.add(new_item.id)

            results.append(
                BulkWardrobeItemResult(
                    client_id=client_id,
                    success=True,
                    item=_model_to_response(new_item),
                )
            )
            saved_count += 1
        except Exception as e:
            db.rollback()
            logger.error("Failed to create bulk wardrobe item (%s): %s", item_data.name, str(e))
            results.append(
                BulkWardrobeItemResult(
                    client_id=client_id,
                    success=False,
                    error=str(e),
                )
            )
            failed_count += 1

    return BulkWardrobeItemsResponse(
        saved_count=saved_count,
        failed_count=failed_count,
        results=results,
    )


@router.get("/items", response_model=List[WardrobeItemResponse])
def list_wardrobe_items(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    color: Optional[str] = Query(None),
    brand: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    query = db.query(WardrobeItem)

    # Scoped ownership: authenticated users only see their items; anonymous users only see unowned legacy items
    if current_user:
        query = query.filter(WardrobeItem.user_id == current_user.id)
    else:
        query = query.filter(WardrobeItem.user_id.is_(None))

    if category and category.lower() != "all":
        query = query.filter(WardrobeItem.category == category.lower().strip())

    if color:
        query = query.filter(
            (WardrobeItem.primary_color.ilike(f"%{color}%"))
            | (WardrobeItem.secondary_color.ilike(f"%{color}%"))
        )

    if brand:
        query = query.filter(WardrobeItem.brand.ilike(f"%{brand.strip()}%"))

    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (WardrobeItem.name.ilike(s))
            | (WardrobeItem.category.ilike(s))
            | (WardrobeItem.sub_category.ilike(s))
            | (WardrobeItem.material.ilike(s))
            | (WardrobeItem.brand.ilike(s))
            | (WardrobeItem.notes.ilike(s))
            | (WardrobeItem.tags.ilike(s))
        )

    items = query.order_by(WardrobeItem.created_at.desc()).all()
    return [_model_to_response(i) for i in items]


@router.get("/items/{item_id}", response_model=WardrobeItemResponse)
def get_wardrobe_item(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    # Ownership guard: User B or anonymous caller cannot access User A's private item
    if item.user_id is not None:
        if current_user is None or current_user.id != item.user_id:
            raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    return _model_to_response(item)


@router.put("/items/{item_id}", response_model=WardrobeItemResponse)
def update_wardrobe_item(
    item_id: str,
    update_data: WardrobeItemUpdate,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    # Ownership guard
    if item.user_id is not None:
        if current_user is None or current_user.id != item.user_id:
            raise HTTPException(status_code=404, detail="Wardrobe item not found.")
    else:
        # Legacy unowned record cannot be claimed or modified by authenticated users
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot modify unowned legacy items.")

    data = update_data.model_dump(exclude_unset=True)
    if "tags" in data and data["tags"] is not None:
        item.tags = json.dumps(data.pop("tags"))

    for key, value in data.items():
        if hasattr(item, key):
            setattr(item, key, value)

    try:
        db.commit()
        db.refresh(item)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database update failed: {str(e)}")

    return _model_to_response(item)


@router.put("/items/{item_id}/photo", response_model=WardrobeItemResponse)
async def update_wardrobe_item_photo(
    item_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    if item.user_id is not None:
        if current_user is None or current_user.id != item.user_id:
            raise HTTPException(status_code=404, detail="Wardrobe item not found.")
    else:
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot modify unowned legacy items.")

    old_public_id = item.cloudinary_public_id or item.image_path
    old_provider = item.storage_provider

    new_meta = await image_storage_service.upload(
        file,
        user_id=item.user_id,
        subfolder="wardrobe",
    )
    item.image_path = new_meta.public_id
    item.storage_provider = new_meta.storage_provider
    item.cloudinary_public_id = new_meta.public_id if new_meta.storage_provider == "cloudinary" else None
    item.image_format = new_meta.format
    item.image_version = new_meta.version

    try:
        db.commit()
        db.refresh(item)
    except Exception as e:
        db.rollback()
        image_storage_service.delete(new_meta.public_id, storage_provider=new_meta.storage_provider)
        raise HTTPException(status_code=500, detail=f"Database photo update failed: {str(e)}")

    if old_public_id and old_public_id != new_meta.public_id:
        image_storage_service.delete(old_public_id, storage_provider=old_provider)

    return _model_to_response(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wardrobe_item(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    # Ownership guard
    if item.user_id is not None:
        if current_user is None or current_user.id != item.user_id:
            raise HTTPException(status_code=404, detail="Wardrobe item not found.")
    else:
        # Legacy unowned record cannot be deleted by authenticated users
        if current_user is not None:
            raise HTTPException(status_code=403, detail="Cannot delete unowned legacy items.")

    # Remove image asset from Cloudinary or local disk
    target_asset = item.cloudinary_public_id or item.image_path
    image_storage_service.delete(target_asset, storage_provider=item.storage_provider)

    db.delete(item)
    db.commit()
    return None


@router.get("/categories")
def get_categories(
    db: Session = Depends(get_db),
    current_user: Optional[AuthenticatedUser] = Depends(get_optional_current_user),
):
    standard_categories = [
        "tops",
        "bottoms",
        "dresses",
        "outerwear",
        "shoes",
        "bags",
        "accessories",
        "other",
    ]
    query = db.query(WardrobeItem.category)
    if current_user:
        query = query.filter(WardrobeItem.user_id == current_user.id)
    else:
        query = query.filter(WardrobeItem.user_id.is_(None))

    counts = {}
    for (cat,) in query.all():
        if cat:
            c = cat.strip().lower()
            counts[c] = counts.get(c, 0) + 1

    # Include standard categories first, then any additional categories with counts
    all_categories = list(standard_categories)
    for cat in counts.keys():
        if cat not in all_categories:
            all_categories.append(cat)

    return [
        {"category": cat, "count": counts.get(cat, 0)}
        for cat in all_categories
    ]


@router.get("/items/{item_id}/listings", response_model=List[CommunityListingResponse])
def get_item_community_listings(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    List all active community shares for a specific personal wardrobe item.
    Scoped strictly to the item owner.
    """
    item = db.query(WardrobeItem).filter(WardrobeItem.id == item_id).first()
    if not item or item.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Wardrobe item not found.")

    listings = (
        db.query(CommunityListing, Community)
        .join(Community, Community.id == CommunityListing.community_id)
        .filter(
            CommunityListing.wardrobe_item_id == item.id,
            CommunityListing.status == "active",
        )
        .all()
    )

    return [
        CommunityListingResponse(
            id=listing.id,
            community_id=comm.id,
            community_name=comm.name,
            wardrobe_item_id=listing.wardrobe_item_id,
            owner_id=listing.owner_id,
            status=listing.status,
            notes=listing.notes,
            created_at=listing.created_at,
            item=_model_to_response(item),
        )
        for listing, comm in listings
    ]
