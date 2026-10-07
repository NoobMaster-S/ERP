# GraphQL API Specification & Conventions

## 1. Design Conventions

1. **Protocol**: GraphQL over HTTP/POST at `/graphql/`. WebSocket subscriptions at `/graphql/ws/` for live updates.
2. **Authentication**: All requests carry the Bearer token header:
   ```text
   Authorization: Bearer <access_token>
   ```
3. **Tenant Context**:
   The tenant context (`business_id`) is inferred directly from the authenticated token claims. If a user belongs to multiple businesses, the active business ID may be passed via the header:
   ```text
   X-Business-ID: <uuid>
   ```
   The backend middleware verifies that the user is an active member of the requested tenant before proceeding.
4. **Pagination**:
   All collection queries follow Relay-style Cursor Connection or Offset pagination:
   ```graphql
   query GetProducts($first: Int, $after: String, $filter: ProductFilterInput) {
     products(first: $first, after: $after, filter: $filter) {
       totalCount
       pageInfo {
         hasNextPage
         endCursor
       }
       edges {
         cursor
         node {
           id
           name
           sku
           sellingPrice
           currentStock
         }
       }
     }
   }
   ```

---

## 2. Core Schema Endpoints

### Authentication & Tenant
```graphql
mutation Login($input: LoginInput!) {
  login(input: $input) {
    accessToken
    refreshToken
    user {
      id
      email
      firstName
      lastName
    }
    businesses {
      id
      name
      roleName
      permissions
    }
  }
}

mutation RefreshToken($refreshToken: String!) {
  refreshToken(refreshToken: $refreshToken) {
    accessToken
  }
}

mutation SwitchBusiness($businessId: UUID!) {
  switchBusiness(businessId: $businessId) {
    accessToken
    activeBusiness {
      id
      name
      permissions
    }
  }
}
```

### Synchronization Outbox Ingestion
```graphql
mutation IngestSyncBatch($input: SyncBatchInput!) {
  ingestSyncBatch(input: $input) {
    processedCount
    results {
      idempotencyKey
      success
      serverEntityId
      errorMessage
      payload
    }
  }
}
```

---

## 3. Structured Error Response Format

Errors return standard GraphQL errors accompanied by machine-readable `extensions`:
```json
{
  "errors": [
    {
      "message": "Permission denied for action 'sales.create'",
      "extensions": {
        "code": "FORBIDDEN",
        "permissionRequired": "sales.create",
        "timestamp": "2026-10-06T16:00:00Z"
      }
    }
  ],
  "data": null
}
```

Standard Error Codes:
* `UNAUTHENTICATED`: Missing or expired access token.
* `FORBIDDEN`: User lacks the necessary permission code in the active business.
* `TENANT_NOT_FOUND` / `TENANT_SUSPENDED`: Business context invalid or account suspended.
* `VALIDATION_ERROR`: Field validation failed (details populated in `fieldErrors`).
* `CONFLICT`: Version mismatch detected during optimistic concurrency update.
* `IDEMPOTENT_REPLAY`: Replayed response from earlier identical submission.
