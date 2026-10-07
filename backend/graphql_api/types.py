import strawberry
from typing import Optional, List
import uuid
from datetime import datetime


@strawberry.type
class PermissionType:
    id: str
    module: str
    description: str


@strawberry.type
class RoleType:
    id: uuid.UUID
    name: str
    description: str
    is_system: bool
    permissions: List[str]


@strawberry.type
class UserType:
    id: uuid.UUID
    email: str
    first_name: str
    last_name: str
    phone: str
    is_platform_admin: bool


@strawberry.type
class BusinessSummaryType:
    id: uuid.UUID
    name: str
    slug: str
    business_type: str
    role_name: str
    permissions: List[str]


@strawberry.type
class BusinessDetailType:
    id: uuid.UUID
    name: str
    slug: str
    business_type: str
    currency_code: str
    currency_symbol: str
    decimal_places: int
    timezone: str
    tax_identification_number: str
    email: str
    phone: str
    address: str
    invoice_prefix: str
    quotation_prefix: str
    is_active: bool
    created_at: datetime


@strawberry.type
class BranchType:
    id: uuid.UUID
    name: str
    code: str
    address: str
    phone: str
    is_headquarters: bool
    is_active: bool


@strawberry.type
class WarehouseType:
    id: uuid.UUID
    name: str
    code: str
    branch_id: uuid.UUID
    branch_name: str
    is_default: bool
    is_active: bool


@strawberry.type
class AuditLogType:
    id: uuid.UUID
    action: str
    entity_type: str
    entity_id: str
    user_email: Optional[str]
    created_at: datetime


@strawberry.type
class AuthPayloadType:
    access_token: str
    refresh_token: str
    user: UserType
    active_business: Optional[BusinessSummaryType]
    available_businesses: List[BusinessSummaryType]


@strawberry.type
class SyncItemResultType:
    idempotency_key: str
    client_mutation_id: str
    is_success: bool
    server_entity_id: Optional[uuid.UUID]
    error_message: Optional[str]


@strawberry.type
class SyncBatchResultType:
    processed_count: int
    results: List[SyncItemResultType]


# Input Types
@strawberry.input
class LoginInput:
    email: str
    password: str
    device_id: Optional[str] = None
    device_name: Optional[str] = "Web Browser"


@strawberry.input
class CreateBusinessInput:
    name: str
    slug: str
    business_type: str = "GENERAL"
    currency_code: str = "INR"
    currency_symbol: str = "₹"
    decimal_places: int = 2
    phone: Optional[str] = ""
    email: Optional[str] = ""
    address: Optional[str] = ""
    tax_identification_number: Optional[str] = ""


@strawberry.input
class SyncItemInput:
    idempotency_key: str
    client_mutation_id: str
    mutation_type: str
    entity_type: str
    payload_json: str


@strawberry.input
class SyncBatchInput:
    items: List[SyncItemInput]


# Inventory & POS Types
@strawberry.type
class CategoryType:
    id: uuid.UUID
    name: str
    slug: str
    description: str


@strawberry.type
class ProductType:
    id: uuid.UUID
    name: str
    sku: str
    barcode: str
    cost_price: float
    selling_price: float
    tax_rate: float
    min_stock_threshold: float
    category_id: Optional[uuid.UUID]
    category_name: Optional[str]
    unit_code: Optional[str]
    is_active: bool
    version: int


@strawberry.type
class CustomerType:
    id: uuid.UUID
    name: str
    phone: str
    email: str
    current_balance: float
    credit_limit: float


@strawberry.type
class SaleItemType:
    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    quantity: float
    unit_price: float
    tax_rate: float
    discount_amount: float
    line_total: float


@strawberry.type
class SaleType:
    id: uuid.UUID
    invoice_number: str
    client_invoice_ref: str
    subtotal: float
    tax_amount: float
    discount_amount: float
    grand_total: float
    paid_amount: float
    payment_status: str
    payment_method: str
    created_at: datetime
    customer_name: Optional[str]
    items: List[SaleItemType]


# Inventory & POS Inputs
@strawberry.input
class CreateProductInput:
    name: str
    sku: Optional[str] = ""
    barcode: Optional[str] = ""
    cost_price: float = 0.0
    selling_price: float = 0.0
    tax_rate: float = 0.0
    category_id: Optional[uuid.UUID] = None
    min_stock_threshold: float = 5.0


@strawberry.input
class CreateCustomerInput:
    name: str
    phone: Optional[str] = ""
    email: Optional[str] = ""
    address: Optional[str] = ""
    credit_limit: float = 0.0
    initial_balance: float = 0.0


@strawberry.input
class SaleItemInput:
    product_id: uuid.UUID
    quantity: float
    unit_price: float
    tax_rate: float = 0.0
    discount_amount: float = 0.0


@strawberry.input
class CreateSaleInput:
    idempotency_key: str
    client_invoice_ref: Optional[str] = ""
    customer_id: Optional[uuid.UUID] = None
    customer_name: Optional[str] = "Walk-in Customer"
    customer_phone: Optional[str] = ""
    discount_amount: float = 0.0
    paid_amount: float = 0.0
    payment_method: str = "CASH"
    items: List[SaleItemInput]
