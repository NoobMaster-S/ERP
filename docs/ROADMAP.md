# Platform Implementation Roadmap (Phases 1 — 8)

| Phase | Title | Scope & Deliverables | Status |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **Foundation** | Three-project repository layout, Django multi-tenant core, Strawberry GraphQL engine, JWT auth, RBAC permissions, Docker Compose, Next.js admin shell, Flutter Clean Architecture shell with FVM setup. | **IN PROGRESS (Active)** |
| **Phase 2** | **Offline Engine** | Drift SQLite database models, SyncOutbox queue, bidirectional sync worker, idempotency key verification, retry backoff with network detection. | Planned |
| **Phase 3** | **Master Data** | Customers, Suppliers, Products, Categories, Units, Branches, Warehouses with cross-tenant isolation and GraphQL resolvers. | Planned |
| **Phase 4** | **Transactions** | POS Sales flow, Purchases, Inventory Movements, Multi-method Payments (Cash, UPI, Card, Bank, Credit), Expense tracking. | Planned |
| **Phase 5** | **Documents** | Invoice numbering sequence generation, thermal 58mm/80mm receipt generation, A4 invoice PDFs, native document sharing. | Planned |
| **Phase 6** | **Reports** | Daily sales summary, low stock warning engine, P&L generation, customer ledger statements, supplier payables. | Planned |
| **Phase 7** | **Admin Web** | Business onboarding wizard, User management, Role & Permission matrix visual editor, Audit Log inspector. | Planned |
| **Phase 8** | **Production** | Full test suite, CI/CD GitHub Actions pipeline, production Dockerfiles, mobile store readiness. | Planned |
