import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.auth.supabase_auth import get_current_user, AuthenticatedUser
from app.schemas import StylistChatRequest, StylistChatResponse
from app.services.adaa_chat_service import AdaaChatService

logger = logging.getLogger("wardrobelens.routes_chat")

router = APIRouter(prefix="/api/stylist", tags=["adaa Conversational Stylist"])


@router.post(
    "/chat",
    response_model=StylistChatResponse,
    summary="Ask adaa - Wardrobe-grounded conversational stylist with strict domain routing",
)
async def chat_with_adaa(
    request: StylistChatRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Authenticated conversational styling session with adaa.
    - Grounded strictly in the authenticated user's digital wardrobe.
    - Enforces fashion-only domain boundaries.
    - Off-topic queries, code requests, and math are redirected without invoking LLMs.
    - Returns structured reply, suggested user garments, acquisition gaps, and valid adaa actions.
    """
    try:
        response = await AdaaChatService.process_chat(
            user_id=current_user.id,
            db=db,
            request=request,
        )
        return response
    except Exception as e:
        logger.exception("Error processing adaa chat: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="adaa styling service encountered a temporary error. Please try again.",
        )
