# Deployment & Infrastructure Guide

## 1. Minimal-Cost Modular Monolith Topology

In accordance with cost-efficiency principles, the initial deployment requires minimal infrastructure overhead while remaining completely horizontally scalable:

* **Backend & API**: Django running behind Gunicorn / Uvicorn in Docker containers.
* **Database**: Managed PostgreSQL 16 (AWS RDS, Supabase, Neon, or DigitalOcean Managed DB) with PgBouncer connection pooling.
* **Admin Portal**: Next.js deployed via Vercel / Cloudflare Pages or standalone Docker container.
* **Business App**:
  * Android: APK / AAB published to Google Play Console.
  * iOS: IPA published via Apple TestFlight / App Store.
  * Web: Static distribution via Cloudflare Pages or AWS S3 + CloudFront.
* **Object Storage**: Cloudflare R2 (zero egress fees) or AWS S3.

---

## 2. Docker Compose Topology for Development & Self-Hosting

The root `docker-compose.yml` orchestrates the local stack:
* `postgres`: PostgreSQL 16 with pre-configured healthchecks and persistent volume.
* `backend`: Django server running Strawberry GraphQL API.
* `admin`: Next.js web application.
* `minio`: Optional local S3-compatible mock object storage.
