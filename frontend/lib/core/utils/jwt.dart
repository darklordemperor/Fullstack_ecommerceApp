import 'dart:convert';
import 'dart:developer';

/// Returns true when [token] is not a well-formed JWT or its `exp` claim is
/// in the past. Used only for UX (skip a doomed `/users/me` call on startup);
/// the backend remains the authority on token validity.
bool isJwtExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (decoded is! Map<String, dynamic>) return true;
    final exp = decoded['exp'];
    if (exp is! num) return true;
    return DateTime.now().millisecondsSinceEpoch >= exp.toInt() * 1000;
  } on FormatException catch (error) {
    log('Token decode failed', name: 'auth', error: error);
    return true;
  }
}
