import logging
from typing import Optional
from fastapi import HTTPException, Request, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt
from jwt import PyJWKClient, PyJWKClientError
from pydantic import BaseModel
from app.config import settings

logger = logging.getLogger("wardrobelens.auth")
security = HTTPBearer(auto_error=False)


class AuthenticatedUser(BaseModel):
    id: str
    email: str = ""
    role: str = "authenticated"


class SupabaseJWTVerifier:
    def __init__(
        self,
        supabase_url: Optional[str] = None,
        jwt_secret: Optional[str] = None,
        audience: str = "authenticated",
        allow_legacy_hs256: bool = True,
    ):
        self.supabase_url = (supabase_url or "").strip().rstrip("/")
        self.jwt_secret = (jwt_secret or "").strip()
        self.expected_audience = audience
        self.expected_issuer = f"{self.supabase_url}/auth/v1" if self.supabase_url else None
        self.allow_legacy_hs256 = allow_legacy_hs256

        self.jwks_client: Optional[PyJWKClient] = None
        if self.supabase_url:
            jwks_url = f"{self.expected_issuer}/.well-known/jwks.json"
            try:
                self.jwks_client = PyJWKClient(
                    jwks_url,
                    headers={"User-Agent": "WardrobeLens-Backend/1.0"},
                    timeout=10,
                    cache_jwk_set=True,
                    lifespan=3600,
                )
            except Exception as e:
                logger.warning("Could not initialize JWKS client for %s: %s", jwks_url, str(e))

    @property
    def is_configured(self) -> bool:
        """
        Returns True if asymmetric JWKS (SUPABASE_URL) or symmetric legacy (SUPABASE_JWT_SECRET) is set.
        Note: For asymmetric ES256/RS256, SUPABASE_JWT_SECRET is NOT required.
        """
        return bool(self.supabase_url or self.jwt_secret)

    def verify_token(self, token: str) -> AuthenticatedUser:
        if not self.is_configured:
            logger.error("Rejecting token verification: Supabase authentication is not configured on the server.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication service is not configured to verify tokens.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not token or not token.strip():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Empty or missing token.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        token_clean = token.strip()

        try:
            unverified_header = jwt.get_unverified_header(token_clean)
            alg = unverified_header.get("alg")
        except Exception as e:
            logger.warning("Failed to parse JWT header: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Malformed authorization token header.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        ALLOWED_ALGORITHMS = {"ES256", "RS256", "HS256"}
        if alg not in ALLOWED_ALGORITHMS:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Unsupported or forbidden token signing algorithm: '{alg}'. Expected asymmetric ES256 (ECC P-256).",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Resolve signing key based on algorithm
        key = None
        if alg in ("ES256", "RS256"):
            # Asymmetric verification via public JWKS endpoint: does NOT require SUPABASE_JWT_SECRET
            if not self.jwks_client:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Asymmetric token ({alg}) supplied but JWKS client is not configured (missing SUPABASE_URL).",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            try:
                kid = unverified_header.get("kid")
                if kid:
                    signing_key = self.jwks_client.get_signing_key(kid)
                else:
                    # If token lacks kid in header, check if JWKS has a single active key
                    signing_keys = self.jwks_client.get_signing_keys()
                    if len(signing_keys) == 1:
                        signing_key = signing_keys[0]
                    else:
                        signing_key = self.jwks_client.get_signing_key_from_jwt(token_clean)
                key = signing_key.key
            except Exception as e:
                logger.warning("JWKS key lookup failed for %s token (kid=%s): %s", alg, unverified_header.get("kid"), str(e))
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Unable to find or verify signing key for token: {str(e)}",
                    headers={"WWW-Authenticate": "Bearer"},
                )
        elif alg == "HS256":
            # Legacy symmetric verification strictly isolated: requires explicit SUPABASE_JWT_SECRET
            if not self.allow_legacy_hs256 or not self.jwt_secret:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Symmetric token (HS256) is disabled. Project uses asymmetric ES256 (ECC P-256) signing via JWKS.",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            key = self.jwt_secret

        # Enforce required claims including issuer, audience, subject, and expiration
        required_claims = ["exp", "sub"]
        if self.expected_issuer:
            required_claims.append("iss")
        if self.expected_audience:
            required_claims.append("aud")

        decode_kwargs = {
            "algorithms": [alg],
            "options": {"require": required_claims},
        }
        if self.expected_audience:
            decode_kwargs["audience"] = self.expected_audience
        if self.expected_issuer:
            decode_kwargs["issuer"] = self.expected_issuer

        try:
            payload = jwt.decode(token_clean, key, **decode_kwargs)
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidIssuerError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token issuer does not match configured Supabase project.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidAudienceError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token audience does not match expected audience.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token signature.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidTokenError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid authorization token: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )

        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is missing required 'sub' subject claim.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return AuthenticatedUser(
            id=str(user_id),
            email=str(payload.get("email", "")),
            role=str(payload.get("role", "authenticated")),
        )


_verifier_instance: Optional[SupabaseJWTVerifier] = None
_cached_config: tuple = ()


def get_jwt_verifier() -> SupabaseJWTVerifier:
    global _verifier_instance, _cached_config
    current_config = (settings.SUPABASE_URL, settings.SUPABASE_JWT_SECRET, settings.SUPABASE_AUDIENCE)
    if _verifier_instance is None or _cached_config != current_config:
        _cached_config = current_config
        _verifier_instance = SupabaseJWTVerifier(
            supabase_url=settings.SUPABASE_URL,
            jwt_secret=settings.SUPABASE_JWT_SECRET,
            audience=settings.SUPABASE_AUDIENCE,
        )
    return _verifier_instance


async def get_optional_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
) -> Optional[AuthenticatedUser]:
    """
    Dependency for endpoints that work for both anonymous and authenticated users.
    - If NO Authorization header is supplied: returns None (proceed as anonymous).
    - If Authorization header IS supplied: strictly verifies it. If invalid or empty, raises 401 Unauthorized.
      (Never silently downgrade an invalid/expired/empty token to anonymous).
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        return None

    if credentials is None or not credentials.credentials or not credentials.credentials.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty or malformed bearer token in Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    verifier = get_jwt_verifier()
    return verifier.verify_token(credentials.credentials.strip())


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
) -> AuthenticatedUser:
    """
    Dependency for endpoints that strictly require an authenticated Supabase user.
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required. Please provide a valid Bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    verifier = get_jwt_verifier()
    return verifier.verify_token(credentials.credentials)
