import 'package:business_app/core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final session = await _remoteDataSource.login(
      email: email,
      password: password,
      deviceName: deviceName,
    );

    // Save complete session securely for offline and persistent login
    await _secureStorage.saveSession(session);

    return session;
  }

  @override
  Future<void> logout() async {
    // Explicit user logout only
    await _secureStorage.clearAll();
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    // 1. Restore persistent session directly from secure storage (works offline)
    final storedSession = await _secureStorage.getSession();
    if (storedSession != null) {
      return storedSession;
    }

    // 2. Fallback: if tokens exist, attempt to restore by refreshing
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        final refreshed = await _remoteDataSource.refreshToken(
          refreshToken: refreshToken,
        );
        await _secureStorage.saveSession(refreshed);
        return refreshed;
      } catch (_) {
        // Network unavailable or server error: do not force logout if stored session exists
        return null;
      }
    }

    return null;
  }

  @override
  Future<AuthSession?> refreshSession() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final newSession = await _remoteDataSource.refreshToken(
        refreshToken: refreshToken,
      );
      await _secureStorage.saveSession(newSession);
      return newSession;
    } catch (_) {
      // Do not log out on network loss; keep existing session
      return await _secureStorage.getSession();
    }
  }
}
