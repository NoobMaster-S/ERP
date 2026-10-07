import uuid
from datetime import datetime, timezone, timedelta
import jwt
from django.conf import settings
from .exceptions_local import InvalidTokenError


def create_access_token(user, tenant=None, permissions=None) -> str:
    """
    Mints a short-lived cryptographically signed JWT access token.
    """
    now = datetime.now(timezone.utc)
    exp = now + settings.ACCESS_TOKEN_LIFETIME

    perm_list = list(permissions) if permissions else []

    payload = {
        'sub': str(user.id),
        'email': user.email,
        'is_platform_admin': bool(getattr(user, 'is_platform_admin', False)),
        'tenant_id': str(tenant.id) if tenant else None,
        'permissions': perm_list,
        'iat': int(now.timestamp()),
        'exp': int(exp.timestamp()),
        'jti': str(uuid.uuid4()),
        'type': 'access',
    }

    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user, device_id: str = None) -> str:
    """
    Mints a long-lived JWT refresh token with unique jti.
    """
    now = datetime.now(timezone.utc)
    exp = now + settings.REFRESH_TOKEN_LIFETIME

    payload = {
        'sub': str(user.id),
        'device_id': device_id or str(uuid.uuid4()),
        'iat': int(now.timestamp()),
        'exp': int(exp.timestamp()),
        'jti': str(uuid.uuid4()),
        'type': 'refresh',
    }

    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_jwt_token(token: str) -> dict:
    """
    Decodes and validates a JWT token signature and expiration.
    Returns decoded claims dict, or None on failure.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None
