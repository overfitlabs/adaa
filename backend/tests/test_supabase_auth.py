import io
import time
import pytest
import jwt
from unittest.mock import patch, MagicMock
from app.auth.supabase_auth import SupabaseJWTVerifier, AuthenticatedUser
from app.models import OutfitAnalysisRecord, WardrobeItem


TEST_SECRET = "super-secret-supabase-test-key-32-chars-long!"
TEST_PROJECT_URL = "https://testproject.supabase.co"


def generate_test_jwt(
    sub="usr-12345",
    email="student@campus.edu",
    role="authenticated",
    exp_offset=3600,
    issuer=f"{TEST_PROJECT_URL}/auth/v1",
    audience="authenticated",
    secret=TEST_SECRET,
    alg="HS256",
):
    now = int(time.time())
    payload = {
        "sub": sub,
        "email": email,
        "role": role,
        "iat": now,
        "exp": now + exp_offset,
        "iss": issuer,
        "aud": audience,
    }
    return jwt.encode(payload, secret, algorithm=alg)


def test_jwt_verifier_unconfigured_rejection():
    """Verifier must reject tokens with 401 if Supabase configuration is missing, rather than bypassing."""
    unconfigured_verifier = SupabaseJWTVerifier(supabase_url="", jwt_secret="")
    token = generate_test_jwt()
    with pytest.raises(Exception) as exc_info:
        unconfigured_verifier.verify_token(token)
    assert exc_info.value.status_code == 401
    assert "not configured" in exc_info.value.detail.lower()


def test_jwt_verifier_valid_token():
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    token = generate_test_jwt(sub="user-abc", email="test@domain.com")
    user = verifier.verify_token(token)
    assert isinstance(user, AuthenticatedUser)
    assert user.id == "user-abc"
    assert user.email == "test@domain.com"
    assert user.role == "authenticated"


def test_jwt_verifier_expired_token():
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    expired_token = generate_test_jwt(exp_offset=-100)
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(expired_token)
    assert exc_info.value.status_code == 401
    assert "expired" in exc_info.value.detail.lower()


def test_jwt_verifier_invalid_signature():
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    bad_signature_token = generate_test_jwt(secret="wrong-secret-key-that-does-not-match")
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(bad_signature_token)
    assert exc_info.value.status_code == 401
    assert "signature" in exc_info.value.detail.lower()


def test_jwt_verifier_wrong_issuer():
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    bad_issuer_token = generate_test_jwt(issuer="https://attacker.supabase.co/auth/v1")
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(bad_issuer_token)
    assert exc_info.value.status_code == 401
    assert "issuer" in exc_info.value.detail.lower()


def test_jwt_verifier_wrong_audience():
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    bad_aud_token = generate_test_jwt(audience="wrong_app_audience")
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(bad_aud_token)
    assert exc_info.value.status_code == 401
    assert "audience" in exc_info.value.detail.lower()


def test_jwt_verifier_unsupported_algorithm_rejected():
    """Tokens with alg='none' or unallowed algorithms must be rejected with 401."""
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    # Generate token with unallowed algorithm
    token_none = jwt.encode({"sub": "u-1", "exp": int(time.time()) + 3600}, "", algorithm="none")
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(token_none)
    assert exc_info.value.status_code == 401
    assert "unsupported" in exc_info.value.detail.lower() or "forbidden" in exc_info.value.detail.lower()


def test_jwt_verifier_malformed_token_rejected():
    """Malformed non-JWT strings must be rejected with 401."""
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token("not.a.valid.jwt.token.structure")
    assert exc_info.value.status_code == 401


def test_jwt_verifier_missing_required_claims():
    """Tokens missing required claims (sub, exp) must be rejected with 401."""
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    # Missing 'sub'
    token_missing_sub = jwt.encode(
        {"email": "test@test.com", "exp": int(time.time()) + 3600, "iss": f"{TEST_PROJECT_URL}/auth/v1", "aud": "authenticated"},
        TEST_SECRET,
        algorithm="HS256",
    )
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(token_missing_sub)
    assert exc_info.value.status_code == 401

    # Missing 'exp'
    token_missing_exp = jwt.encode(
        {"sub": "u-1", "iss": f"{TEST_PROJECT_URL}/auth/v1", "aud": "authenticated"},
        TEST_SECRET,
        algorithm="HS256",
    )
    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(token_missing_exp)
    assert exc_info.value.status_code == 401


def test_jwt_verifier_jwks_failure_handling():
    """Asymmetric token where JWKS key retrieval fails must raise 401, not 500."""
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
    mock_jwks = MagicMock()
    mock_jwks.get_signing_key_from_jwt.side_effect = Exception("Network connection to Supabase JWKS timed out")
    verifier.jwks_client = mock_jwks

    # Fake RS256 token
    fake_rs256_token = jwt.encode(
        {"sub": "u-1", "exp": int(time.time()) + 3600, "iss": f"{TEST_PROJECT_URL}/auth/v1", "aud": "authenticated"},
        "dummy-rsa-key",
        algorithm="HS256",  # Encode with HS256 then forge header
    )
    # Forge header to RS256
    import base64, json
    header = base64.urlsafe_b64encode(json.dumps({"alg": "RS256", "typ": "JWT"}).encode()).decode().rstrip("=")
    parts = fake_rs256_token.split(".")
    forged_token = f"{header}.{parts[1]}.{parts[2]}"

    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(forged_token)
    assert exc_info.value.status_code == 401
    assert "unable to find or verify signing key" in exc_info.value.detail.lower()


def test_jwt_verifier_asymmetric_es256_valid_without_jwt_secret():
    """
    Supabase project with ECC P-256 uses asymmetric ES256 signing via JWKS.
    Verification must succeed using the public key and must NOT require SUPABASE_JWT_SECRET.
    """
    from cryptography.hazmat.primitives.asymmetric import ec

    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()

    now = int(time.time())
    token = jwt.encode(
        {
            "sub": "student-es256-uuid",
            "email": "student@campus.edu",
            "role": "authenticated",
            "iat": now,
            "exp": now + 3600,
            "iss": f"{TEST_PROJECT_URL}/auth/v1",
            "aud": "authenticated",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": "faa8abe5-fb8d-449d-a272-23c9ad603e41"},
    )

    # Initialized with NO jwt_secret (empty string)
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret="")
    assert verifier.is_configured is True

    mock_jwks = MagicMock()
    mock_key = MagicMock()
    mock_key.key = public_key
    mock_key.key_id = "faa8abe5-fb8d-449d-a272-23c9ad603e41"
    mock_jwks.get_signing_key.return_value = mock_key
    mock_jwks.get_signing_keys.return_value = [mock_key]
    verifier.jwks_client = mock_jwks

    user = verifier.verify_token(token)
    assert isinstance(user, AuthenticatedUser)
    assert user.id == "student-es256-uuid"
    assert user.email == "student@campus.edu"
    assert user.role == "authenticated"


def test_jwt_verifier_es256_single_key_fallback_when_no_kid():
    """If token lacks 'kid' header, fallback to single key in JWKS if available."""
    from cryptography.hazmat.primitives.asymmetric import ec

    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()

    now = int(time.time())
    token_no_kid = jwt.encode(
        {
            "sub": "student-no-kid",
            "email": "nokid@campus.edu",
            "role": "authenticated",
            "iat": now,
            "exp": now + 3600,
            "iss": f"{TEST_PROJECT_URL}/auth/v1",
            "aud": "authenticated",
        },
        private_key,
        algorithm="ES256",
    )

    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret="")
    mock_jwks = MagicMock()
    mock_key = MagicMock()
    mock_key.key = public_key
    mock_jwks.get_signing_keys.return_value = [mock_key]
    verifier.jwks_client = mock_jwks

    user = verifier.verify_token(token_no_kid)
    assert user.id == "student-no-kid"


def test_jwt_verifier_hs256_rejected_when_jwt_secret_empty():
    """When project is configured for asymmetric signing (jwt_secret is empty), HS256 must be rejected."""
    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret="")
    hs256_token = generate_test_jwt()

    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(hs256_token)
    assert exc_info.value.status_code == 401
    assert "symmetric token (hs256) is disabled" in exc_info.value.detail.lower()


def test_jwt_verifier_es256_expired_token():
    """Expired ES256 token must fail closed with 401."""
    from cryptography.hazmat.primitives.asymmetric import ec

    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()

    now = int(time.time())
    expired_token = jwt.encode(
        {
            "sub": "student-expired",
            "exp": now - 100,
            "iss": f"{TEST_PROJECT_URL}/auth/v1",
            "aud": "authenticated",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": "key-1"},
    )

    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret="")
    mock_jwks = MagicMock()
    mock_key = MagicMock()
    mock_key.key = public_key
    mock_jwks.get_signing_key.return_value = mock_key
    verifier.jwks_client = mock_jwks

    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(expired_token)
    assert exc_info.value.status_code == 401
    assert "expired" in exc_info.value.detail.lower()


def test_jwt_verifier_es256_invalid_signature():
    """ES256 token signed with wrong key must fail closed with 401."""
    from cryptography.hazmat.primitives.asymmetric import ec

    private_key_signer = ec.generate_private_key(ec.SECP256R1())
    private_key_verifier = ec.generate_private_key(ec.SECP256R1())

    now = int(time.time())
    token = jwt.encode(
        {
            "sub": "student-forged",
            "exp": now + 3600,
            "iss": f"{TEST_PROJECT_URL}/auth/v1",
            "aud": "authenticated",
        },
        private_key_signer,
        algorithm="ES256",
        headers={"kid": "key-1"},
    )

    verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret="")
    mock_jwks = MagicMock()
    mock_key = MagicMock()
    mock_key.key = private_key_verifier.public_key()
    mock_jwks.get_signing_key.return_value = mock_key
    verifier.jwks_client = mock_jwks

    with pytest.raises(Exception) as exc_info:
        verifier.verify_token(token)
    assert exc_info.value.status_code == 401
    assert "invalid token signature" in exc_info.value.detail.lower()



def test_api_auth_me_requires_authentication(client):
    """GET /api/auth/me without Authorization header must return 401."""
    res = client.get("/api/auth/me")
    assert res.status_code == 401
    assert "authentication required" in res.json()["detail"].lower()


def test_api_auth_me_with_valid_token(client):
    token = generate_test_jwt(sub="user-777", email="member@university.edu")
    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        res = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200
        data = res.json()
        assert data["user_id"] == "user-777"
        assert data["email"] == "member@university.edu"
        assert data["role"] == "authenticated"


def test_optional_auth_invalid_token_is_strictly_rejected(client, sample_image_bytes):
    """
    CRITICAL SECURITY CHECK:
    If Authorization header is provided with an invalid token,
    it must be rejected with 401, NOT silently downgraded to anonymous!
    """
    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    res = client.post(
        "/api/analysis/analyze-image",
        files=files,
        headers={"Authorization": "Bearer this-is-a-completely-bogus-token"},
    )
    assert res.status_code == 401


def test_optional_auth_empty_bearer_token_rejected(client, sample_image_bytes):
    """
    Supplying an Authorization header with empty/whitespace bearer token
    must fail closed with 401, never downgraded to anonymous.
    """
    files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
    res = client.post(
        "/api/analysis/analyze-image",
        files=files,
        headers={"Authorization": "Bearer   "},
    )
    assert res.status_code == 401


def test_optional_auth_no_token_proceeds_as_anonymous(client, sample_image_bytes):
    """When no Authorization header is present, existing outfit analysis must succeed anonymously."""
    from unittest.mock import AsyncMock, patch, MagicMock
    from app.schemas import DetectedFashionItem, StyleAttributes

    sample_item = DetectedFashionItem(
        id="item-test-anon",
        category="jackets",
        sub_category="Blazer",
        name="Navy Wool Blazer",
        primary_color="Navy",
        attributes=StyleAttributes(material="wool", formality="smart-casual"),
    )

    with patch("app.api.routes_analysis.get_vision_provider") as mock_get_provider:
        mock_provider = MagicMock()
        mock_provider.analyze_outfit_image = AsyncMock(
            return_value=("Tailored outfit", "Minimalist", [sample_item])
        )
        mock_get_provider.return_value = mock_provider

        files = {"file": ("outfit.jpg", io.BytesIO(sample_image_bytes), "image/jpeg")}
        res = client.post("/api/analysis/analyze-image", files=files)
        assert res.status_code == 200
        data = res.json()
        assert data["user_id"] is None


def test_outfit_analysis_user_isolation(client, db_session):
    """
    Test that private analyses belonging to User A cannot be accessed by User B
    or anonymous callers using the direct ID.
    """
    # Create an analysis belonging to user_a
    record_a = OutfitAnalysisRecord(
        user_id="user-a-123",
        image_path="inspirations/user_a_look.jpg",
        summary="User A private outfit",
        vibe="Minimalist",
        items_json="[]",
    )
    # Create an unowned legacy record
    record_legacy = OutfitAnalysisRecord(
        user_id=None,
        image_path="inspirations/legacy_look.jpg",
        summary="Legacy unowned look",
        vibe="Vintage",
        items_json="[]",
    )
    db_session.add_all([record_a, record_legacy])
    db_session.commit()

    token_user_a = generate_test_jwt(sub="user-a-123", email="user_a@test.com")
    token_user_b = generate_test_jwt(sub="user-b-999", email="user_b@test.com")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # User A can access their own record
        res_a = client.get(
            f"/api/analysis/{record_a.id}",
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_a.status_code == 200
        assert res_a.json()["user_id"] == "user-a-123"

        # User B cannot access User A's record (returns 404 to prevent ID probing)
        res_b = client.get(
            f"/api/analysis/{record_a.id}",
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_b.status_code == 404

        # Anonymous caller cannot access User A's private record
        res_anon = client.get(f"/api/analysis/{record_a.id}")
        assert res_anon.status_code == 404

        # Anonymous caller CAN access the unowned legacy record
        res_legacy = client.get(f"/api/analysis/{record_legacy.id}")
        assert res_legacy.status_code == 200
        assert res_legacy.json()["user_id"] is None


def test_wardrobe_item_user_ownership_isolation(client, db_session, sample_image_bytes):
    """
    Test that WardrobeItem endpoints strictly enforce user ownership:
    - User A can create, view, update, delete their own item.
    - User B cannot view, update, or delete User A's item (returns 404).
    - Authenticated users cannot update or delete legacy unowned items (returns 403).
    - Anonymous users see only unowned items, never User A's private item.
    """
    # Create User A item and unowned legacy item
    item_a = WardrobeItem(
        user_id="user-a-456",
        name="User A Cashmere Sweater",
        category="tops",
        primary_color="Cream",
        image_path="wardrobe/sweater_a.jpg",
    )
    item_legacy = WardrobeItem(
        user_id=None,
        name="Legacy Unowned Oxford Shirt",
        category="shirts",
        primary_color="Blue",
        image_path="wardrobe/shirt_legacy.jpg",
    )
    db_session.add_all([item_a, item_legacy])
    db_session.commit()

    token_user_a = generate_test_jwt(sub="user-a-456", email="usera@college.edu")
    token_user_b = generate_test_jwt(sub="user-b-789", email="userb@college.edu")

    with patch("app.auth.supabase_auth.get_jwt_verifier") as mock_get_verifier:
        mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
        mock_get_verifier.return_value = mock_verifier

        # 1. User A can view their item
        res_a = client.get(
            f"/api/wardrobe/items/{item_a.id}",
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_a.status_code == 200
        assert res_a.json()["user_id"] == "user-a-456"

        # 2. User B cannot view User A's item
        res_b = client.get(
            f"/api/wardrobe/items/{item_a.id}",
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_b.status_code == 404

        # 3. User B cannot update User A's item
        res_b_update = client.put(
            f"/api/wardrobe/items/{item_a.id}",
            json={"name": "Hacked Name"},
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_b_update.status_code == 404

        # 4. User B cannot delete User A's item
        res_b_delete = client.delete(
            f"/api/wardrobe/items/{item_a.id}",
            headers={"Authorization": f"Bearer {token_user_b}"},
        )
        assert res_b_delete.status_code == 404

        # 5. List items is properly scoped
        list_a = client.get("/api/wardrobe/items", headers={"Authorization": f"Bearer {token_user_a}"}).json()
        assert any(i["id"] == item_a.id for i in list_a)
        assert not any(i["id"] == item_legacy.id for i in list_a)

        list_b = client.get("/api/wardrobe/items", headers={"Authorization": f"Bearer {token_user_b}"}).json()
        assert not any(i["id"] == item_a.id for i in list_b)

        list_anon = client.get("/api/wardrobe/items").json()
        assert not any(i["id"] == item_a.id for i in list_anon)
        assert any(i["id"] == item_legacy.id for i in list_anon)

        # 6. Authenticated user cannot claim/modify unowned legacy item
        res_claim = client.put(
            f"/api/wardrobe/items/{item_legacy.id}",
            json={"name": "Attempted Claim"},
            headers={"Authorization": f"Bearer {token_user_a}"},
        )
        assert res_claim.status_code == 403


def test_inspiration_image_privacy_and_access_control(client, db_session, sample_image_bytes):
    """
    Verify inspiration image privacy boundaries:
    - Unauthenticated callers CANNOT retrieve private inspiration images (returns 404).
    - User B CANNOT retrieve User A's private inspiration image (returns 404).
    - User A CAN retrieve their own image with Bearer header (returns 200).
    - User A CAN retrieve their own image with ?token= query param (returns 200).
    - Anonymous / legacy unowned images (user_id IS NULL) remain accessible (returns 200).
    - Invalid or expired tokens fail closed (returns 401).
    """
    from app.config import settings

    inspirations_dir = settings.storage_path / "inspirations"
    inspirations_dir.mkdir(parents=True, exist_ok=True)

    file_a = inspirations_dir / "user_a_private.jpg"
    file_legacy = inspirations_dir / "legacy_unowned.jpg"

    file_a.write_bytes(sample_image_bytes)
    file_legacy.write_bytes(sample_image_bytes)

    try:
        # Create private record for user-a
        record_a = OutfitAnalysisRecord(
            user_id="user-a-uuid",
            image_path="inspirations/user_a_private.jpg",
            summary="User A private outfit",
            vibe="Casual",
            items_json="[]",
        )
        # Create unowned legacy record
        record_legacy = OutfitAnalysisRecord(
            user_id=None,
            image_path="inspirations/legacy_unowned.jpg",
            summary="Legacy unowned look",
            vibe="Streetwear",
            items_json="[]",
        )
        db_session.add_all([record_a, record_legacy])
        db_session.commit()

        token_user_a = generate_test_jwt(sub="user-a-uuid", email="user_a@test.com")
        token_user_b = generate_test_jwt(sub="user-b-uuid", email="user_b@test.com")
        expired_token = generate_test_jwt(sub="user-a-uuid", exp_offset=-100)

        with patch("app.api.routes_storage.get_jwt_verifier") as mock_get_verifier:
            mock_verifier = SupabaseJWTVerifier(supabase_url=TEST_PROJECT_URL, jwt_secret=TEST_SECRET)
            mock_get_verifier.return_value = mock_verifier

            # 1. Unauthenticated caller cannot access User A's private image -> 404
            res_anon_a = client.get("/storage/inspirations/user_a_private.jpg")
            assert res_anon_a.status_code == 404

            # 2. User B cannot access User A's private image -> 404
            res_b_a = client.get(
                "/storage/inspirations/user_a_private.jpg",
                headers={"Authorization": f"Bearer {token_user_b}"},
            )
            assert res_b_a.status_code == 404

            # 3. User A can access their own private image via Bearer header -> 200
            res_a_a = client.get(
                "/storage/inspirations/user_a_private.jpg",
                headers={"Authorization": f"Bearer {token_user_a}"},
            )
            assert res_a_a.status_code == 200
            assert res_a_a.headers["content-type"] == "image/jpeg"
            assert "private" in res_a_a.headers.get("cache-control", "")

            # 4. Token in query parameter is strictly rejected / ignored to prevent token leakage (returns 404)
            res_a_query = client.get(f"/storage/inspirations/user_a_private.jpg?token={token_user_a}")
            assert res_a_query.status_code == 404

            # 5. Anonymous caller CAN access unowned legacy image -> 200
            res_anon_leg = client.get("/storage/inspirations/legacy_unowned.jpg")
            assert res_anon_leg.status_code == 200
            assert res_anon_leg.content == sample_image_bytes

            # 6. Authenticated user CAN access unowned legacy image -> 200
            res_user_leg = client.get(
                "/storage/inspirations/legacy_unowned.jpg",
                headers={"Authorization": f"Bearer {token_user_b}"},
            )
            assert res_user_leg.status_code == 200

            # 7. Invalid/expired token fails closed -> 401
            res_expired = client.get(
                "/storage/inspirations/user_a_private.jpg",
                headers={"Authorization": f"Bearer {expired_token}"},
            )
            assert res_expired.status_code == 401

    finally:
        if file_a.exists():
            file_a.unlink()
        if file_legacy.exists():
            file_legacy.unlink()


def test_inspiration_image_path_traversal_and_validation(client, db_session, sample_image_bytes):
    """
    Verify path traversal defenses and filename validation:
    - Path traversal sequences (../, slashes, backslashes) return 400 Bad Request.
    - Unsupported extensions return 400 Bad Request.
    - Non-existent files return 404 Not Found.
    - Untracked files on disk without DB record return 404 Not Found.
    """
    from app.config import settings

    # 1. Path traversal attempts
    res_trav1 = client.get("/storage/inspirations/..%2Fwardrobelens.db")
    assert res_trav1.status_code in (400, 404)

    res_trav2 = client.get("/storage/inspirations/subdir%2Fphoto.jpg")
    assert res_trav2.status_code in (400, 404)

    # 2. Unsupported extension
    res_ext = client.get("/storage/inspirations/malicious.exe")
    assert res_ext.status_code == 400
    assert "unsupported" in res_ext.json()["detail"].lower()

    # 3. Non-existent file
    res_not_found = client.get("/storage/inspirations/non_existent_uuid_123.jpg")
    assert res_not_found.status_code == 404

    # 4. Untracked file on disk without corresponding database record returns 404
    inspirations_dir = settings.storage_path / "inspirations"
    untracked_file = inspirations_dir / "untracked_test_photo.jpg"
    untracked_file.write_bytes(sample_image_bytes)

    try:
        res_untracked = client.get("/storage/inspirations/untracked_test_photo.jpg")
        assert res_untracked.status_code == 404
    finally:
        if untracked_file.exists():
            untracked_file.unlink()

