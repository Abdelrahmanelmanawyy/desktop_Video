import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:desktop_recorder/config/kiosk_config.dart';
import 'package:desktop_recorder/providers/auth_provider.dart';
import 'package:desktop_recorder/screens/home_screen.dart';
import 'package:desktop_recorder/screens/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress known Flutter keyboard state assertion (e.g. after app focus loss/restore)
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('HardwareKeyboard') &&
        details.toString().contains('_pressedKeys.containsKey')) {
      return;
    }
    originalOnError?.call(details);
  };

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    fullScreen: true,
    alwaysOnTop: true,
  );
  windowManager.waitUntilReadyToShow(options).then((_) {
    windowManager.show();
    windowManager.focus();
  });
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return KioskEscapeWrapper(
      child: MaterialApp(
        title: 'Masaüstü Kayıt',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Wraps the app and listens for Ctrl+Shift+F12 to show admin exit dialog.
class KioskEscapeWrapper extends StatefulWidget {
  const KioskEscapeWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<KioskEscapeWrapper> createState() => _KioskEscapeWrapperState();
}

class _KioskEscapeWrapperState extends State<KioskEscapeWrapper> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  bool _isAdminCombo(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.f12) return false;
    return HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed;
  }

  void _showKioskExitDialog() {
    if (!mounted) return;
    _pinController.clear();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pinFocusNode.requestFocus();
        });
        return AlertDialog(
        title: const Text('Yönetici: Kiosktan Çık'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kiosktan çıkmak ve masaüstünü geri getirmek için yönetici PIN\'ini girin:'),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onTap: () => _pinFocusNode.requestFocus(),
              onSubmitted: (_) => _submitKioskExit(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => _submitKioskExit(context),
            child: const Text('Kiosktan Çık'),
          ),
        ],
      );
      },
    ).then((_) {
      _pinFocusNode.unfocus();
    });
  }

  void _submitKioskExit(BuildContext dialogContext) {
    final pin = _pinController.text;
    if (pin != KioskConfig.defaultAdminPin) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Yanlış PIN')),
      );
      return;
    }
    Navigator.of(dialogContext).pop();
    try {
      File(KioskConfig.stopFile).writeAsStringSync('');
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_isAdminCombo(event)) {
          _showKioskExitDialog();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

/// Shows SignInScreen when not authenticated, HomeScreen when signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const SignInScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Kimlik doğrulama hatası: $err', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
