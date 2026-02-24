import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:desktop_recorder/models/doctor.dart';

/// Save directory for recordings (inside project folder).
String get saveDir => path.join(Directory.current.path, 'recordings');

/// Build recording filename: doctor_id + timestamp.
String recordingFilename(Doctor doctor) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${doctor.doctorId}_$timestamp.mp4';
}

/// Build full path for a recording.
String recordingPath(Doctor doctor) {
  return path.join(saveDir, recordingFilename(doctor));
}
