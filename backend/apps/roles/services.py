from django.db import transaction
from .models import Permission, Role, RolePermission
from .constants import ALL_SYSTEM_PERMISSIONS, DEFAULT_ROLES_PERMISSIONS


def seed_system_permissions():
    """
    Ensures all system permission identifiers exist in the database.
    """
    for code, (module, description) in ALL_SYSTEM_PERMISSIONS.items():
        Permission.objects.update_or_create(
            id=code,
            defaults={'module': module, 'description': description}
        )


@transaction.atomic
def initialize_tenant_roles(business):
    """
    Creates standard default roles for a newly registered Business tenant
    and assigns appropriate system permissions. Returns dictionary of created roles.
    """
    seed_system_permissions()
    created_roles = {}

    for role_name, perm_codes in DEFAULT_ROLES_PERMISSIONS.items():
        role, _ = Role.objects.get_or_create(
            business=business,
            name=role_name,
            defaults={
                'description': f"Default {role_name} role for {business.name}",
                'is_system': True,
            }
        )
        created_roles[role_name] = role

        # Assign permissions
        for code in perm_codes:
            perm = Permission.objects.filter(id=code).first()
            if perm:
                RolePermission.objects.get_or_create(role=role, permission=perm)

    return created_roles
