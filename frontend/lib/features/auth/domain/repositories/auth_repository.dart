import '../../model/user_model.dart';

/// Domain contract for authentication data access.
///
/// The presentation layer depends on this abstraction (through use cases),
/// never on the Dio-backed implementation — so the data source can be swapped
/// or faked in tests without touching the auth flow. Kept as pure Dart: no
/// Flutter, Dio, or storage imports leak in here.
abstract interface class AuthRepository {
  Future<UserModel> register(Map<String, dynamic> body);
  Future<({String token, String refreshToken, UserModel user})> login(
    String email,
    String password,
  );
  Future<UserModel> me();
  Future<UserModel> updateProfile(Map<String, dynamic> body);
  Future<void> applySeller(
    String shopName,
    String shopLocation,
    String taxPayerNumber,
  );

  /// Revokes the refresh token server-side (best-effort on logout).
  Future<void> logout(String refreshToken);
}
