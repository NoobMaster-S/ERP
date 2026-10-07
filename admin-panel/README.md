# ERP Admin Panel

Independent Next.js, React, and TypeScript Web Administration Console.

## Core Capabilities
* Multi-tenant organization switching and creation
* Visual Roles & Permission matrix explorer
* Member invitation and role allocation
* Security and operational audit log viewer
* Responsive glassmorphism interface

## Local Setup

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Configure Environment**:
   Ensure `NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:8000/graphql/` in `.env.local`.

3. **Run Development Server**:
   ```bash
   npm run dev
   ```
   Admin console runs on `http://localhost:3000`.

4. **Production Build**:
   ```bash
   npm run build
   npm start
   ```
