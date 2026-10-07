import uuid
from django.db import models


class BaseModel(models.Model):
    """
    Abstract base model providing UUID primary key and timestamp tracking.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ['-created_at']


class TenantQuerySet(models.QuerySet):
    """
    QuerySet that automatically scopes queries to a given business.
    """
    def for_tenant(self, business):
        if not business:
            return self.none()
        business_id = getattr(business, 'id', business)
        return self.filter(business_id=business_id)


class TenantManager(models.Manager.from_queryset(TenantQuerySet)):
    """
    Default manager for TenantModel.
    """
    pass


class TenantModel(BaseModel):
    """
    Abstract model for all tenant-owned entities.
    Every tenant record MUST belong to a specific Business.
    """
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        related_name='%(app_label)s_%(class)s_set',
        db_index=True,
    )

    objects = TenantManager()

    class Meta:
        abstract = True
        indexes = [
            models.Index(fields=['business', '-created_at']),
        ]
