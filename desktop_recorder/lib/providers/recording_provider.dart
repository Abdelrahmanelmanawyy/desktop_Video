import 'dart:io';

import 'package:path/path.dart' as path;

/// Save directory for recordings (inside project folder).
String get saveDir => path.join(Directory.current.path, 'recordings');
