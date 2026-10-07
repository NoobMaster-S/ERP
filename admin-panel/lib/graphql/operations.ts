export const LOGIN_MUTATION = `
  mutation Login($input: LoginInput!) {
    login(input: $input) {
      accessToken
      refreshToken
      user {
        id
        email
        firstName
        lastName
        isPlatformAdmin
      }
      activeBusiness {
        id
        name
        slug
        businessType
        roleName
        permissions
      }
      availableBusinesses {
        id
        name
        slug
        businessType
        roleName
        permissions
      }
    }
  }
`;

export const CREATE_BUSINESS_MUTATION = `
  mutation CreateBusiness($input: CreateBusinessInput!) {
    createBusiness(input: $input) {
      id
      name
      slug
      businessType
      roleName
      permissions
    }
  }
`;

export const GET_MY_BUSINESSES = `
  query GetMyBusinesses {
    myBusinesses {
      id
      name
      slug
      businessType
      roleName
      permissions
    }
  }
`;

export const GET_ROLES = `
  query GetRoles {
    roles {
      id
      name
      description
      isSystem
      permissions
    }
  }
`;

export const GET_PERMISSIONS = `
  query GetPermissions {
    permissions {
      id
      module
      description
    }
  }
`;

export const GET_BRANCHES = `
  query GetBranches {
    branches {
      id
      name
      code
      address
      phone
      isHeadquarters
      isActive
    }
  }
`;

export const GET_AUDIT_LOGS = `
  query GetAuditLogs($limit: Int) {
    auditLogs(limit: $limit) {
      id
      action
      entityType
      entityId
      userEmail
      createdAt
    }
  }
`;

export const GET_PRODUCTS = `
  query GetProducts($search: String) {
    products(search: $search) {
      id
      name
      sku
      barcode
      costPrice
      sellingPrice
      taxRate
      minStockThreshold
      categoryName
      unitCode
      isActive
      version
    }
  }
`;

export const CREATE_PRODUCT_MUTATION = `
  mutation CreateProduct($input: CreateProductInput!) {
    createProduct(input: $input) {
      id
      name
      sku
      barcode
      costPrice
      sellingPrice
      taxRate
      minStockThreshold
      categoryName
      unitCode
      isActive
    }
  }
`;

export const GET_SALES = `
  query GetSales($limit: Int) {
    sales(limit: $limit) {
      id
      invoiceNumber
      clientInvoiceRef
      subtotal
      taxAmount
      discountAmount
      grandTotal
      paidAmount
      paymentStatus
      paymentMethod
      createdAt
      customerName
      items {
        id
        productId
        productName
        quantity
        unitPrice
        lineTotal
      }
    }
  }
`;

export const GET_CUSTOMERS = `
  query GetCustomers($search: String) {
    customers(search: $search) {
      id
      name
      phone
      email
      currentBalance
      creditLimit
    }
  }
`;

