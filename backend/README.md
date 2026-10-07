# ERP Backend Service

Independent Python & Django multi-tenant server powering the GraphQL API.

## Core Capabilities
* Multi-tenant data isolation with PostgreSQL
* RBAC with granular permission codes
* Cryptographically secure JWT authentication with refresh token rotation
* Strawberry GraphQL API engine
* Offline synchronization outbox ingestion with idempotency enforcement
* Append-only audit logging

## Local Development Setup

1. **Activate Virtual Environment**:
   ```bash
   # Windows PowerShell
   .\venv\Scripts\Activate.ps1
   # Linux/macOS
   source venv/bin/activate
   ```

2. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run Migrations**:
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

4. **Seed System Permissions**:
   ```bash
   python manage.py shell -c "from apps.roles.services import seed_system_permissions; seed_system_permissions()"
   ```

5. **Start Development Server**:
   ```bash
   python manage.py runserver 8000
   ```
   GraphQL Playground available at `http://localhost:8000/graphql/`.

6. **Run Tests**:
   ```bash
   python manage.py test
   ```
