/// Signed-in user from Firebase Auth REST API.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
  });

  final String uid;
  final String email;
}
