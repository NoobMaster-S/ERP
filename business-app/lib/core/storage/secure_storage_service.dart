import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/authentication/domain/entities/auth_session.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyAccessToken = 'erp_access_token';
  static const _keyRefreshToken = 'erp_refresh_token';
  static const _keyActiveBusinessId = 'erp_active_business_id';
  static const _keySessionData = 'erp_auth_session_data';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<void> saveSession(AuthSession session) async {
    await saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    if (session.activeBusiness != null) {
      await saveActiveBusinessId(session.activeBusiness!.id);
    }
    await _storage.write(
      key: _keySessionData,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<AuthSession?> getSession() async {
    final rawJson = await _storage.read(key: _keySessionData);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(rawJson);
        return AuthSession.fromJson(data);
      } catch (_) {
        // In case of corrupt storage or version changes
      }
    }
    return null;
  }

  Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }

    final currentSession = await getSession();
    if (currentSession != null) {
      final updatedSession = currentSession.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken ?? currentSession.refreshToken,
      );
      await _storage.write(
        key: _keySessionData,
        value: jsonEncode(updatedSession.toJson()),
      );
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<void> saveActiveBusinessId(String businessId) async {
    await _storage.write(key: _keyActiveBusinessId, value: businessId);
  }

  Future<String?> getActiveBusinessId() =>
      _storage.read(key: _keyActiveBusinessId);

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
