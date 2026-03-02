import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_recorder/presentation/providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  static const int _maxFailedAttempts = 3;
  static const int _lockoutSeconds = 30;

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  int _lockoutRemainingSeconds = 0;
  Timer? _lockoutTimer;

  bool get _isLockedOut => _lockoutRemainingSeconds > 0;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _startLockout() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _lockoutRemainingSeconds--;
        if (_lockoutRemainingSeconds <= 0) {
          _lockoutTimer?.cancel();
          _lockoutTimer = null;
          _failedAttempts = 0;
        }
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLockedOut) return;
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await ref.read(authStateProvider.notifier).signIn(
            _usernameController.text,
            _passwordController.text,
          );
    } on AuthException catch (e) {
      if (!mounted) return;
      final newCount = _failedAttempts + 1;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
        _failedAttempts = newCount;
        if (newCount >= _maxFailedAttempts) {
          _lockoutRemainingSeconds = _lockoutSeconds;
        }
      });
      if (newCount >= _maxFailedAttempts) _startLockout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      final newCount = _failedAttempts + 1;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _failedAttempts = newCount;
        if (newCount >= _maxFailedAttempts) {
          _lockoutRemainingSeconds = _lockoutSeconds;
        }
      });
      if (newCount >= _maxFailedAttempts) _startLockout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 24),
                    Text('Giriş yap', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Adınız ve şifrenizle giriş yapın.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _usernameController,
                      focusNode: _usernameFocusNode,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      onTap: () => _usernameFocusNode.requestFocus(),
                      decoration: const InputDecoration(labelText: 'Ad', hintText: '', prefixIcon: Icon(Icons.person_outline_rounded), border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Adınızı girin' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onTap: () => _passwordFocusNode.requestFocus(),
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Şifrenizi girin' : null,
                    ),
                    if (_isLockedOut) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_clock_rounded, color: Theme.of(context).colorScheme.error, size: 24),
                            const SizedBox(width: 12),
                            Text('Çok fazla deneme. $_lockoutRemainingSeconds saniye sonra tekrar deneyin.', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    FilledButton(
                      onPressed: (_isLoading || _isLockedOut) ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isLoading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isLockedOut ? 'Kilitli' : 'Giriş yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
