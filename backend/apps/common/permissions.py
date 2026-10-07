from typing import Optional, Set
from .exceptions import PermissionDeniedError, AuthenticationRequiredError, TenantNotFoundError


def get_user_tenant_permissions(user, business) -> Set[str]:
    """
    Computes the set of active permission codes for a user within a specific business.
    """
    if not user or not user.is_authenticated or not business:
        return set()

    # Platform superusers have full authority
    if getattr(user, 'is_platform_admin', False) or user.is_superuser:
        from apps.roles.constants import ALL_SYSTEM_PERMISSIONS
        return set(ALL_SYSTEM_PERMISSIONS.keys())

    # Check business membership
    from apps.businesses.models import BusinessUser
    membership = BusinessUser.objects.filter(
        business=business,
        user=user,
        is_active=True
    ).select_related('role').first()

    if not membership:
        return set()

    role = membership.role
    if not role:
        return set()

    # Query permissions assigned to the role
    permission_ids = set(
        role.role_permissions.values_list('permission_id', flat=True)
    )
    return permission_ids


def require_permission(context, permission_code: str):
    """
    Enforces that the current authenticated user possesses the specified
    permission code within the active tenant context.
    Raises AuthenticationRequiredError, TenantNotFoundError, or PermissionDeniedError.
    """
    user = getattr(context, 'user', None)
    if not user or not user.is_authenticated:
        raise AuthenticationRequiredError()

    # Platform administrators have wildcard access
    if getattr(user, 'is_platform_admin', False) or user.is_superuser:
        return

    tenant = getattr(context, 'tenant', None)
    if not tenant:
        raise TenantNotFoundError("No active business selected or accessible.")

    permissions = getattr(context, 'permissions', None)
    if permissions is None:
        permissions = get_user_tenant_permissions(user, tenant)

    if permission_code not in permissions:
        raise PermissionDeniedError(permission_code=permission_code)
