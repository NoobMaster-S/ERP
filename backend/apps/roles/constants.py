"""
Granular system permission constants.
Code logic checks these permission codes rather than arbitrary role names.
"""

ALL_SYSTEM_PERMISSIONS = {
    # Users & Team
    'users.view': ('Users', 'View team members and memberships'),
    'users.invite': ('Users', 'Invite new team members'),
    'users.edit': ('Users', 'Modify member roles or branches'),
    'users.deactivate': ('Users', 'Deactivate or remove members'),
    
    # Roles & Permissions
    'roles.view': ('Roles', 'View business roles and permissions'),
    'roles.manage': ('Roles', 'Create and modify custom roles'),
    
    # Branches & Warehouses
    'branches.view': ('Branches', 'View business branches'),
    'branches.manage': ('Branches', 'Create and edit branches'),
    'warehouses.view': ('Warehouses', 'View storage warehouses'),
    'warehouses.manage': ('Warehouses', 'Create and edit warehouses'),
    
    # Products & Inventory Master
    'products.view': ('Products', 'View product catalog and pricing'),
    'products.create': ('Products', 'Create new products, categories, and units'),
    'products.edit': ('Products', 'Update product details and pricing'),
    'products.delete': ('Products', 'Archive/delete products'),
    
    # Inventory Operations
    'inventory.view': ('Inventory', 'View stock levels and movements'),
    'inventory.adjust': ('Inventory', 'Perform stock adjustments and write-offs'),
    'inventory.transfer': ('Inventory', 'Transfer stock between warehouses'),
    
    # Customers
    'customers.view': ('Customers', 'View customer list and balances'),
    'customers.create': ('Customers', 'Add new customer profiles'),
    'customers.edit': ('Customers', 'Update customer details and credit limits'),
    'customers.delete': ('Customers', 'Deactivate customer profiles'),
    
    # Suppliers
    'suppliers.view': ('Suppliers', 'View supplier list and balances'),
    'suppliers.create': ('Suppliers', 'Add new supplier profiles'),
    'suppliers.edit': ('Suppliers', 'Update supplier details'),
    'suppliers.delete': ('Suppliers', 'Deactivate supplier profiles'),
    
    # Sales & POS
    'sales.view': ('Sales', 'View sales records and invoices'),
    'sales.create': ('Sales', 'Create sales orders and POS transactions'),
    'sales.cancel': ('Sales', 'Cancel or void sales transactions'),
    'sales.discount': ('Sales', 'Apply special discounts'),
    
    # Purchases
    'purchases.view': ('Purchases', 'View purchase orders and bills'),
    'purchases.create': ('Purchases', 'Create purchase orders and record receipts'),
    'purchases.cancel': ('Purchases', 'Cancel purchase orders'),
    
    # Payments & Expenses
    'payments.view': ('Payments', 'View payment vouchers'),
    'payments.create': ('Payments', 'Record receipts and outgoing payments'),
    'expenses.view': ('Expenses', 'View operating expenses'),
    'expenses.create': ('Expenses', 'Record new business expenses'),
    
    # Reports
    'reports.sales': ('Reports', 'View sales and revenue reports'),
    'reports.inventory': ('Reports', 'View stock valuation and movement reports'),
    'reports.financial': ('Reports', 'View financial statements and P&L'),
    
    # Settings & Audit
    'settings.view': ('Settings', 'View business settings'),
    'settings.edit': ('Settings', 'Update business configuration'),
    'audit.view': ('Audit', 'Inspect audit logs and system trail'),
}

DEFAULT_ROLES_PERMISSIONS = {
    'Owner': list(ALL_SYSTEM_PERMISSIONS.keys()),
    'Administrator': [
        k for k in ALL_SYSTEM_PERMISSIONS.keys() if k not in ('settings.delete_business',)
    ],
    'Manager': [
        'users.view', 'branches.view', 'warehouses.view',
        'products.view', 'products.create', 'products.edit',
        'inventory.view', 'inventory.adjust', 'inventory.transfer',
        'customers.view', 'customers.create', 'customers.edit',
        'suppliers.view', 'suppliers.create', 'suppliers.edit',
        'sales.view', 'sales.create', 'sales.cancel', 'sales.discount',
        'purchases.view', 'purchases.create',
        'payments.view', 'payments.create',
        'expenses.view', 'expenses.create',
        'reports.sales', 'reports.inventory', 'reports.financial',
        'settings.view', 'audit.view',
    ],
    'Sales Staff': [
        'products.view',
        'inventory.view',
        'customers.view', 'customers.create',
        'sales.view', 'sales.create',
        'payments.create',
    ],
    'Cashier': [
        'products.view',
        'customers.view',
        'sales.view', 'sales.create',
        'payments.create',
    ],
    'Inventory Staff': [
        'products.view', 'products.create', 'products.edit',
        'inventory.view', 'inventory.adjust', 'inventory.transfer',
        'warehouses.view',
        'suppliers.view',
        'purchases.view', 'purchases.create',
    ],
    'Accountant': [
        'customers.view', 'suppliers.view',
        'sales.view', 'purchases.view',
        'payments.view', 'payments.create',
        'expenses.view', 'expenses.create',
        'reports.sales', 'reports.inventory', 'reports.financial',
        'audit.view',
    ],
}
