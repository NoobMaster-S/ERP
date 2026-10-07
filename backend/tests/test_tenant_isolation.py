from django.test import TestCase
from django.contrib.auth import get_user_model
from apps.businesses.models import Business, BusinessUser
from apps.roles.models import Role, Permission, RolePermission
from apps.branches.models import Branch, Warehouse
from apps.roles.services import initialize_tenant_roles
from apps.common.permissions import get_user_tenant_permissions

User = get_user_model()


class TenantIsolationTestCase(TestCase):
    """
    CRITICAL PROOF TEST:
    Verifies that Business A cannot access, query, or mutate Business B's data under any condition.
    """

    def setUp(self):
        # 1. Create User A and Business A
        self.user_a = User.objects.create_user(
            email='alice@business-a.com',
            password='Password123!',
            first_name='Alice',
            last_name='Smith'
        )
        self.business_a = Business.objects.create(
            name='Alpha Retail Mart',
            slug='alpha-retail',
            business_type='RETAIL',
        )
        roles_a = initialize_tenant_roles(self.business_a)
        self.role_owner_a = roles_a['Owner']

        self.branch_a = Branch.objects.create(
            business=self.business_a,
            name='Alpha Main Branch',
            code='ALPHA-01'
        )
        self.warehouse_a = Warehouse.objects.create(
            business=self.business_a,
            branch=self.branch_a,
            name='Alpha Storage Alpha',
            code='WH-A'
        )
        BusinessUser.objects.create(
            business=self.business_a,
            user=self.user_a,
            role=self.role_owner_a,
            default_branch=self.branch_a
        )

        # 2. Create User B and Business B
        self.user_b = User.objects.create_user(
            email='bob@business-b.com',
            password='Password123!',
            first_name='Bob',
            last_name='Jones'
        )
        self.business_b = Business.objects.create(
            name='Beta Wholesale Depot',
            slug='beta-wholesale',
            business_type='WHOLESALE',
        )
        roles_b = initialize_tenant_roles(self.business_b)
        self.role_owner_b = roles_b['Owner']

        self.branch_b = Branch.objects.create(
            business=self.business_b,
            name='Beta Central Depot',
            code='BETA-01'
        )
        self.warehouse_b = Warehouse.objects.create(
            business=self.business_b,
            branch=self.branch_b,
            name='Beta Vault',
            code='WH-B'
        )
        BusinessUser.objects.create(
            business=self.business_b,
            user=self.user_b,
            role=self.role_owner_b,
            default_branch=self.branch_b
        )

    def test_tenant_data_is_strictly_partitioned(self):
        """Proves that querying for_tenant(A) yields ZERO records belonging to B."""
        # Query branches for Business A
        branches_a = Branch.objects.for_tenant(self.business_a)
        self.assertEqual(branches_a.count(), 1)
        self.assertEqual(branches_a.first().id, self.branch_a.id)

        # Ensure Branch B is nowhere inside branches_a
        self.assertFalse(branches_a.filter(id=self.branch_b.id).exists())

        # Query warehouses for Business B
        warehouses_b = Warehouse.objects.for_tenant(self.business_b)
        self.assertEqual(warehouses_b.count(), 1)
        self.assertEqual(warehouses_b.first().id, self.warehouse_b.id)

        # Ensure Warehouse A is nowhere inside warehouses_b
        self.assertFalse(warehouses_b.filter(id=self.warehouse_a.id).exists())

    def test_user_a_has_no_permissions_in_business_b(self):
        """Proves that User A possesses zero permissions inside Business B."""
        perms_in_b = get_user_tenant_permissions(self.user_a, self.business_b)
        self.assertEqual(len(perms_in_b), 0)

    def test_user_b_has_no_permissions_in_business_a(self):
        """Proves that User B possesses zero permissions inside Business A."""
        perms_in_a = get_user_tenant_permissions(self.user_b, self.business_a)
        self.assertEqual(len(perms_in_a), 0)

    def test_user_cannot_claim_foreign_tenant_membership(self):
        """Validates that membership query with foreign user returns empty."""
        membership = BusinessUser.objects.filter(
            business=self.business_a,
            user=self.user_b,
            is_active=True
        ).first()
        self.assertIsNone(membership)
