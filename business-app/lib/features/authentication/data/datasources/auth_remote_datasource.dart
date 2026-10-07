import 'package:graphql_flutter/graphql_flutter.dart' hide ServerException;
import 'package:business_app/core/error/exceptions.dart';
import '../../domain/entities/auth_session.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceName,
  });

  Future<AuthSession> refreshToken({
    required String refreshToken,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final GraphQLClient _client;

  AuthRemoteDataSourceImpl(this._client);

  static const String _loginMutation = r'''
    mutation Login($input: LoginInput!) {
      login(input: $input) {
        accessToken
        refreshToken
        user {
          id
          email
          firstName
          lastName
          isPlatformAdmin
        }
        activeBusiness {
          id
          name
          slug
          businessType
          roleName
          permissions
        }
        availableBusinesses {
          id
          name
          slug
          businessType
          roleName
          permissions
        }
      }
    }
  ''';

  static const String _refreshTokenMutation = r'''
    mutation RefreshToken($refreshToken: String!) {
      refreshToken(refreshToken: $refreshToken) {
        accessToken
        refreshToken
        user {
          id
          email
          firstName
          lastName
          isPlatformAdmin
        }
        activeBusiness {
          id
          name
          slug
          businessType
          roleName
          permissions
        }
        availableBusinesses {
          id
          name
          slug
          businessType
          roleName
          permissions
        }
      }
    }
  ''';

  AuthSession _parseAuthSession(Map<String, dynamic> data) {
    final userJson = data['user'];
    final user = UserProfile(
      id: userJson['id'],
      email: userJson['email'],
      firstName: userJson['firstName'] ?? '',
      lastName: userJson['lastName'] ?? '',
      isPlatformAdmin: userJson['isPlatformAdmin'] ?? false,
    );

    BusinessSummary? activeBusiness;
    if (data['activeBusiness'] != null) {
      final ab = data['activeBusiness'];
      activeBusiness = BusinessSummary(
        id: ab['id'],
        name: ab['name'],
        slug: ab['slug'],
        businessType: ab['businessType'],
        roleName: ab['roleName'],
        permissions: List<String>.from(ab['permissions'] ?? []),
      );
    }

    final available = (data['availableBusinesses'] as List<dynamic>? ?? [])
        .map((b) => BusinessSummary(
              id: b['id'],
              name: b['name'],
              slug: b['slug'],
              businessType: b['businessType'],
              roleName: b['roleName'],
              permissions: List<String>.from(b['permissions'] ?? []),
            ))
        .toList();

    return AuthSession(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
      user: user,
      activeBusiness: activeBusiness,
      availableBusinesses: available,
    );
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final result = await _client.mutate(
      MutationOptions(
        document: gql(_loginMutation),
        variables: {
          'input': {
            'email': email,
            'password': password,
            'deviceName': deviceName ?? 'Flutter Mobile POS',
          }
        },
      ),
    );

    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.isNotEmpty == true
          ? result.exception!.graphqlErrors.first.message
          : 'Authentication failed. Please verify network and credentials.';
      throw ServerException(msg);
    }

    final data = result.data?['login'];
    if (data == null) {
      throw const ServerException('Empty response received from server.');
    }

    return _parseAuthSession(data);
  }

  @override
  Future<AuthSession> refreshToken({
    required String refreshToken,
  }) async {
    final result = await _client.mutate(
      MutationOptions(
        document: gql(_refreshTokenMutation),
        variables: {
          'refreshToken': refreshToken,
        },
      ),
    );

    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.isNotEmpty == true
          ? result.exception!.graphqlErrors.first.message
          : 'Token refresh failed.';
      throw ServerException(msg);
    }

    final data = result.data?['refreshToken'];
    if (data == null) {
      throw const ServerException('Empty response received from server.');
    }

    return _parseAuthSession(data);
  }
}
