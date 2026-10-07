import json
import uuid
import strawberry
from django.contrib.auth import authenticate
from django.db import transaction
from django.utils.text import slugify

from graphql_api.types import (
    AuthPayloadType,
    UserType,
    BusinessSummaryType,
    LoginInput,
    RegisterInput,
    CreateBusinessInput,
    SyncBatchInput,
    SyncBatchResultType,
    SyncItemResultType,
    ProductType,
    SaleType,
    SaleItemType,
    CustomerType,
    CreateProductInput,
    CreateCustomerInput,
    CreateSaleInput,
)
from apps.authentication.models import User, UserDeviceSession
from apps.authentication.jwt_utils import (
    create_access_token,
    create_refresh_token,
    decode_jwt_token,
)
from apps.businesses.models import Business, BusinessUser
from apps.roles.services import initialize_tenant_roles
from apps.branches.models import Branch, Warehouse
from apps.audit.services import log_audit_event
from apps.synchronization.models import SyncOutboxLog
from apps.inventory.models import Product, Category, WarehouseStock, StockMovement, MovementType
from apps.sales.models import Customer, Sale, SaleItem, InvoiceSequenceTracker, PaymentStatus, PaymentMethod
from apps.common.exceptions import (
    AuthenticationRequiredError,
    PermissionDeniedError,
    ValidationError,
)
from apps.common.permissions import get_user_tenant_permissions


@strawberry.type
class Mutation:
    @strawberry.mutation
    def login(self, info: strawberry.Info, input: LoginInput) -> AuthPayloadType:
        user = authenticate(email=input.email, password=input.password)
        if not user or not user.is_active:
            raise ValidationError("Invalid email or password.")

        # Find active business memberships
        memberships = BusinessUser.objects.filter(
            user=user,
            is_active=True,
            business__is_active=True
        ).select_related('business', 'role')

        active_membership = memberships.first()
        active_business = active_membership.business if active_membership else None

        permissions = get_user_tenant_permissions(user, active_business) if active_business else set()

        access_token = create_access_token(user, tenant=active_business, permissions=permissions)
        refresh_token = create_refresh_token(user, device_id=input.device_id)

        # Track session
        refresh_payload = decode_jwt_token(refresh_token) or {}
        UserDeviceSession.objects.create(
            user=user,
            device_id=input.device_id or str(uuid.uuid4()),
            device_name=input.device_name or "Client",
            refresh_token_jti=refresh_payload.get('jti', str(uuid.uuid4())),
            ip_address=info.context.request.META.get('REMOTE_ADDR'),
            user_agent=info.context.request.META.get('HTTP_USER_AGENT', ''),
        )

        log_audit_event(
            action='user.login',
            entity_type='User',
            entity_id=str(user.id),
            business=active_business,
            user=user,
            new_values={'device': input.device_name},
            ip_address=info.context.request.META.get('REMOTE_ADDR'),
        )

        all_summaries = []
        for m in memberships:
            m_perms = list(m.role.role_permissions.values_list('permission_id', flat=True)) if m.role else []
            all_summaries.append(BusinessSummaryType(
                id=m.business.id,
                name=m.business.name,
                slug=m.business.slug,
                business_type=m.business.business_type,
                role_name=m.role.name if m.role else 'Member',
                permissions=m_perms,
            ))

        active_summary = None
        if active_business and active_membership:
            active_summary = BusinessSummaryType(
                id=active_business.id,
                name=active_business.name,
                slug=active_business.slug,
                business_type=active_business.business_type,
                role_name=active_membership.role.name if active_membership.role else 'Member',
                permissions=list(permissions),
            )

        return AuthPayloadType(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserType(
                id=user.id,
                email=user.email,
                first_name=user.first_name,
                last_name=user.last_name,
                phone=user.phone,
                is_platform_admin=user.is_platform_admin,
            ),
            active_business=active_summary,
            available_businesses=all_summaries,
        )

    @strawberry.mutation
    @transaction.atomic
    def register(self, info: strawberry.Info, input: RegisterInput) -> AuthPayloadType:
        clean_email = input.email.strip().lower()
        if User.objects.filter(email=clean_email).exists():
            raise ValidationError("A user with this email address already exists.")

        user = User.objects.create_user(
            email=clean_email,
            password=input.password,
            first_name=input.first_name or "",
            last_name=input.last_name or "",
            phone=input.phone or "",
        )

        base_slug = slugify(input.business_name) or "my-business"
        slug = base_slug
        counter = 1
        while Business.objects.filter(slug=slug).exists():
            slug = f"{base_slug}-{counter}"
            counter += 1

        business = Business.objects.create(
            name=input.business_name,
            slug=slug,
            email=clean_email,
            currency_code="INR",
            currency_symbol="₹",
            decimal_places=2,
        )

        roles_dict = initialize_tenant_roles(business)
        owner_role = roles_dict.get('Owner')

        hq_branch = Branch.objects.create(
            business=business,
            name="Main Branch",
            code="HQ",
            is_headquarters=True,
            is_active=True,
        )

        Warehouse.objects.create(
            business=business,
            branch=hq_branch,
            name="Main Warehouse",
            code="WH-MAIN",
            is_default=True,
            is_active=True,
        )

        BusinessUser.objects.create(
            business=business,
            user=user,
            role=owner_role,
            is_active=True,
        )

        permissions = get_user_tenant_permissions(user, business)
        access_token = create_access_token(user, tenant=business, permissions=permissions)
        refresh_token = create_refresh_token(user)

        active_summary = BusinessSummaryType(
            id=business.id,
            name=business.name,
            slug=business.slug,
            business_type=business.business_type,
            role_name="Owner",
            permissions=sorted(list(permissions)),
        )

        return AuthPayloadType(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserType(
                id=user.id,
                email=user.email,
                first_name=user.first_name,
                last_name=user.last_name,
                phone=user.phone,
                is_platform_admin=user.is_platform_admin,
            ),
            active_business=active_summary,
            available_businesses=[active_summary],
        )

    @strawberry.mutation
    def refresh_token(self, info: strawberry.Info, refresh_token: str) -> AuthPayloadType:
        payload = decode_jwt_token(refresh_token)
        if not payload or payload.get('type') != 'refresh':
            raise ValidationError("Invalid or expired refresh token.")

        user_id = payload.get('sub')
        device_id = payload.get('device_id')
        jti = payload.get('jti')

        user = User.objects.filter(id=user_id, is_active=True).first()
        if not user:
            raise ValidationError("User not found or inactive.")

        if jti:
            revoked_session = UserDeviceSession.objects.filter(refresh_token_jti=jti, is_revoked=True).first()
            if revoked_session:
                raise ValidationError("Session has been revoked.")

        memberships = BusinessUser.objects.filter(
            user=user,
            is_active=True,
            business__is_active=True
        ).select_related('business', 'role')

        active_membership = memberships.first()
        active_business = active_membership.business if active_membership else None
        permissions = get_user_tenant_permissions(user, active_business) if active_business else set()

        new_access_token = create_access_token(user, tenant=active_business, permissions=permissions)
        new_refresh_token = create_refresh_token(user, device_id=device_id)

        all_summaries = []
        for m in memberships:
            m_perms = list(m.role.role_permissions.values_list('permission_id', flat=True)) if m.role else []
            all_summaries.append(BusinessSummaryType(
                id=m.business.id,
                name=m.business.name,
                slug=m.business.slug,
                business_type=m.business.business_type,
                role_name=m.role.name if m.role else 'Member',
                permissions=m_perms,
            ))

        active_summary = None
        if active_business and active_membership:
            active_summary = BusinessSummaryType(
                id=active_business.id,
                name=active_business.name,
                slug=active_business.slug,
                business_type=active_business.business_type,
                role_name=active_membership.role.name if active_membership.role else 'Member',
                permissions=list(permissions),
            )

        return AuthPayloadType(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            user=UserType(
                id=user.id,
                email=user.email,
                first_name=user.first_name,
                last_name=user.last_name,
                phone=user.phone,
                is_platform_admin=user.is_platform_admin,
            ),
            active_business=active_summary,
            available_businesses=all_summaries,
        )

    @strawberry.mutation
    @transaction.atomic
    def create_business(self, info: strawberry.Info, input: CreateBusinessInput) -> BusinessSummaryType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()

        base_slug = slugify(input.slug or input.name)
        slug = base_slug
        counter = 1
        while Business.objects.filter(slug=slug).exists():
            slug = f"{base_slug}-{counter}"
            counter += 1

        business = Business.objects.create(
            name=input.name,
            slug=slug,
            business_type=input.business_type,
            currency_code=input.currency_code,
            currency_symbol=input.currency_symbol,
            decimal_places=input.decimal_places,
            phone=input.phone or "",
            email=input.email or "",
            address=input.address or "",
            tax_identification_number=input.tax_identification_number or "",
        )

        # Initialize default roles and assign Owner role to creator
        roles_dict = initialize_tenant_roles(business)
        owner_role = roles_dict.get('Owner')

        # Create Default Headquarters Branch & Main Warehouse
        hq_branch = Branch.objects.create(
            business=business,
            name="Main Branch",
            code="HQ",
            is_headquarters=True,
            is_active=True,
        )

        Warehouse.objects.create(
            business=business,
            branch=hq_branch,
            name="Main Warehouse",
            code="WH-MAIN",
            is_default=True,
            is_active=True,
        )

        # Create membership
        BusinessUser.objects.create(
            business=business,
            user=user,
            role=owner_role,
            default_branch=hq_branch,
            is_active=True,
        )

        log_audit_event(
            action='business.created',
            entity_type='Business',
            entity_id=str(business.id),
            business=business,
            user=user,
            new_values={'name': business.name, 'slug': business.slug},
            ip_address=info.context.request.META.get('REMOTE_ADDR'),
        )

        perms = list(owner_role.role_permissions.values_list('permission_id', flat=True)) if owner_role else []

        return BusinessSummaryType(
            id=business.id,
            name=business.name,
            slug=business.slug,
            business_type=business.business_type,
            role_name=owner_role.name if owner_role else "Owner",
            permissions=perms,
        )

    @strawberry.mutation
    def switch_business(self, info: strawberry.Info, business_id: uuid.UUID) -> AuthPayloadType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()

        membership = BusinessUser.objects.filter(
            user=user,
            business_id=business_id,
            is_active=True,
            business__is_active=True
        ).select_related('business', 'role').first()

        if not membership and not (user.is_platform_admin or user.is_superuser):
            raise PermissionDeniedError("business.access", "You do not have access to this business.")

        target_business = membership.business if membership else Business.objects.get(id=business_id)
        perms = get_user_tenant_permissions(user, target_business)

        access_token = create_access_token(user, tenant=target_business, permissions=perms)
        refresh_token = create_refresh_token(user)

        active_summary = BusinessSummaryType(
            id=target_business.id,
            name=target_business.name,
            slug=target_business.slug,
            business_type=target_business.business_type,
            role_name=membership.role.name if membership and membership.role else "Owner",
            permissions=list(perms),
        )

        return AuthPayloadType(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserType(
                id=user.id,
                email=user.email,
                first_name=user.first_name,
                last_name=user.last_name,
                phone=user.phone,
                is_platform_admin=user.is_platform_admin,
            ),
            active_business=active_summary,
            available_businesses=[active_summary],
        )

    @strawberry.mutation
    @transaction.atomic
    def ingest_sync_batch(self, info: strawberry.Info, input: SyncBatchInput) -> SyncBatchResultType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()

        tenant = info.context.tenant
        if not tenant:
            raise ValidationError("Sync mutations require an active tenant context.")

        item_results = []

        for item in input.items:
            # Check existing idempotency record
            existing = SyncOutboxLog.objects.filter(
                business=tenant,
                idempotency_key=item.idempotency_key
            ).first()

            if existing:
                # Idempotent replay: return cached execution result
                item_results.append(SyncItemResultType(
                    idempotency_key=existing.idempotency_key,
                    client_mutation_id=existing.client_mutation_id,
                    is_success=existing.is_success,
                    server_entity_id=existing.server_entity_id,
                    error_message=existing.error_message or None,
                ))
                continue

            # Process new outbox item
            server_id = uuid.uuid4()
            try:
                parsed_payload = json.loads(item.payload_json) if item.payload_json else {}
                if item.mutation_type == 'CREATE_CUSTOMER' or item.entity_type == 'Customer':
                    c_name = parsed_payload.get('name', '').strip()
                    if c_name:
                        cust = Customer.objects.create(
                            business=tenant,
                            name=c_name,
                            phone=parsed_payload.get('phone', ''),
                            email=parsed_payload.get('email', ''),
                            current_balance=float(parsed_payload.get('initialBalance', 0.0) or 0.0),
                        )
                        server_id = cust.id
                elif item.mutation_type == 'CREATE_PRODUCT' or item.entity_type == 'Product':
                    p_name = parsed_payload.get('name', '').strip()
                    if p_name:
                        prod = Product.objects.create(
                            business=tenant,
                            name=p_name,
                            sku=parsed_payload.get('sku', '') or f"SKU-{uuid.uuid4().hex[:8].upper()}",
                            barcode=parsed_payload.get('barcode', ''),
                            cost_price=float(parsed_payload.get('costPrice', 0.0) or 0.0),
                            selling_price=float(parsed_payload.get('sellingPrice', 0.0) or 0.0),
                        )
                        server_id = prod.id
                elif item.mutation_type == 'CREATE_SALE' or item.entity_type == 'Sale':
                    existing_sale = Sale.objects.filter(
                        business=tenant,
                        idempotency_key=item.idempotency_key
                    ).first()
                    if existing_sale:
                        server_id = existing_sale.id
                    else:
                        branch = Branch.objects.filter(business=tenant, is_headquarters=True).first() or Branch.objects.filter(business=tenant).first()
                        warehouse = Warehouse.objects.filter(business=tenant, is_default=True).first() or Warehouse.objects.filter(business=tenant).first()
                        
                        cust = None
                        c_id = parsed_payload.get('customerId')
                        if c_id:
                            cust = Customer.objects.filter(id=c_id, business=tenant).first()
                        elif parsed_payload.get('customerName') and parsed_payload.get('customerName') != "Walk-in Customer":
                            cust, _ = Customer.objects.get_or_create(
                                business=tenant,
                                name=parsed_payload.get('customerName'),
                                defaults={'phone': parsed_payload.get('customerPhone', '')}
                            )

                        inv_num = InvoiceSequenceTracker.get_next_invoice_number(business=tenant, branch=branch)
                        subtotal = 0.0
                        items_data = parsed_payload.get('items', [])
                        for it in items_data:
                            subtotal += float(it.get('quantity', 1.0)) * float(it.get('unitPrice', 0.0))
                        
                        disc = float(parsed_payload.get('discountAmount', 0.0) or 0.0)
                        grand_total = max(0.0, subtotal - disc)
                        paid = float(parsed_payload.get('paidAmount', grand_total) or grand_total)
                        pay_stat = PaymentStatus.PAID if paid >= grand_total else PaymentStatus.PARTIAL
                        pay_meth = parsed_payload.get('paymentMethod', PaymentMethod.CASH)

                        sale = Sale.objects.create(
                            business=tenant,
                            branch=branch,
                            customer=cust,
                            idempotency_key=item.idempotency_key,
                            invoice_number=inv_num,
                            client_invoice_ref=item.client_mutation_id,
                            subtotal=subtotal,
                            tax_amount=0.0,
                            discount_amount=disc,
                            grand_total=grand_total,
                            paid_amount=paid,
                            payment_status=pay_stat,
                            payment_method=pay_meth,
                            created_by=user,
                        )
                        server_id = sale.id

                        for it in items_data:
                            p_id = it.get('productId')
                            prod = Product.objects.filter(id=p_id, business=tenant).first() if p_id else None
                            if prod:
                                qty = float(it.get('quantity', 1.0))
                                up = float(it.get('unitPrice', prod.sellingPrice))
                                SaleItem.objects.create(
                                    sale=sale,
                                    product=prod,
                                    quantity=qty,
                                    unit_price=up,
                                    tax_rate=0.0,
                                    discount_amount=0.0,
                                    line_total=qty * up,
                                )
                                if warehouse:
                                    wh_stock, _ = WarehouseStock.objects.get_or_create(
                                        business=tenant,
                                        product=prod,
                                        warehouse=warehouse,
                                        defaults={'quantity_on_hand': 0.0}
                                    )
                                    wh_stock.quantity_on_hand = float(wh_stock.quantity_on_hand) - qty
                                    wh_stock.save(update_fields=['quantity_on_hand', 'updated_at'])
                                    StockMovement.objects.create(
                                        business=tenant,
                                        product=prod,
                                        warehouse=warehouse,
                                        movement_type=MovementType.SALE,
                                        quantity_delta=-qty,
                                        reference_id=inv_num,
                                        notes=f"Synced Offline POS Sale Invoice #{inv_num}",
                                        created_by=user,
                                    )

                SyncOutboxLog.objects.create(
                    business=tenant,
                    idempotency_key=item.idempotency_key,
                    client_mutation_id=item.client_mutation_id,
                    mutation_type=item.mutation_type,
                    entity_type=item.entity_type,
                    server_entity_id=server_id,
                    response_payload=parsed_payload,
                    is_success=True,
                )
                item_results.append(SyncItemResultType(
                    idempotency_key=item.idempotency_key,
                    client_mutation_id=item.client_mutation_id,
                    is_success=True,
                    server_entity_id=server_id,
                    error_message=None,
                ))
            except Exception as e:
                SyncOutboxLog.objects.create(
                    business=tenant,
                    idempotency_key=item.idempotency_key,
                    client_mutation_id=item.client_mutation_id,
                    mutation_type=item.mutation_type,
                    entity_type=item.entity_type,
                    is_success=False,
                    error_message=str(e),
                )
                item_results.append(SyncItemResultType(
                    idempotency_key=item.idempotency_key,
                    client_mutation_id=item.client_mutation_id,
                    is_success=False,
                    server_entity_id=None,
                    error_message=str(e),
                ))

        return SyncBatchResultType(
            processed_count=len(item_results),
            results=item_results,
        )

    @strawberry.mutation
    @transaction.atomic
    def create_product(self, info: strawberry.Info, input: CreateProductInput) -> ProductType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()
        tenant = info.context.tenant
        if not tenant:
            raise ValidationError("Creating a product requires an active business context.")

        category = None
        if input.category_id:
            category = Category.objects.filter(id=input.category_id, business=tenant).first()

        sku = input.sku or f"SKU-{uuid.uuid4().hex[:8].upper()}"

        product = Product.objects.create(
            business=tenant,
            name=input.name,
            sku=sku,
            barcode=input.barcode or "",
            cost_price=input.cost_price,
            selling_price=input.selling_price,
            tax_rate=input.tax_rate,
            min_stock_threshold=input.min_stock_threshold,
            category=category,
        )

        # Ensure main warehouse has a stock row
        main_wh = Warehouse.objects.filter(business=tenant, is_default=True).first()
        if not main_wh:
            main_wh = Warehouse.objects.filter(business=tenant).first()
        if main_wh:
            WarehouseStock.objects.get_or_create(
                business=tenant,
                product=product,
                warehouse=main_wh,
                defaults={'quantity_on_hand': 100.0}
            )

        return ProductType(
            id=product.id,
            name=product.name,
            sku=product.sku,
            barcode=product.barcode,
            cost_price=float(product.cost_price),
            selling_price=float(product.selling_price),
            tax_rate=float(product.tax_rate),
            min_stock_threshold=float(product.min_stock_threshold),
            category_id=product.category.id if product.category else None,
            category_name=product.category.name if product.category else None,
            unit_code='PCS',
            is_active=product.is_active,
            version=product.version,
        )

    @strawberry.mutation
    @transaction.atomic
    def create_customer(self, info: strawberry.Info, input: CreateCustomerInput) -> CustomerType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()
        tenant = info.context.tenant
        if not tenant:
            raise ValidationError("Creating a customer requires an active business context.")
        if not input.name or not input.name.strip():
            raise ValidationError("Customer name cannot be empty.")

        customer = Customer.objects.create(
            business=tenant,
            name=input.name.strip(),
            phone=input.phone.strip() if input.phone else "",
            email=input.email.strip() if input.email else "",
            address=input.address.strip() if input.address else "",
            credit_limit=input.credit_limit,
            current_balance=input.initial_balance,
        )

        return CustomerType(
            id=customer.id,
            name=customer.name,
            phone=customer.phone,
            email=customer.email,
            current_balance=float(customer.current_balance),
            credit_limit=float(customer.credit_limit),
        )

    @strawberry.mutation
    @transaction.atomic
    def create_sale(self, info: strawberry.Info, input: CreateSaleInput) -> SaleType:
        user = info.context.user
        if not user or not user.is_authenticated:
            raise AuthenticationRequiredError()
        tenant = info.context.tenant
        if not tenant:
            raise ValidationError("Sale requires an active business context.")

        # Idempotency check: if sale already exists for this idempotency_key, return it
        existing_sale = Sale.objects.filter(
            business=tenant,
            idempotency_key=input.idempotency_key
        ).select_related('customer').prefetch_related('items__product').first()

        if existing_sale:
            return SaleType(
                id=existing_sale.id,
                invoice_number=existing_sale.invoice_number,
                client_invoice_ref=existing_sale.client_invoice_ref,
                subtotal=float(existing_sale.subtotal),
                tax_amount=float(existing_sale.tax_amount),
                discount_amount=float(existing_sale.discount_amount),
                grand_total=float(existing_sale.grand_total),
                paid_amount=float(existing_sale.paid_amount),
                payment_status=existing_sale.payment_status,
                payment_method=existing_sale.payment_method,
                created_at=existing_sale.created_at,
                customer_name=existing_sale.customer.name if existing_sale.customer else 'Walk-in Customer',
                items=[
                    SaleItemType(
                        id=it.id,
                        product_id=it.product.id,
                        product_name=it.product.name,
                        quantity=float(it.quantity),
                        unit_price=float(it.unit_price),
                        tax_rate=float(it.tax_rate),
                        discount_amount=float(it.discount_amount),
                        line_total=float(it.line_total),
                    )
                    for it in existing_sale.items.all()
                ]
            )

        # Get default branch & warehouse
        branch = Branch.objects.filter(business=tenant, is_headquarters=True).first()
        if not branch:
            branch = Branch.objects.filter(business=tenant).first()
        warehouse = Warehouse.objects.filter(business=tenant, is_default=True).first()
        if not warehouse:
            warehouse = Warehouse.objects.filter(business=tenant).first()

        # Customer handling
        customer = None
        if input.customer_id:
            customer = Customer.objects.filter(id=input.customer_id, business=tenant).first()
        elif input.customer_name and input.customer_name != "Walk-in Customer":
            customer, _ = Customer.objects.get_or_create(
                business=tenant,
                name=input.customer_name,
                defaults={'phone': input.customer_phone or ''}
            )

        # Generate authoritative sequential invoice number
        invoice_number = InvoiceSequenceTracker.get_next_invoice_number(business=tenant, branch=branch)

        # Calculate totals
        subtotal = 0.0
        tax_total = 0.0
        sale_items_data = []

        for item_in in input.items:
            prod = Product.objects.filter(id=item_in.product_id, business=tenant).first()
            if not prod:
                raise ValidationError(f"Product {item_in.product_id} not found in this business.")
            line_subtotal = (item_in.quantity * item_in.unit_price) - item_in.discount_amount
            line_tax = line_subtotal * (item_in.tax_rate / 100.0)
            line_total = line_subtotal + line_tax
            subtotal += line_subtotal
            tax_total += line_tax
            sale_items_data.append({
                'product': prod,
                'quantity': item_in.quantity,
                'unit_price': item_in.unit_price,
                'tax_rate': item_in.tax_rate,
                'discount_amount': item_in.discount_amount,
                'line_total': line_total,
            })

        grand_total = subtotal + tax_total - input.discount_amount

        # Payment status
        if input.payment_method == PaymentMethod.CREDIT:
            payment_status = PaymentStatus.PENDING if input.paid_amount == 0 else PaymentStatus.PARTIAL
        elif input.paid_amount >= grand_total:
            payment_status = PaymentStatus.PAID
        elif input.paid_amount > 0:
            payment_status = PaymentStatus.PARTIAL
        else:
            payment_status = PaymentStatus.PENDING

        # Update customer balance if credit / unpaid
        unpaid_amount = grand_total - input.paid_amount
        if customer and unpaid_amount > 0:
            customer.current_balance = float(customer.current_balance) + unpaid_amount
            customer.save(update_fields=['current_balance', 'updated_at'])

        # Create Sale
        sale = Sale.objects.create(
            business=tenant,
            branch=branch,
            customer=customer,
            invoice_number=invoice_number,
            client_invoice_ref=input.client_invoice_ref or "",
            subtotal=subtotal,
            tax_amount=tax_total,
            discount_amount=input.discount_amount,
            grand_total=grand_total,
            paid_amount=input.paid_amount,
            payment_status=payment_status,
            payment_method=input.payment_method,
            idempotency_key=input.idempotency_key,
            created_by=user,
        )

        created_items = []
        for item_dict in sale_items_data:
            s_item = SaleItem.objects.create(
                sale=sale,
                product=item_dict['product'],
                quantity=item_dict['quantity'],
                unit_price=item_dict['unit_price'],
                tax_rate=item_dict['tax_rate'],
                discount_amount=item_dict['discount_amount'],
                line_total=item_dict['line_total'],
            )
            created_items.append(SaleItemType(
                id=s_item.id,
                product_id=s_item.product.id,
                product_name=s_item.product.name,
                quantity=float(s_item.quantity),
                unit_price=float(s_item.unit_price),
                tax_rate=float(s_item.tax_rate),
                discount_amount=float(s_item.discount_amount),
                line_total=float(s_item.line_total),
            ))

            # Deduct inventory stock
            if warehouse:
                wh_stock, _ = WarehouseStock.objects.get_or_create(
                    business=tenant,
                    product=item_dict['product'],
                    warehouse=warehouse,
                    defaults={'quantity_on_hand': 0.0}
                )
                wh_stock.quantity_on_hand = float(wh_stock.quantity_on_hand) - item_dict['quantity']
                wh_stock.save(update_fields=['quantity_on_hand', 'updated_at'])

                StockMovement.objects.create(
                    business=tenant,
                    product=item_dict['product'],
                    warehouse=warehouse,
                    movement_type=MovementType.SALE,
                    quantity_delta=-item_dict['quantity'],
                    reference_id=sale.invoice_number,
                    notes=f"POS Sale Invoice #{sale.invoice_number}",
                    created_by=user,
                )

        # Also log sync outbox idempotent record
        SyncOutboxLog.objects.create(
            business=tenant,
            idempotency_key=input.idempotency_key,
            client_mutation_id=input.client_invoice_ref or str(sale.id),
            mutation_type="CREATE",
            entity_type="Sale",
            server_entity_id=sale.id,
            response_payload={
                "invoice_number": sale.invoice_number,
                "client_invoice_ref": sale.client_invoice_ref,
                "grand_total": float(sale.grand_total),
            },
            is_success=True,
        )

        return SaleType(
            id=sale.id,
            invoice_number=sale.invoice_number,
            client_invoice_ref=sale.client_invoice_ref,
            subtotal=float(sale.subtotal),
            tax_amount=float(sale.tax_amount),
            discount_amount=float(sale.discount_amount),
            grand_total=float(sale.grand_total),
            paid_amount=float(sale.paid_amount),
            payment_status=sale.payment_status,
            payment_method=sale.payment_method,
            created_at=sale.created_at,
            customer_name=sale.customer.name if sale.customer else 'Walk-in Customer',
            items=created_items,
        )
