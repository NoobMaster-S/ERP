import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'app/app.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/network/graphql_client_provider.dart';
import 'core/database/app_database.dart';
import 'core/sync/sync_engine.dart';
import 'features/authentication/data/datasources/auth_remote_datasource.dart';
import 'features/authentication/data/repositories/auth_repository_impl.dart';
import 'features/authentication/domain/usecases/login_usecase.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Secure Storage & Local Drift Database
  final secureStorage = SecureStorageService();
  final database = AppDatabase(openConnection());

  // 2. Initialize GraphQL Client Provider
  final gqlProvider = GraphQLClientProvider(secureStorage);
  final gqlClientNotifier = gqlProvider.createClient();

  // 3. Initialize Offline Synchronization Engine
  final syncEngine = SyncEngine(
    db: database,
    client: gqlClientNotifier.value,
  );

  // 4. Clean Architecture Dependency Injection for Authentication
  final authRemoteDataSource =
      AuthRemoteDataSourceImpl(gqlClientNotifier.value);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    secureStorage: secureStorage,
  );
  final loginUseCase = LoginUseCase(authRepository);

  // 5. Restore persistent session so logged-in users remain logged in
  final initialSession = await authRepository.getCurrentSession();
  final authBloc = AuthBloc(
    loginUseCase: loginUseCase,
    authRepository: authRepository,
    initialSession: initialSession,
  );

  if (initialSession == null) {
    authBloc.add(AuthCheckRequested());
  }

  runApp(BusinessERPApp(
    authBloc: authBloc,
    syncEngine: syncEngine,
  ));
}
