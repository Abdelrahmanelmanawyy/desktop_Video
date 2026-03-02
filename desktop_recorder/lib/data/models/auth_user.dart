/// Signed-in user from Firebase Auth REST API.
/// Firebase stores username as email: username@desktop.local
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
  });

  final String uid;
  /// Firebase "email" (synthetic): username@desktop.local
  final String email;

  /// Display username (part before @desktop.local)
  String get username {
    const suffix = '@desktop.local';
    if (email.endsWith(suffix)) {
      return email.substring(0, email.length - suffix.length);
    }
    return email;
  }
}
