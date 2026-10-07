# Multi-Tenant Business ERP Platform

Enterprise-grade, extensible, multi-tenant SaaS ERP platform built for small and medium-sized businesses across diverse verticals (Retail POS, Wholesale, Jewellery, Electronics, Grocery, Restaurants, Manufacturing, and General Trading).

---

## 1. Project Architecture & Boundaries

The platform strictly segregates three independent applications communicating exclusively via public GraphQL contracts:

```text
                    ┌───────────────────────────┐
                    │  PostgreSQL 16 Database   │
                    │   (Multi-Tenant Ledger)   │
                    └─────────────┬─────────────┘
                                  │ ORM
                    ┌─────────────┴─────────────┐
                    │      Django Backend       │
                    │     - Strawberry GraphQL  │
                    │     - JWT Auth & RBAC     │
                    │     - Sync Outbox Engine  │
                    │     - Tenant Isolation    │
                    └───────────┬───┬───────────┘
                                │   │
              GraphQL over HTTP │   │ GraphQL over HTTP
                                │   │
          ┌─────────────────────┘   └──────────────────────┐
          │                                                │
┌─────────▼──────────┐                          ┌──────────▼─────────┐
│   business-app     │                          │    admin-panel     │
│  (Flutter Client)  │                          │   (Next.js Web)    │
│                    │                          │                    │
│ - Android / iOS    │                          │ - Platform Admin   │
│ - Tablet / Web POS │                          │ - Business Admin   │
│ - Drift SQLite     │                          │ - Roles & RBAC     │
│ - Offline Outbox   │                          │ - Audit Trail      │
└────────────────────┘                          └────────────────────┘
```

---

## 2. Directory Structure

```text
ERP/
├── backend/                   # Independent Python 3.12 / Django 5+ GraphQL Server
│   ├── apps/
│   │   ├── common/            # BaseModel, TenantModel, TenantContextMiddleware
│   │   ├── authentication/    # Custom User model, UserDeviceSession, JWT rotation
│   │   ├── businesses/        # Business tenant root model, BusinessUser membership
│   │   ├── roles/             # RBAC Role, Permission, RolePermission, seed service
│   │   ├── branches/          # Branch and Warehouse models
│   │   ├── audit/             # Append-only AuditLog model and event logger
│   │   └── synchronization/   # SyncOutboxLog, Idempotency enforcement
│   ├── graphql_api/           # Strawberry GraphQL Schema, Queries, and Mutations
│   ├── tests/                 # 10/10 automated tests proving tenant isolation & auth
│   ├── requirements.txt
│   └── Dockerfile
│
├── admin-panel/               # Independent Next.js 14+ / React / TypeScript Admin Console
│   ├── app/
│   │   ├── dashboard/         # Protected dashboard, businesses, roles, users, audit
│   │   ├── login/             # JWT authentication page
│   │   └── globals.css        # Responsive design system & glassmorphism tokens
│   ├── components/            # Sidebar, Header, Tenant Switcher
│   ├── lib/                   # GraphQL client and AuthContext
│   ├── package.json
│   └── Dockerfile
│
├── business-app/              # Independent Flutter / Dart Offline-First Business Client
│   ├── .fvmrc                 # Pinned Flutter SDK version management
│   ├── lib/
│   │   ├── app/               # GoRouter, Theme tokens, Environment configuration
│   │   ├── core/              # Drift SQLite DB, SyncEngine, PrintService, Storage
│   │   └── features/          # Clean Architecture modules (auth, dashboard, sync)
│   ├── pubspec.yaml
│   └── README.md
│
├── docs/                      # Architectural & System Specifications
│   ├── ARCHITECTURE.md
│   ├── DATABASE.md
│   ├── GRAPHQL.md
│   ├── AUTHENTICATION.md
│   ├── PERMISSIONS.md
│   ├── OFFLINE_SYNC.md
│   ├── STORAGE.md
│   ├── PRINTING.md
│   ├── DEPLOYMENT.md
│   ├── PRODUCTION_CHECKLIST.md
│   └── ROADMAP.md
│
├── .github/workflows/ci.yml   # Multi-project CI/CD Pipeline
├── docker-compose.yml         # Full local development orchestrator
├── .env.example               # Unified environment variables template
└── README.md                  # This documentation
```

---

## 3. Getting Started & Operations

### Step 1: Start PostgreSQL (Docker)
```bash
docker compose up -d postgres
```
*Port:* `5432` | *Database:* `erp_platform` | *User:* `erp_user`

---

### Step 2: Configure Environment
Copy the template to `.env`:
```bash
cp .env.example .env
```

---

### Step 3: Start Django & Run Migrations
```bash
cd backend

# 1. Activate virtual environment
# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# macOS/Linux:
source venv/bin/activate

# 2. Run database migrations
python manage.py migrate

# 3. Seed system permissions
python manage.py shell -c "from apps.roles.services import seed_system_permissions; seed_system_permissions()"

# 4. Create superuser
python manage.py createsuperuser

# 5. Start development server
python manage.py runserver 8000
```
*Health Check:* `http://localhost:8000/healthz/`
*GraphQL Playground:* `http://localhost:8000/graphql/`
*Django Admin:* `http://localhost:8000/admin/`

---

### Step 4: Run Backend Tests (Tenant Isolation Proof)
```bash
cd backend
python manage.py test
```
*Verification:* Proves that Business A cannot access or mutate Business B's data under any condition, validates token refresh, and tests outbox sync idempotency.

---

### Step 5: Start Next.js Admin Panel
```bash
cd admin-panel
npm install
npm run dev
```
*Admin URL:* `http://localhost:3000`
*Default Test Login:* `owner@acme-corp.com` / `StrongPassword123!`

---

### Step 6: Start Flutter Business Client (with FVM)
```bash
cd business-app

# 1. Install packages
fvm flutter pub get

# 2. Run local SQLite code generator
fvm flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run application
fvm flutter run -d chrome    # or -d windows / -d android
```

---

## 4. Production Build & Release

### Backend Container Build:
```bash
docker build -t erp-backend:latest ./backend
```

### Admin Web Build:
```bash
cd admin-panel
npm run build
```

### Flutter Release Targets:
```bash
cd business-app
# Android App Bundle
fvm flutter build appbundle --release
# Web Distribution
fvm flutter build web --release
# Windows Desktop
fvm flutter build windows --release
```
