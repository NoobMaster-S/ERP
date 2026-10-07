import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<AuthSession> execute({
    required String email,
    required String password,
    String? deviceName,
  }) {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email address cannot be empty.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }

    return _repository.login(
      email: email.trim(),
      password: password,
      deviceName: deviceName ?? 'Flutter Mobile POS',
    );
  }
}
