import strawberry
from typing import List, Optional
from graphql_api.types import (
    UserType,
    BusinessSummaryType,
    BusinessDetailType,
    RoleType,
    PermissionType,
    BranchType,
    WarehouseType,
    AuditLogType,
    ProductType,
    CategoryType,
    CustomerType,
    SaleType,
    SaleItemType,
)
from apps.common.permissions import require_permission, get_user_tenant_permissions
from apps.common.exceptions import AuthenticationRequiredError, TenantNotFoundError
from apps.businesses.models import Business, BusinessUser
from apps.roles.models import Role, Permission
from apps.branches.models import Branch, Warehouse
from apps.audit.models import AuditLog
from apps.inventory.models import Product, Category
from apps.sales.models import Customer, Sale, SaleItem


@strawberry.type
class Query:
    @strawberry.field
    def me(self, info: strawberry.Info) -> Optional[UserType]:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()
        return UserType(
            id=user.id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            phone=user.phone,
            is_platform_admin=user.is_platform_admin,
        )

    @strawberry.field
    def my_businesses(self, info: strawberry.Info) -> List[BusinessSummaryType]:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()

        memberships = BusinessUser.objects.filter(
            user=user,
            is_active=True,
            business__is_active=True
        ).select_related('business', 'role')

        summaries = []
        for m in memberships:
            perms = list(m.role.role_permissions.values_list('permission_id', flat=True)) if m.role else []
            summaries.append(BusinessSummaryType(
                id=m.business.id,
                name=m.business.name,
                slug=m.business.slug,
                business_type=m.business.business_type,
                role_name=m.role.name if m.role else 'Member',
                permissions=perms,
            ))
        return summaries

    @strawberry.field
    def active_business(self, info: strawberry.Info) -> BusinessDetailType:
        require_permission(info.context, 'settings.view')
        b = info.context.tenant
        return BusinessDetailType(
            id=b.id,
            name=b.name,
            slug=b.slug,
            business_type=b.business_type,
            currency_code=b.currency_code,
            currency_symbol=b.currency_symbol,
            decimal_places=b.decimal_places,
            timezone=b.timezone,
            tax_identification_number=b.tax_identification_number,
            email=b.email,
            phone=b.phone,
            address=b.address,
            invoice_prefix=b.invoice_prefix,
            quotation_prefix=b.quotation_prefix,
            is_active=b.is_active,
            created_at=b.created_at,
        )

    @strawberry.field
    def roles(self, info: strawberry.Info) -> List[RoleType]:
        require_permission(info.context, 'roles.view')
        tenant = info.context.tenant
        qs = Role.objects.filter(business=tenant).prefetch_related('role_permissions')

        results = []
        for r in qs:
            perms = list(r.role_permissions.values_list('permission_id', flat=True))
            results.append(RoleType(
                id=r.id,
                name=r.name,
                description=r.description,
                is_system=r.is_system,
                permissions=perms,
            ))
        return results

    @strawberry.field
    def permissions(self, info: strawberry.Info) -> List[PermissionType]:
        # Available to any authenticated member
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()

        perms = Permission.objects.all().order_by('module', 'id')
        return [
            PermissionType(id=p.id, module=p.module, description=p.description)
            for p in perms
        ]

    @strawberry.field
    def branches(self, info: strawberry.Info) -> List[BranchType]:
        require_permission(info.context, 'branches.view')
        tenant = info.context.tenant
        qs = Branch.objects.filter(business=tenant, is_active=True)
        return [
            BranchType(
                id=b.id,
                name=b.name,
                code=b.code,
                address=b.address,
                phone=b.phone,
                is_headquarters=b.is_headquarters,
                is_active=b.is_active,
            )
            for b in qs
        ]

    @strawberry.field
    def warehouses(self, info: strawberry.Info) -> List[WarehouseType]:
        require_permission(info.context, 'warehouses.view')
        tenant = info.context.tenant
        qs = Warehouse.objects.filter(business=tenant, is_active=True).select_related('branch')
        return [
            WarehouseType(
                id=w.id,
                name=w.name,
                code=w.code,
                branch_id=w.branch.id,
                branch_name=w.branch.name,
                is_default=w.is_default,
                is_active=w.is_active,
            )
            for w in qs
        ]

    @strawberry.field
    def audit_logs(self, info: strawberry.Info, limit: int = 50) -> List[AuditLogType]:
        require_permission(info.context, 'audit.view')
        tenant = info.context.tenant
        qs = AuditLog.objects.filter(business=tenant).select_related('user')[:limit]
        return [
            AuditLogType(
                id=log.id,
                action=log.action,
                entity_type=log.entity_type,
                entity_id=log.entity_id,
                user_email=log.user.email if log.user else 'System',
                created_at=log.created_at,
            )
            for log in qs
        ]

    # Inventory & POS Queries
    @strawberry.field
    def products(self, info: strawberry.Info, search: Optional[str] = None) -> List[ProductType]:
        tenant = info.context.tenant
        if not tenant:
            raise AuthenticationRequiredError()
        qs = Product.objects.filter(business=tenant, is_active=True).select_related('category', 'unit')
        if search:
            qs = qs.filter(name__icontains=search) | qs.filter(sku__icontains=search) | qs.filter(barcode__icontains=search)
        return [
            ProductType(
                id=p.id,
                name=p.name,
                sku=p.sku,
                barcode=p.barcode,
                cost_price=float(p.cost_price),
                selling_price=float(p.selling_price),
                tax_rate=float(p.tax_rate),
                min_stock_threshold=float(p.min_stock_threshold),
                category_id=p.category.id if p.category else None,
                category_name=p.category.name if p.category else None,
                unit_code=p.unit.code if p.unit else 'PCS',
                is_active=p.is_active,
                version=p.version,
            )
            for p in qs
        ]

    @strawberry.field
    def categories(self, info: strawberry.Info) -> List[CategoryType]:
        tenant = info.context.tenant
        if not tenant:
            raise AuthenticationRequiredError()
        qs = Category.objects.filter(business=tenant, is_active=True)
        return [
            CategoryType(
                id=c.id,
                name=c.name,
                slug=c.slug,
                description=c.description,
            )
            for c in qs
        ]

    @strawberry.field
    def customers(self, info: strawberry.Info, search: Optional[str] = None) -> List[CustomerType]:
        tenant = info.context.tenant
        if not tenant:
            raise AuthenticationRequiredError()
        qs = Customer.objects.filter(business=tenant, is_active=True)
        if search:
            qs = qs.filter(name__icontains=search) | qs.filter(phone__icontains=search)
        return [
            CustomerType(
                id=c.id,
                name=c.name,
                phone=c.phone,
                email=c.email,
                current_balance=float(c.current_balance),
                credit_limit=float(c.credit_limit),
            )
            for c in qs
        ]

    @strawberry.field
    def sales(self, info: strawberry.Info, limit: int = 50) -> List[SaleType]:
        tenant = info.context.tenant
        if not tenant:
            raise AuthenticationRequiredError()
        qs = Sale.objects.filter(business=tenant).select_related('customer').prefetch_related('items__product')[:limit]
        return [
            SaleType(
                id=s.id,
                invoice_number=s.invoice_number,
                client_invoice_ref=s.client_invoice_ref,
                subtotal=float(s.subtotal),
                tax_amount=float(s.tax_amount),
                discount_amount=float(s.discount_amount),
                grand_total=float(s.grand_total),
                paid_amount=float(s.paid_amount),
                payment_status=s.payment_status,
                payment_method=s.payment_method,
                created_at=s.created_at,
                customer_name=s.customer.name if s.customer else 'Walk-in Customer',
                items=[
                    SaleItemType(
                        id=item.id,
                        product_id=item.product.id,
                        product_name=item.product.name,
                        quantity=float(item.quantity),
                        unit_price=float(item.unit_price),
                        tax_rate=float(item.tax_rate),
                        discount_amount=float(item.discount_amount),
                        line_total=float(item.line_total),
                    )
                    for item in s.items.all()
                ]
            )
            for s in qs
        ]
