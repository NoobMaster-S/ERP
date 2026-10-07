import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No network connectivity available.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Backend server returned an error.']);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure([super.message = 'Invalid email or password.']);
}

class PermissionFailure extends Failure {
  final String permissionRequired;
  const PermissionFailure(this.permissionRequired, [String message = 'Action forbidden.'])
      : super(message);

  @override
  List<Object?> get props => [message, permissionRequired];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Local SQLite database operation failed.']);
}

class SyncFailure extends Failure {
  const SyncFailure([super.message = 'Synchronization error.']);
}
