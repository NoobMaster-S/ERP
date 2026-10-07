from django.contrib import admin
from .models import SyncOutboxLog


@admin.register(SyncOutboxLog)
class SyncOutboxLogAdmin(admin.ModelAdmin):
    list_display = ('idempotency_key', 'business', 'mutation_type', 'entity_type', 'is_success', 'created_at')
    list_filter = ('is_success', 'mutation_type', 'business')
    search_fields = ('idempotency_key', 'client_mutation_id')
