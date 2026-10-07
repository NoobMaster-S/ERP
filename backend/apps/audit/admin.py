from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('action', 'entity_type', 'entity_id', 'business', 'user', 'ip_address', 'created_at')
    list_filter = ('action', 'entity_type', 'business')
    search_fields = ('action', 'entity_type', 'entity_id', 'user__email')
    readonly_fields = ('id', 'business', 'user', 'action', 'entity_type', 'entity_id', 'old_values', 'new_values', 'ip_address', 'user_agent', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
