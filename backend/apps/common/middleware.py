import uuid
from django.utils.deprecation import MiddlewareMixin
from django.contrib.auth.models import AnonymousUser
from apps.authentication.jwt_utils import decode_jwt_token
from apps.businesses.models import Business, BusinessUser
from apps.common.permissions import get_user_tenant_permissions


class TenantContextMiddleware(MiddlewareMixin):
    """
    Middleware that inspects incoming requests, decodes Bearer JWT tokens,
    resolves the active User and Business tenant, and populates:
      - request.user
      - request.tenant
      - request.permissions (set of permission strings)
    """

    def process_request(self, request):
        request.tenant = None
        request.permissions = set()

        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return

        token = auth_header[7:].strip()
        payload = decode_jwt_token(token)
        if not payload:
            return

        # Resolve user
        from apps.authentication.models import User
        user_id = payload.get('sub')
        if not user_id:
            return

        try:
            user = User.objects.get(id=user_id, is_active=True)
            request.user = user
        except User.DoesNotExist:
            request.user = AnonymousUser()
            return

        # Resolve business tenant from X-Business-ID header or token tenant_id claim
        tenant_id_header = request.headers.get('X-Business-ID')
        tenant_id = tenant_id_header or payload.get('tenant_id')

        if tenant_id:
            try:
                business_uuid = uuid.UUID(str(tenant_id))
                # Validate user membership in requested tenant (unless platform admin)
                if user.is_platform_admin or user.is_superuser:
                    business = Business.objects.filter(id=business_uuid, is_active=True).first()
                else:
                    business = Business.objects.filter(
                        id=business_uuid,
                        is_active=True,
                        memberships__user=user,
                        memberships__is_active=True,
                    ).first()

                if business:
                    request.tenant = business
                    request.permissions = get_user_tenant_permissions(user, business)
            except (ValueError, TypeError):
                pass
