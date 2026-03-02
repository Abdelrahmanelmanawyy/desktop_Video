import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import 'package:desktop_recorder/core/config/firebase_config.dart';

/// Result of zip + upload. [success] true if upload succeeded.
class VideoUploadResult {
  const VideoUploadResult({
    required this.success,
    this.errorMessage,
  });
  final bool success;
  final String? errorMessage;
}

/// Zips a video file (compressed) and uploads to Firebase Storage under recordings/{uid}/.
/// [onProgress] is called with 0.0 to 1.0 (0–0.5 compressing, 0.5–1.0 uploading).
Future<VideoUploadResult> zipAndUploadVideo({
  required String videoPath,
  required String uid,
  required Future<String?> Function() getIdToken,
  void Function(double progress)? onProgress,
}) async {
  final file = File(videoPath);
  if (!await file.exists()) {
    return const VideoUploadResult(success: false, errorMessage: 'Dosya bulunamadı.');
  }

  try {
    onProgress?.call(0.0);

    // 1. Zip with compression
    final bytes = await file.readAsBytes();
    final archive = Archive();
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'recording.mp4';
    archive.addFile(ArchiveFile(name, bytes.length, bytes));

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    onProgress?.call(0.5);

    // 2. Upload to Firebase Storage
    final idToken = await getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return const VideoUploadResult(success: false, errorMessage: 'Oturum bulunamadı. Tekrar giriş yapın.');
    }

    final bucket = firebaseStorageBucket;
    final storageName = 'recordings/$uid/${name.replaceAll(RegExp(r'\.mp4$'), '')}.zip';
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=${Uri.encodeComponent(storageName)}',
    );

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/zip',
      },
      body: zipBytes,
    );

    onProgress?.call(1.0);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return const VideoUploadResult(success: true);
    }
    final body = res.body;
    return VideoUploadResult(
      success: false,
      errorMessage: 'Yükleme hatası: ${res.statusCode}. $body',
    );
  } catch (e) {
    return VideoUploadResult(success: false, errorMessage: e.toString());
  }
}
