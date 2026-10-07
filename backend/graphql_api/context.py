from dataclasses import dataclass
from typing import Optional, Set
from django.http import HttpRequest
from apps.authentication.models import User
from apps.businesses.models import Business


@dataclass
class GraphQLContext:
    request: HttpRequest
    user: Optional[User]
    tenant: Optional[Business]
    permissions: Set[str]


def get_context(request: HttpRequest, response=None, **kwargs) -> GraphQLContext:
    return GraphQLContext(
        request=request,
        user=getattr(request, 'user', None),
        tenant=getattr(request, 'tenant', None),
        permissions=getattr(request, 'permissions', set()),
    )
