from django.contrib import admin
from django.urls import path
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from strawberry.django.views import GraphQLView
from graphql_api.schema import schema
from graphql_api.context import get_context


def health_check(request):
    """Liveness and readiness health probe."""
    return JsonResponse({
        'status': 'healthy',
        'service': 'erp-backend',
        'version': '1.0.0',
    })


urlpatterns = [
    path('admin/', admin.site.urls),
    path('healthz/', health_check, name='health_check'),
    path(
        'graphql/',
        csrf_exempt(GraphQLView.as_view(schema=schema, get_context=get_context)),
        name='graphql'
    ),
]
