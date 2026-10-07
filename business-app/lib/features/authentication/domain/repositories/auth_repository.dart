import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceName,
  });

  Future<void> logout();

  Future<AuthSession?> getCurrentSession();

  Future<AuthSession?> refreshSession();
}
