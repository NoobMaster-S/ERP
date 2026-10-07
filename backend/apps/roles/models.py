from django.db import models
# pyrefly: ignore [missing-import]
from apps.common.models import BaseModel


class Permission(models.Model):
    """
    Granular permission identifier (e.g. 'sales.create', 'inventory.adjust').
    """
    id = models.CharField(max_length=64, primary_key=True)
    module = models.CharField(max_length=32, db_index=True)
    description = models.CharField(max_length=255)

    class Meta:
        verbose_name = 'Permission'
        verbose_name_plural = 'Permissions'
        ordering = ['module', 'id']

    def __str__(self):
        return f"{self.id} ({self.module})"


class Role(BaseModel):
    """
    Named collection of permissions.
    If business is NULL, the role is a global system template.
    If business is set, the role belongs exclusively to that tenant.
    """
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='roles',
        db_index=True,
    )
    name = models.CharField(max_length=64)
    description = models.TextField(blank=True)
    is_system = models.BooleanField(
        default=False,
        help_text='System default roles cannot be deleted.'
    )

    class Meta:
        verbose_name = 'Role'
        verbose_name_plural = 'Roles'
        ordering = ['name']
        constraints = [
            models.UniqueConstraint(
                fields=['business', 'name'],
                name='uq_business_role_name'
            )
        ]

    def __str__(self):
        tenant_str = self.business.name if self.business else "Global Template"
        return f"{self.name} [{tenant_str}]"


class RolePermission(BaseModel):
    """
    Join table linking a Role to its granted Permissions.
    """
    role = models.ForeignKey(
        Role,
        on_delete=models.CASCADE,
        related_name='role_permissions',
    )
    permission = models.ForeignKey(
        Permission,
        on_delete=models.CASCADE,
        related_name='roles',
    )

    class Meta:
        verbose_name = 'Role Permission'
        verbose_name_plural = 'Role Permissions'
        constraints = [
            models.UniqueConstraint(
                fields=['role', 'permission'],
                name='uq_role_permission'
            )
        ]

    def __str__(self):
        return f"{self.role.name} -> {self.permission.id}"
