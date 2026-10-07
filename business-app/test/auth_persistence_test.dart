import 'package:flutter_test/flutter_test.dart';
import 'package:business_app/features/authentication/domain/entities/auth_session.dart';
import 'package:business_app/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:business_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:business_app/features/authentication/domain/usecases/login_usecase.dart';
import 'package:business_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:business_app/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// In-memory mock for FlutterSecureStorage
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  AuthSession? mockSession;
  bool shouldThrow = false;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return mockSession!;
  }

  @override
  Future<AuthSession> refreshToken({required String refreshToken}) async {
    if (shouldThrow) throw Exception('Network offline');
    return mockSession!;
  }
}

void main() {
  group('Auth Persistence & Seamless Retention Tests', () {
    late FakeSecureStorage fakeStorage;
    late SecureStorageService storageService;
    late FakeAuthRemoteDataSource fakeRemoteDataSource;
    late AuthRepositoryImpl authRepository;
    late LoginUseCase loginUseCase;

    final testUser = const UserProfile(
      id: 'user-123',
      email: 'pos.cashier@business.com',
      firstName: 'Jane',
      lastName: 'Cashier',
      isPlatformAdmin: false,
    );

    final testBusiness = const BusinessSummary(
      id: 'biz-456',
      name: 'Downtown Mart',
      slug: 'downtown-mart',
      businessType: 'RETAIL',
      roleName: 'Cashier',
      permissions: ['sales.create', 'products.view'],
    );

    final testSession = AuthSession(
      accessToken: 'access-token-abc',
      refreshToken: 'refresh-token-xyz',
      user: testUser,
      activeBusiness: testBusiness,
      availableBusinesses: [testBusiness],
    );

    setUp(() {
      fakeStorage = FakeSecureStorage();
      storageService = SecureStorageService(storage: fakeStorage);
      fakeRemoteDataSource = FakeAuthRemoteDataSource();
      fakeRemoteDataSource.mockSession = testSession;
      authRepository = AuthRepositoryImpl(
        remoteDataSource: fakeRemoteDataSource,
        secureStorage: storageService,
      );
      loginUseCase = LoginUseCase(authRepository);
    });

    test('AuthSession serialization and deserialization preserves all data', () {
      final json = testSession.toJson();
      final restored = AuthSession.fromJson(json);

      expect(restored.accessToken, equals(testSession.accessToken));
      expect(restored.refreshToken, equals(testSession.refreshToken));
      expect(restored.user.email, equals(testUser.email));
      expect(restored.activeBusiness?.id, equals(testBusiness.id));
      expect(restored.availableBusinesses.length, equals(1));
    });

    test('User login persists session and getCurrentSession retrieves it offline', () async {
      // 1. Initial state has no session
      expect(await authRepository.getCurrentSession(), isNull);

      // 2. Perform login
      final session = await authRepository.login(
        email: 'pos.cashier@business.com',
        password: 'password123',
      );
      expect(session.user.id, equals('user-123'));

      // 3. Simulate app restart/cold start offline (remote data source throws)
      fakeRemoteDataSource.shouldThrow = true;
      final retrievedSession = await authRepository.getCurrentSession();

      expect(retrievedSession, isNotNull);
      expect(retrievedSession!.accessToken, equals('access-token-abc'));
      expect(retrievedSession.user.email, equals('pos.cashier@business.com'));
      expect(retrievedSession.activeBusiness?.name, equals('Downtown Mart'));
    });

    test('User remains logged in until explicit logout is triggered', () async {
      await authRepository.login(
        email: 'pos.cashier@business.com',
        password: 'password123',
      );

      // Stored session exists
      expect(await authRepository.getCurrentSession(), isNotNull);

      // Explicit user logout
      await authRepository.logout();

      // Now session is cleared
      expect(await authRepository.getCurrentSession(), isNull);
    });

    test('AuthBloc starts in AuthAuthenticated when initialSession is passed', () {
      final bloc = AuthBloc(
        loginUseCase: loginUseCase,
        authRepository: authRepository,
        initialSession: testSession,
      );

      expect(bloc.state, isA<AuthAuthenticated>());
      final authState = bloc.state as AuthAuthenticated;
      expect(authState.session.user.email, equals('pos.cashier@business.com'));
      bloc.close();
    });

    test('AuthBloc only transitions to AuthUnauthenticated on explicit AuthLogoutRequested', () async {
      final bloc = AuthBloc(
        loginUseCase: loginUseCase,
        authRepository: authRepository,
        initialSession: testSession,
      );

      // Verify authenticated initially
      expect(bloc.state, isA<AuthAuthenticated>());

      // Trigger user logout
      bloc.add(AuthLogoutRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthUnauthenticated>(),
        ]),
      );

      bloc.close();
    });

    test('Token refresh updates access token without logging out user', () async {
      await storageService.saveSession(testSession);

      await storageService.updateTokens(
        accessToken: 'brand-new-access-token',
        refreshToken: 'brand-new-refresh-token',
      );

      final updated = await storageService.getSession();
      expect(updated, isNotNull);
      expect(updated!.accessToken, equals('brand-new-access-token'));
      expect(updated.refreshToken, equals('brand-new-refresh-token'));
      expect(updated.user.email, equals('pos.cashier@business.com'));
    });
  });
}
