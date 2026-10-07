# ERP Business App (Flutter Client)

Production-grade cross-platform (Android, iOS, Tablet, Web) client for daily operations and point-of-sale.

## Architectural Principles
* **FVM Managed**: Pinned to Flutter `stable` via `.fvmrc` and `.fvm/fvm_config.json`.
* **Offline-First**: Reads from local Drift (SQLite) immediately. Writes commit locally first and sync asynchronously via `SyncOutbox`.
* **Feature-First Clean Architecture**: Presentation (BLoC) -> Domain (Use Cases) -> Data (Repositories & Drift / GraphQL).
* **Hardware Abstractions**: Swappable abstractions for standard OS printing and 58mm/80mm thermal receipt printers.
* **Secure Storage**: Tokens persisted strictly via Android Keystore & iOS Keychain (`flutter_secure_storage`).

## Local Setup with FVM

1. **Verify FVM**:
   ```bash
   fvm flutter --version
   ```

2. **Get Dependencies**:
   ```bash
   fvm flutter pub get
   ```

3. **Run Code Generation (Drift schema)**:
   ```bash
   fvm flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Launch Application**:
   ```bash
   # Run on Chrome
   fvm flutter run -d chrome
   # Run on Android Emulator
   fvm flutter run -d android
   # Run on Windows Desktop
   fvm flutter run -d windows
   ```
