import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from app.auth.supabase_auth import get_current_user, AuthenticatedUser

logger = logging.getLogger("wardrobelens.routes_auth")

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


class UserProfileResponse(BaseModel):
    user_id: str
    email: str
    role: str


@router.get("/me", response_model=UserProfileResponse)
def get_current_user_profile(
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Returns the authenticated user's profile verified from their Supabase JWT.
    Strictly requires a valid Supabase Bearer token.
    """
    return UserProfileResponse(
        user_id=current_user.id,
        email=current_user.email,
        role=current_user.role,
    )
