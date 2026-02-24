import 'dart:io';

import 'package:path/path.dart' as path;

/// Kiosk configuration for BAT-based soft kiosk mode.
/// Deploy app to C:\KioskApp\ (or any folder) and run kiosk_watchdog.bat from there.
class KioskConfig {
  KioskConfig._();

  /// Default admin PIN to exit kiosk. Change this for production.
  static const String defaultAdminPin = '1234';

  /// Path to STOP_KIOSK.txt — same directory as the executable.
  /// Creating this file signals the watchdog to stop the loop and restore Explorer.
  static String get stopFile => path.join(
        path.dirname(Platform.resolvedExecutable),
        'STOP_KIOSK.txt',
      );
}
