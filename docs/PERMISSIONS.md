# Roles & Permissions Specification (RBAC)

## 1. Design Principles

1. **Permissions Over Roles**: Business logic and GraphQL resolvers NEVER check for role names (such as "Manager" or "Admin"). Instead, code checks against fine-grained permission codes (such as `sales.create` or `inventory.adjust`).
2. **Multi-Tenant Scoping**: Roles and their permission assignments belong to a specific `business_id` (with pre-seeded standard default templates created on business setup).
3. **Defense in Depth**: Hiding a button in the Flutter UI or Next.js admin is solely for user ergonomics. Every single GraphQL query and mutation independently enforces authentication, tenant context, and permission grants.

---

## 2. Granular Permission Catalog

The platform enforces the following system permission identifiers:

| Module | Permission Code | Description |
| :--- | :--- | :--- |
| **Authentication & Users** | `users.view` | View user list and membership in business |
| | `users.invite` | Invite new team members to business |
| | `users.edit` | Modify member role or branch assignment |
| | `users.deactivate` | Deactivate/remove users from business |
| **Roles** | `roles.view` | Inspect defined roles and permission matrices |
| | `roles.manage` | Create, update, or delete custom business roles |
| **Branches & Warehouses**| `branches.view` | List branches |
| | `branches.manage` | Create and modify branch details |
| | `warehouses.view` | List warehouses |
| | `warehouses.manage` | Create and modify warehouses |
| **Products & Catalog** | `products.view` | Query product catalog, pricing, and stock levels |
| | `products.create` | Create new products, categories, and units |
| | `products.edit` | Update product details, prices, and tax rates |
| | `products.delete` | Soft-delete products |
| **Customers** | `customers.view` | View customers and outstanding balances |
| | `customers.create` | Add new customer profiles |
| | `customers.edit` | Update customer contact and credit limits |
| | `customers.delete` | Deactivate customer records |
| **Suppliers** | `suppliers.view` | View suppliers and payable balances |
| | `suppliers.create` | Add new supplier profiles |
| | `suppliers.edit` | Update supplier details |
| | `suppliers.delete` | Deactivate suppliers |
| **Sales & POS** | `sales.view` | View sales history and invoices |
| | `sales.create` | Create sales orders and POS transactions |
| | `sales.cancel` | Void or cancel completed sales |
| | `sales.discount` | Apply manual discounts exceeding standard policy |
| **Purchases** | `purchases.view` | View purchase orders and bills |
| | `purchases.create` | Create and receive purchase orders |
| | `purchases.cancel` | Cancel purchase records |
| **Inventory** | `inventory.view` | View stock levels and movements across warehouses |
| | `inventory.adjust` | Perform manual stock adjustments and write-offs |
| | `inventory.transfer`| Transfer stock between warehouses or branches |
| **Payments & Expenses** | `payments.view` | View received and issued payment ledgers |
| | `payments.create` | Record customer receipts and supplier payments |
| | `expenses.view` | View operating expenses |
| | `expenses.create` | Record new expense vouchers and receipts |
| **Reports** | `reports.sales` | Generate sales and profitability summaries |
| | `reports.inventory`| Generate stock valuation and low-stock reports |
| | `reports.financial`| Generate P&L, balance sheets, and tax reports |
| **Business Settings** | `settings.view` | View business settings and invoice configurations |
| | `settings.edit` | Edit business profile, currency, taxes, and prefixes |
| **Audit Logs** | `audit.view` | Inspect audit logs and change histories |

---

## 3. Standard Pre-Configured Role Matrix

When a new business tenant is initialized, the following standard template roles are created:

| Role Name | Description | Default Permissions Included |
| :--- | :--- | :--- |
| **Owner** | Full unrestricted business authority | All business permissions (`*`) |
| **Administrator** | Day-to-day operations & configuration | All except destroying business entity |
| **Manager** | Store & inventory management | `sales.*`, `purchases.*`, `inventory.*`, `products.*`, `customers.*`, `suppliers.*`, `payments.*`, `expenses.*`, `reports.*` |
| **Sales Staff** | Frontline POS and sales creation | `sales.view`, `sales.create`, `products.view`, `customers.view`, `customers.create`, `payments.create` |
| **Cashier** | Cash register / POS checkout only | `sales.view`, `sales.create`, `products.view`, `customers.view`, `payments.create` |
| **Inventory Staff** | Stock intake, adjustment, transfer | `products.view`, `inventory.view`, `inventory.adjust`, `inventory.transfer`, `warehouses.view` |
| **Accountant** | Financial oversight and reporting | `payments.*`, `expenses.*`, `sales.view`, `purchases.view`, `reports.*`, `customers.view`, `suppliers.view` |
