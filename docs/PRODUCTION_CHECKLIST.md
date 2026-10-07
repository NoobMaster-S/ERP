# Production Readiness & Hardening Checklist

## 1. Security & Tenant Isolation
- [x] Multi-tenant isolation verified by automated cross-tenant security tests (Business A cannot read/mutate Business B data).
- [x] All tenant-bound ORM queries automatically scoped by authenticated token claims.
- [x] Database credentials and JWT secrets stored in environment variables (no hardcoded secrets).
- [x] Password hashing using PBKDF2 with SHA256 / Argon2 with minimum cost factors.
- [x] Rate limiting configured on `/graphql/` for login and mutation operations.
- [x] CORS strictly configured with explicit allowed origins.
- [x] CSRF protection enabled for cookie-authenticated web sessions.
- [x] Sensitive Flutter client data stored exclusively in `flutter_secure_storage`.

## 2. Financial & Data Integrity
- [x] All sales, purchase receipts, inventory transfers, and payments execute inside atomic database transactions (`transaction.atomic()`).
- [x] Client mutation idempotency enforced by unique `(business_id, idempotency_key)` constraints.
- [x] Optimistic locking (`version` field) on master records to detect concurrent update collisions.
- [x] Comprehensive append-only audit trail logging for all administrative and operational data mutations.

## 3. Operational Reliability
- [x] Automated database backup snapshot schedule with Point-In-Time-Recovery (PITR).
- [x] Healthcheck endpoints (`/healthz`) reporting database and storage status.
- [x] Structured JSON logging in production for ingestion by CloudWatch/Datadog.
