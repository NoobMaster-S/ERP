from django.db import models
from apps.common.models import TenantModel


class SyncOutboxLog(TenantModel):
    """
    Server-side record of ingested client offline outbox mutations.
    Guarantees strict idempotency: identical idempotency_key returns cached response.
    """
    idempotency_key = models.CharField(max_length=128, db_index=True)
    client_mutation_id = models.CharField(max_length=128, blank=True)
    mutation_type = models.CharField(max_length=64)
    entity_type = models.CharField(max_length=64)
    server_entity_id = models.UUIDField(null=True, blank=True)
    response_payload = models.JSONField(default=dict, blank=True)
    is_success = models.BooleanField(default=True)
    error_message = models.TextField(blank=True)

    class Meta:
        verbose_name = 'Sync Outbox Log'
        verbose_name_plural = 'Sync Outbox Logs'
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'idempotency_key'],
                name='uq_tenant_sync_idempotency_key'
            )
        ]

    def __str__(self):
        return f"{self.business.name} | {self.mutation_type} | {self.idempotency_key} ({'OK' if self.is_success else 'ERR'})"
