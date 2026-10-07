import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../storage/secure_storage_service.dart';
import '../../app/configuration/app_config.dart';

class GraphQLClientProvider {
  final SecureStorageService _storage;

  GraphQLClientProvider(this._storage);

  bool _isJwtExpiredOrExpiringSoon(String token, {int thresholdSeconds = 60}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final decodedString = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decodedString) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is int) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
        final now = DateTime.now().toUtc();
        return expiryDate
            .isBefore(now.add(Duration(seconds: thresholdSeconds)));
      }
    } catch (_) {}
    return false;
  }

  Future<String?> getValidAccessToken() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null) return null;

    if (!_isJwtExpiredOrExpiringSoon(accessToken)) {
      return accessToken;
    }

    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      return accessToken;
    }

    try {
      final client = HttpClient();
      try {
        final request =
            await client.postUrl(Uri.parse(AppConfig.current.apiBaseUrl));
        request.headers.set('Content-Type', 'application/json');
        request.write(jsonEncode({
          'query': r'''
            mutation RefreshToken($refreshToken: String!) {
              refreshToken(refreshToken: $refreshToken) {
                accessToken
                refreshToken
              }
            }
          ''',
          'variables': {'refreshToken': refreshToken},
        }));
        final response =
            await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody);
          final refreshData = data['data']?['refreshToken'];
          if (refreshData != null && refreshData['accessToken'] != null) {
            final newAccess = refreshData['accessToken'] as String;
            final newRefresh = refreshData['refreshToken'] as String?;
            await _storage.updateTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            return newAccess;
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Network loss or temporary failure: never log out the user, keep using current token
    }

    return accessToken;
  }

  ValueNotifier<GraphQLClient> createClient() {
    final httpLink = HttpLink(AppConfig.current.apiBaseUrl);

    final authLink = AuthLink(
      getToken: () async {
        final token = await getValidAccessToken();
        return token != null ? 'Bearer $token' : null;
      },
    );

    // Concatenate authLink and httpLink
    final link = authLink.concat(httpLink);

    final client = GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );

    return ValueNotifier(client);
  }
}
