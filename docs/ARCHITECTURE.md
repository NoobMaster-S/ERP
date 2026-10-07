# ERP Platform Architecture Specification

## 1. Executive Summary & Core Principles

This system is an enterprise-grade, extensible, multi-tenant Business ERP SaaS platform designed for small and medium-sized enterprises (SMEs) across diverse verticals including:
* Retail & Point of Sale (POS)
* Jewellery & precious metals
* Electronics & serial-tracked inventory
* Grocery & batch/expiry items
* Wholesale & Distribution
* Service businesses
* Light manufacturing
* Restaurants & Cafes
* General trading

### Non-Negotiable Architectural Invariants
1. **Three Truly Independent Repositories / Projects**:
   * `erp-backend`: Django 5.1 + Strawberry GraphQL + PostgreSQL (Own Git repo, `.env`, tests, CI/CD, Dockerfile, deployment).
   * `erp-admin-panel`: Next.js 14 + React + TypeScript (Own Git repo, `.env`, tests, CI/CD, deployment).
   * `erp-business-app`: Flutter + BLoC + Drift (Own Git repo, `.env`, tests, CI/CD, deployment).
   * **Zero Source Code Imports Across Projects**: Communication occurs strictly over HTTPS/WSS via strongly typed GraphQL contracts.
   * **Independent Lifecycles**: Each frontend is independently versioned, built, and deployed without requiring synchronous deployments of the others.
2. **Database Invariant (No Production SQLite on Backend)**:
   * **PostgreSQL 16+** is the sole production database for the backend (ACID transactions, JSONB, row-level locking, and tenant partitioning). The backend never runs SQLite in production.
   * **SQLite (via Drift)** exists **exclusively** on the client device inside `business-app` as an encrypted local offline database and outbox sync buffer.
3. **Server as Final Authority & Authoritative Invoice Numbering**:
   * The backend owns authoritative tenant isolation, authorization, financial calculations, and **consecutive invoice numbering**.
   * Mobile POS clients generate a local offline reference (e.g. `OFFLINE-DEV1-00042` or UUID `idempotency_key`) for local receipt printing while offline.
   * Upon synchronization, the backend atomically assigns the true, legal, consecutive `invoice_number` (e.g. `INV-2026-00142`) using tenant- and branch-scoped sequence counters with row-level locks, returning the authoritative number to the client. This completely eliminates duplicate numbers and sequencing gaps across multiple concurrent offline devices.
4. **Multi-Tenant Data Isolation**: Every business entity is bound to a tenant (`business_id`). The tenant context is derived exclusively from the cryptographically verified JWT/session token and validated in server middleware and resolvers.
5. **Offline-First Resilience**: Daily operations in `business-app` never block on network availability. All reads query the local Drift/SQLite store immediately. All writes commit locally first, generate idempotent `SyncOutbox` records, and synchronize asynchronously.
6. **Zero Monoliths & Clean Architecture**: Both Flutter and Django feature clean, domain-driven, feature-first modular architectures with strict unidirectional data flow.

---

## 2. High-Level Topology

```text
                               ┌───────────────────────────┐
                               │   PostgreSQL 16 (Source   │
                               │   of Truth & Multi-Tenant)│
                               └─────────────┬─────────────┘
                                             │ ORM / Connection Pool
                               ┌─────────────▼─────────────┐
                               │       Django Backend      │
                               │  - Strawberry GraphQL API │
                               │  - Multi-Tenant Engine    │
                               │  - Permissions & RBAC     │
                               │  - Outbox Sync Ingestion  │
                               │  - Audit Logging Service  │
                               └─────────────┬─────────────┘
                                             │
                       ┌─────────────────────┴─────────────────────┐
        GraphQL over   │                                           │ GraphQL over
        HTTPS / WSS    │                                           │ HTTPS
                       │                                           │
             ┌─────────▼──────────┐                     ┌──────────▼─────────┐
             │    business-app    │                     │    admin-panel     │
             │   (Flutter Client) │                     │   (Next.js Web)    │
             │                    │                     │                    │
             │ - Android / iOS    │                     │ - Platform Admin   │
             │ - Tablet / Web POS │                     │ - Business Admin   │
             │ - Drift Local DB   │                     │ - Role & User Mgt  │
             │ - Sync Engine      │                     │ - Audits & Config  │
             └────────────────────┘                     └────────────────────┘
```

---

## 3. Technology Stack Matrix

| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Backend Language & Framework** | Python 3.12+, Django 5+ | Robust ORM, enterprise ecosystem, rich transactional integrity, mature security. |
| **API Layer** | Strawberry GraphQL | Python type-hint native, strongly typed schema generation, high performance. |
| **Primary Database** | PostgreSQL 16+ | ACID transactions, JSONB, row-level locking, battle-tested multi-tenant support. |
| **Client Application** | Flutter 3.x, Dart 3.x (managed via FVM) | High-performance cross-platform targeting Android, iOS, Tablet, and Web. |
| **Client State & Architecture** | Flutter BLoC/Cubit, Feature-First Clean Arch | Predictable unidirectional state, testability, decoupling of UI from business logic. |
| **Client Local Database** | Drift (SQLite) | Reactive, type-safe Dart SQL queries, schema migrations, robust offline caching. |
| **Admin Web Portal** | Next.js 14+ (App Router), React 18+, TypeScript | High-productivity SSR/SSG, type safety, modular dashboard design. |
| **Object Storage** | S3-Compatible API (AWS S3, MinIO, Cloudflare R2) | Scalable binary storage with metadata maintained strictly in PostgreSQL. |

---

## 4. Subsystem Responsibilities & Isolation Boundaries

### A. Backend (`backend/`)
* **Data Layer**: PostgreSQL database migrations, schema models, constraints, and relational integrity.
* **Authentication Service**: Token minting, rotation, revocation, and password hashing using PBKDF2/Argon2.
* **Tenant Middleware**: Resolves business context from bearer tokens, injecting tenant boundaries into all querysets.
* **GraphQL Resolvers**: Perform authentication, tenant validation, granular permission checks, business validation, and atomic database transactions.
* **Sync Engine (Remote)**: Ingests client mutation batches, verifies idempotency keys, applies transactional changes, records conflict resolutions, and returns authoritative state.
* **Audit Service**: Append-only log recording who did what, when, to which entity, along with pre- and post-mutation diffs.

### B. Business Application (`business-app/`)
* **Presentation**: Reactive screens using BLoC/Cubit listening to domain streams.
* **Domain Layer**: Clean Architecture use cases defining business intent (e.g., `RecordSaleUseCase`, `SyncOutboxUseCase`).
* **Data Layer**:
  * Local: Drift SQLite database storing mirrored tenant records and pending outbox queues.
  * Remote: GraphQL client performing network queries, mutations, and synchronization calls.
* **Sync Engine (Local)**: Observes device connectivity, reads pending outbox entries, serializes GraphQL mutations with idempotency tokens, updates local temporary IDs with server UUIDs, and reconciles conflicts.
* **Hardware Abstractions**: Abstract `PrintService` supporting system printers, PDF renderers, and Bluetooth/network thermal printers; abstract camera/barcode scanners.

### C. Admin Panel (`admin-panel/`)
* **Platform Administration**: Multi-tenant business creation, subscription status, system health.
* **Business Administration**: User invitations, role and permission matrix management, branch and warehouse configuration, audit log analysis.
* **No Direct DB Access**: All operations are dispatched through GraphQL mutations with business-scoped permissions.

---

## 5. Security Architecture

1. **Authentication**: JWT tokens (short-lived access tokens, long-lived refresh tokens with cryptographic rotation).
2. **Authorization**: RBAC with fine-grained permission codes (`sales.create`, `inventory.adjust`, `users.invite`). Roles are bundles of permissions, never hard-coded in logic.
3. **Tenant Invariant**:
   $$\forall \text{ record } r \in \text{ Database}, \quad r.\text{business\_id} \equiv \text{context}.\text{tenant\_id}$$
   Any query omitting `business_id` is blocked at the ORM manager level via custom `TenantModel` base classes.
4. **Offline Security**: Local SQLite database keys stored in platform secure storage (Android Keystore / iOS Keychain). Tokens are never written to unencrypted storage.
