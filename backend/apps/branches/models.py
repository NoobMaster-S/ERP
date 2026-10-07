from django.db import models
from apps.common.models import TenantModel


class Branch(TenantModel):
    """
    Physical or logical operational branch of a business (e.g. Main Store, Downtown Branch).
    """
    name = models.CharField(max_length=128)
    code = models.CharField(max_length=32, blank=True)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=32, blank=True)
    email = models.EmailField(blank=True)
    is_headquarters = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Branch'
        verbose_name_plural = 'Branches'
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'name'],
                name='uq_business_branch_name'
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.business.name})"


class Warehouse(TenantModel):
    """
    Inventory storage location, bound to a branch and business.
    """
    branch = models.ForeignKey(
        Branch,
        on_delete=models.CASCADE,
        related_name='warehouses',
    )
    name = models.CharField(max_length=128)
    code = models.CharField(max_length=32, blank=True)
    is_default = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Warehouse'
        verbose_name_plural = 'Warehouses'
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'branch', 'name'],
                name='uq_business_branch_warehouse_name'
            )
        ]

    def __str__(self):
        return f"{self.name} - {self.branch.name}"
