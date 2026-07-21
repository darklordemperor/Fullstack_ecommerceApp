import '../../model/user_model.dart';
import '../repositories/auth_repository.dart';

/// Use cases express one user intent each as a callable object. They keep the
/// view model (AuthNotifier) thin and make each action independently testable
/// and reusable. They contain no Flutter or transport code — only the flow.

/// Signs a user in and returns the token pair + user record.
class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<({String token, String refreshToken, UserModel user})> call(
          String email, String password) =>
      _repository.login(email, password);
}

/// Creates a new customer account.
class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<UserModel> call(Map<String, dynamic> body) => _repository.register(body);
}

/// Loads the currently authenticated user (used to restore a session).
class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  Future<UserModel> call() => _repository.me();
}

/// Persists profile edits and returns the updated user.
class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);
  final AuthRepository _repository;

  Future<UserModel> call(Map<String, dynamic> body) =>
      _repository.updateProfile(body);
}
