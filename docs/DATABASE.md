# Database & Entity Relationship Plan

## 1. Overview & Data Integrity Rules

The ERP platform uses PostgreSQL 16+ as the authoritative source of truth. Every tenant-owned table implements strict relational constraints, UUID primary keys for external visibility, row-level tenant foreign keys, and audit triggers.

### Non-Negotiable Database Rules
1. **Tenant Isolation**: Every tenant-bound table contains a mandatory non-nullable foreign key `business_id REFERENCES businesses_business(id) ON DELETE CASCADE`.
2. **UUID Primary Keys**: All external API identifiers use RFC 4122 version 4 UUIDs to prevent enumeration attacks and simplify offline temporary ID mapping.
3. **Optimistic Locking**: Critical concurrent models (e.g., `Product`, `WarehouseStock`, `Customer`) include an integer `version` field incremented on each mutation to detect concurrency collisions during sync.
4. **Financial Immutability**: Sales, Purchases, Payments, and Invoices operate with append-only transactional accounting. Cancellations and adjustments create compensating ledger entries rather than in-place destructive edits.
5. **Auditing**: An append-only `AuditLog` table records state transitions.

---

## 2. Core Entity Catalog

```text
+---------------------------------------------------------------------------------+
|                                 TENANT CORE                                     |
+---------------------------------------------------------------------------------+
| Business                                                                        |
|  - id (UUID, PK)                                                                |
|  - name (VARCHAR 255)                                                           |
|  - slug (VARCHAR 100, UNIQUE)                                                   |
|  - currency_code (VARCHAR 3, default 'INR')                                     |
|  - currency_symbol (VARCHAR 8, default '₹')                                     |
|  - decimal_places (INT, default 2)                                              |
|  - tax_identification_number (VARCHAR 64)                                       |
|  - address (TEXT)                                                               |
|  - phone (VARCHAR 32)                                                           |
|  - email (VARCHAR 255)                                                          |
|  - is_active (BOOLEAN, default TRUE)                                            |
|  - created_at, updated_at                                                       |
+---------------------------------------------------------------------------------+
| Branch (1..N per Business)                                                      |
|  - id (UUID, PK)                                                                |
|  - business_id (FK -> Business)                                                |
|  - name (VARCHAR 100)                                                           |
|  - code (VARCHAR 32)                                                            |
|  - address, phone, is_headquarters (BOOLEAN)                                    |
+---------------------------------------------------------------------------------+
| Warehouse (1..N per Branch/Business)                                            |
|  - id (UUID, PK)                                                                |
|  - business_id (FK -> Business)                                                |
|  - branch_id (FK -> Branch)                                                     |
|  - name (VARCHAR 100)                                                           |
|  - is_default (BOOLEAN)                                                         |
+---------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------+
|                         IDENTITY & AUTHORIZATION (RBAC)                         |
+---------------------------------------------------------------------------------+
| User                                                                            |
|  - id (UUID, PK)                                                                |
|  - email (VARCHAR 255, UNIQUE)                                                  |
|  - first_name, last_name, phone                                                 |
|  - is_platform_admin (BOOLEAN, default FALSE)                                   |
|  - is_active (BOOLEAN, default TRUE)                                            |
|  - date_joined, last_login                                                      |
+---------------------------------------------------------------------------------+
| Role                                                                            |
|  - id (UUID, PK)                                                                |
|  - business_id (FK -> Business, NULL for system default templates)              |
|  - name (VARCHAR 64)                                                            |
|  - description (TEXT)                                                           |
|  - is_system (BOOLEAN)                                                          |
+---------------------------------------------------------------------------------+
| Permission                                                                      |
|  - id (VARCHAR 64, PK) e.g., 'sales.create', 'products.view'                    |
|  - module (VARCHAR 32) e.g., 'sales', 'inventory'                               |
|  - description (TEXT)                                                           |
+---------------------------------------------------------------------------------+
| RolePermission                                                                  |
|  - role_id (FK -> Role)                                                         |
|  - permission_id (FK -> Permission)                                             |
|  (UNIQUE constraint on role_id, permission_id)                                  |
+---------------------------------------------------------------------------------+
| BusinessUser (Membership)                                                       |
|  - id (UUID, PK)                                                                |
|  - business_id (FK -> Business)                                                |
|  - user_id (FK -> User)                                                         |
|  - role_id (FK -> Role)                                                         |
|  - default_branch_id (FK -> Branch, NULLable)                                   |
|  - is_active (BOOLEAN, default TRUE)                                            |
|  (UNIQUE constraint on business_id, user_id)                                    |
+---------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------+
|                             MASTER DATA CATALOG                                 |
+---------------------------------------------------------------------------------+
| ProductCategory                                                                 |
|  - id (UUID, PK), business_id (FK)                                              |
|  - name (VARCHAR 100), parent_id (FK -> ProductCategory, NULLable)              |
+---------------------------------------------------------------------------------+
| ProductUnit                                                                     |
|  - id (UUID, PK), business_id (FK)                                              |
|  - name (VARCHAR 32), symbol (VARCHAR 16) e.g., 'kg', 'pcs', 'g'                |
+---------------------------------------------------------------------------------+
| Product                                                                         |
|  - id (UUID, PK), business_id (FK)                                              |
|  - name (VARCHAR 255), sku (VARCHAR 64), barcode (VARCHAR 64)                   |
|  - category_id (FK -> ProductCategory)                                          |
|  - unit_id (FK -> ProductUnit)                                                  |
|  - cost_price (DECIMAL 14, 2)                                                   |
|  - selling_price (DECIMAL 14, 2)                                                |
|  - tax_rate (DECIMAL 5, 2)                                                      |
|  - min_stock_threshold (DECIMAL 14, 2)                                          |
|  - is_active (BOOLEAN, default TRUE)                                            |
|  - version (INT, default 1)                                                     |
|  - created_at, updated_at                                                       |
+---------------------------------------------------------------------------------+
| Customer                                                                        |
|  - id (UUID, PK), business_id (FK)                                              |
|  - name, phone, email, tax_id, address                                          |
|  - credit_limit (DECIMAL 14, 2)                                                 |
|  - current_balance (DECIMAL 14, 2)                                              |
|  - is_active (BOOLEAN), version (INT)                                           |
+---------------------------------------------------------------------------------+
| Supplier                                                                        |
|  - id (UUID, PK), business_id (FK)                                              |
|  - name, phone, email, tax_id, address                                          |
|  - current_balance (DECIMAL 14, 2)                                              |
|  - is_active (BOOLEAN), version (INT)                                           |
+---------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------+
|                           TRANSACTIONAL LEDGER                                  |
+---------------------------------------------------------------------------------+
| InventoryMovement                                                               |
|  - id (UUID, PK), business_id (FK)                                              |
|  - product_id (FK -> Product)                                                   |
|  - warehouse_id (FK -> Warehouse)                                               |
|  - movement_type (ENUM: 'PURCHASE', 'SALE', 'ADJUSTMENT', 'TRANSFER_IN', etc.)  |
|  - quantity_delta (DECIMAL 14, 4)                                               |
|  - reference_id (UUID, NULLable)                                                |
|  - notes (TEXT), created_at, created_by_id (FK -> User)                         |
+---------------------------------------------------------------------------------+
| Sale & SaleItem                                                                 |
|  - id (UUID, PK), business_id (FK), branch_id (FK), customer_id (FK)            |
|  - invoice_number (VARCHAR 64, UNIQUE per business) -- Authoritative final seq   |
|  - client_invoice_ref (VARCHAR 64, NULLable) -- Temporary offline device ref     |
|  - total_amount, discount_amount, tax_amount, grand_total, paid_amount          |
|  - payment_status (ENUM: 'PENDING', 'PARTIAL', 'PAID')                          |
|  - idempotency_key (VARCHAR 128, UNIQUE per business)                           |
+---------------------------------------------------------------------------------+
| InvoiceSequenceTracker (Authoritative Server Sequence Generator)                |
|  - id (UUID, PK), business_id (FK), branch_id (FK)                              |
|  - fiscal_year (VARCHAR 16), prefix (VARCHAR 16, default 'INV-')                |
|  - current_sequence (BIGINT, default 0)                                         |
|  - updated_at (TIMESTAMP)                                                       |
|  * Constraint: UNIQUE(business_id, branch_id, fiscal_year, prefix)              |
+---------------------------------------------------------------------------------+
| Payment                                                                         |
|  - id (UUID, PK), business_id (FK)                                              |
|  - payment_type (ENUM: 'CUSTOMER_PAYMENT', 'SUPPLIER_PAYMENT', 'EXPENSE')        |
|  - payment_method (ENUM: 'CASH', 'CARD', 'UPI', 'BANK_TRANSFER', 'CHEQUE')      |
|  - amount (DECIMAL 14, 2), transaction_reference, notes, created_at             |
+---------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------+
|                       SYNC & IDEMPOTENCY ENGINE                                 |
+---------------------------------------------------------------------------------+
| SyncOutboxLog                                                                   |
|  - id (UUID, PK), business_id (FK)                                              |
|  - idempotency_key (VARCHAR 128, UNIQUE per business)                           |
|  - client_mutation_id (VARCHAR 128)                                             |
|  - entity_type (VARCHAR 64)                                                     |
|  - entity_id (UUID)                                                             |
|  - applied_at (TIMESTAMPTZ)                                                     |
|  - response_payload (JSONB)                                                     |
+---------------------------------------------------------------------------------+
| AuditLog                                                                        |
|  - id (UUID, PK), business_id (FK, NULL for platform actions)                   |
|  - user_id (FK -> User, NULLable for system automated jobs)                     |
|  - action (VARCHAR 64) e.g., 'product.price_updated', 'sale.created'            |
|  - entity_name (VARCHAR 64), entity_id (VARCHAR 64)                             |
|  - old_values (JSONB), new_values (JSONB)                                       |
|  - ip_address (INET), user_agent (TEXT), timestamp (TIMESTAMPTZ)                |
+---------------------------------------------------------------------------------+
```

---

## 3. Database Indexes & Constraints Strategy

1. **Compound Multi-Tenant Uniqueness**:
   ```sql
   CREATE UNIQUE INDEX uq_business_product_sku ON products_product(business_id, sku);
   CREATE UNIQUE INDEX uq_business_sale_invoice ON sales_sale(business_id, invoice_number);
   CREATE UNIQUE INDEX uq_business_idempotency ON sync_idempotency(business_id, idempotency_key);
   ```
2. **Performance Query Indexing**:
   ```sql
   CREATE INDEX idx_products_business_name ON products_product(business_id, name);
   CREATE INDEX idx_inventory_product_warehouse ON inventory_inventorymovement(business_id, product_id, warehouse_id);
   CREATE INDEX idx_audit_business_timestamp ON audit_auditlog(business_id, timestamp DESC);
   ```
