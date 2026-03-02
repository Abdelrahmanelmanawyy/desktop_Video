import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desktop_recorder/presentation/providers/auth_provider.dart';

/// State for the sign-in form.
class SignInFormState {
  const SignInFormState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isLoading;
  final String? errorMessage;

  SignInFormState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SignInFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Controller for the sign-in page: form state and sign-in / sign-up actions.
class SignInController extends Notifier<SignInFormState> {
  @override
  SignInFormState build() => const SignInFormState();

  void setEmail(String value) {
    state = state.copyWith(email: value, errorMessage: null);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value, errorMessage: null);
  }

  Future<void> signIn() async {
    if (state.isLoading) return;
    final email = state.email.trim();
    final password = state.password;
    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter email and password.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    final auth = ref.read(authStateProvider.notifier);
    try {
      await auth.signIn(email, password);
      state = state.copyWith(isLoading: false, errorMessage: null);
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromException(e),
      );
    }
  }

  Future<void> signUp() async {
    if (state.isLoading) return;
    final email = state.email.trim();
    final password = state.password;
    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter email and password.',
      );
      return;
    }
    if (password.length < 6) {
      state = state.copyWith(
        errorMessage: 'Password must be at least 6 characters.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    final auth = ref.read(authStateProvider.notifier);
    try {
      await auth.signUp(email, password);
      state = state.copyWith(isLoading: false, errorMessage: null);
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromException(e),
      );
    }
  }

  static String _messageFromException(Exception e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (msg.contains('invalid-email')) {
      return 'Invalid email address.';
    }
    if (msg.contains('weak-password')) {
      return 'Password is too weak.';
    }
    if (msg.contains('network')) {
      return 'Network error. Please try again.';
    }
    return 'Giriş başarısız. Lütfen tekrar deneyin.';
  }
}

final signInControllerProvider =
    NotifierProvider<SignInController, SignInFormState>(SignInController.new);
