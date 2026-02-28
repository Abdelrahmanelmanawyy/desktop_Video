import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desktop_recorder/config/firebase_config.dart';
import 'package:desktop_recorder/models/auth_user.dart';

const _baseAuthUrl = 'https://identitytoolkit.googleapis.com/v1/accounts';
const _secureTokenUrl = 'https://securetoken.googleapis.com/v1/token';
const _refreshTokenKey = 'firebase_refresh_token';

/// Firebase Email/Password uses email as identifier; we use username@desktop.local
const _usernameEmailSuffix = '@desktop.local';

/// Converts a username to the Firebase "email" we store (username@desktop.local).
String _usernameToFirebaseEmail(String username) {
  final clean = username.trim().toLowerCase().split(RegExp(r'@')).first;
  return '$clean$_usernameEmailSuffix';
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>((ref) {
  return AuthNotifier();
});

/// Convenience: current user if authenticated, null otherwise.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> signUp(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final email = _usernameToFirebaseEmail(username);
      final uri = Uri.parse(
        '$_baseAuthUrl:signUp?key=$firebaseWebApiKey',
      );
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode != 200) {
        final message = _errorMessage(data) ?? 'Kayıt başarısız';
        state = const AsyncValue.data(null);
        throw AuthException(message);
      }
      final refreshToken = data!['refreshToken'] as String?;
      final localId = data['localId'] as String?;
      final emailRes = data['email'] as String?;
      if (localId == null || emailRes == null) {
        state = const AsyncValue.data(null);
        throw AuthException('Geçersiz yanıt');
      }
      await _persistRefreshToken(refreshToken);
      state = AsyncValue.data(AuthUser(uid: localId, email: emailRes));
    } catch (e) {
      state = const AsyncValue.data(null);
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  Future<void> signIn(String username, String password) async {
    // Don't set loading here - SignInScreen shows its own spinner.
    // Avoids AuthGate switching to full-screen loader (the "refresh").
    try {
      final email = _usernameToFirebaseEmail(username);
      final uri = Uri.parse(
        '$_baseAuthUrl:signInWithPassword?key=$firebaseWebApiKey',
      );
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode != 200) {
        final message = _errorMessage(data) ?? 'Giriş başarısız';
        state = const AsyncValue.data(null);
        throw AuthException(message);
      }
      final refreshToken = data!['refreshToken'] as String?;
      final localId = data['localId'] as String?;
      final emailRes = data['email'] as String?;
      if (localId == null || emailRes == null) {
        state = const AsyncValue.data(null);
        throw AuthException('Geçersiz yanıt');
      }
      await _persistRefreshToken(refreshToken);
      state = AsyncValue.data(AuthUser(uid: localId, email: emailRes));
    } catch (e) {
      state = const AsyncValue.data(null);
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
    state = const AsyncValue.data(null);
  }

  Future<void> _persistRefreshToken(String? token) async {
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  /// Returns current Firebase ID token for Storage/API calls. Null if not signed in.
  Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final uri = Uri.parse('$_secureTokenUrl?key=$firebaseWebApiKey');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=${Uri.encodeComponent(refreshToken)}',
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    return data?['id_token'] as String?;
  }

  /// Kept for potential future "remember me" / session restore.
  // ignore: unused_element
  Future<_TokenResponse?> _refreshToken(String refreshToken) async {
    final uri = Uri.parse('$_secureTokenUrl?key=$firebaseWebApiKey');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=${Uri.encodeComponent(refreshToken)}',
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (data == null) return null;
    final idToken = data['id_token'] as String?;
    final newRefresh = data['refresh_token'] as String?;
    final userId = data['user_id'] as String?;
    // Get email from decoding id_token payload (base64 middle part) or from getAccountInfo
    final email = _decodeEmailFromIdToken(idToken);
    if (userId == null || email == null) return null;
    return _TokenResponse(uid: userId, email: email, refreshToken: newRefresh);
  }

  static String? _decodeEmailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>?;
      return map?['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? _errorMessage(Map<String, dynamic>? data) {
    if (data == null) return null;
    final err = data['error'];
    if (err is! Map<String, dynamic>) return null;
    final msg = err['message'] as String?;
    if (msg == null) return null;
    // Convert Firebase error codes to readable messages
    switch (msg) {
      case 'EMAIL_NOT_FOUND':
        return 'Bu kullanıcı adına ait hesap bulunamadı.';
      case 'INVALID_PASSWORD':
        return 'Yanlış şifre.';
      case 'USER_DISABLED':
        return 'Bu hesap devre dışı bırakıldı.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Geçersiz kullanıcı adı veya şifre.';
      case 'EMAIL_EXISTS':
        return 'Bu kullanıcı adı zaten kayıtlı.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Kayıt açık değil.';
      case 'WEAK_PASSWORD':
        return 'Şifre yeterince güçlü değil.';
      default:
        return msg;
    }
  }
}

class _TokenResponse {
  _TokenResponse({
    required this.uid,
    required this.email,
    this.refreshToken,
  });
  final String uid;
  final String email;
  final String? refreshToken;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
