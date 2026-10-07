# Authentication & Session Security Specification

## 1. Authentication Architecture

The ERP system implements stateless, cryptographically secure JWT tokens with refresh rotation, combined with device fingerprinting and server-side revocation tables.

### Token Specs
* **Access Token**: Short-lived (15 minutes). Contains `sub` (User UUID), `tenant_id` (Active Business UUID), `roles`, `permissions` (array of permission codes), and `exp`.
* **Refresh Token**: Long-lived (30 days). Stored in secure HTTP-only cookies for web (`admin-panel`) and `flutter_secure_storage` for mobile/desktop (`business-app`).
* **Refresh Rotation**: Every token refresh issues a new refresh token and invalidates the previous one in the database (`UserDeviceSession`). Reusing an invalidated refresh token triggers family revocation, terminating all sessions for that device.

---

## 2. Token Storage by Platform

| Client | Access Token Storage | Refresh Token Storage | Security Mechanism |
| :--- | :--- | :--- | :--- |
| **Flutter Android** | Memory | `flutter_secure_storage` | Android EncryptedSharedPreferences backed by Android Keystore |
| **Flutter iOS** | Memory | `flutter_secure_storage` | Apple Keychain Services |
| **Flutter Web** | Memory / Session Storage | In-memory with silent refresh | Defense against XSS persistence |
| **Next.js Admin** | In-Memory (React context) | `HttpOnly`, `SameSite=Strict`, `Secure` Cookie | Immune to JavaScript XSS access |

---

## 3. Session Revocation & Multi-Device Tracking

1. **Session Table (`authentication_userdevicesession`)**:
   Tracks `user_id`, `device_id`, `device_name`, `ip_address`, `last_active_at`, and `is_revoked`.
2. **Instant Revocation**:
   * Changing a password revokes all active device sessions.
   * Business administrators can deactivate or terminate team members' sessions immediately from the admin panel.
