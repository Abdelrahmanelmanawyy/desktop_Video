import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_recorder/models/doctor.dart';
import 'package:desktop_recorder/models/rec_state.dart';
import 'package:desktop_recorder/providers/auth_provider.dart';
import 'package:desktop_recorder/providers/recording_provider.dart';
import 'package:desktop_recorder/services/video_upload_service.dart';
import 'package:desktop_recorder/widgets/framing_overlay_painter.dart';
import 'package:desktop_recorder/widgets/indicator_chip.dart';
import 'package:desktop_recorder/widgets/recorded_video_preview.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CameraController? _cameraController;
  String? _cameraError;
  RecState _recState = RecState.idle;
  int _seconds = 0;
  bool _warning75 = false;
  String? _errorMsg;
  bool _beepPlayed = false;
  bool _timeUpShown = false;
  Timer? _recordTimer;
  String? _lastRecordedPath;
  Timer? _inactivityTimer;
  static const Duration _inactivityTimeout = Duration(seconds: 20);
  int _recordingAttempts = 0;
  static const int _maxRecordingAttempts = 3;
  bool _isSending = false;
  double _sendProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _initCamera();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetInactivityTimer());
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Do not start sign-out countdown while camera is recording
    if (_recState == RecState.recording) return;
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (mounted) ref.read(authStateProvider.notifier).signOut();
    });
  }

  Future<void> _initCamera() async {
    if (!Platform.isWindows || !mounted) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = e.toString());
      }
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _inactivityTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  String _formatDuration(int sec) {
    return '$sec sn';
  }

  Future<void> _onStartStop() async {
    if (!Platform.isWindows || _cameraController == null) return;
    if (_recordingAttempts >= _maxRecordingAttempts && _recState != RecState.recording) {
      return; // Prevent starting new recording if limit reached
    }
    final controller = _cameraController!;

    if (_recState == RecState.recording) {
      await _stopRecording();
    } else {
      await _startRecording(controller);
    }
  }

  void _onRecordAgain() {
    setState(() {
      _recState = RecState.idle;
      _lastRecordedPath = null;
      _timeUpShown = false;
      _isSending = false;
      _sendProgress = 0.0;
    });
  }

  Future<void> _onSendPressed() async {
    final path = _lastRecordedPath;
    final user = ref.read(currentUserProvider);
    if (path == null || user == null) return;

    setState(() {
      _isSending = true;
      _sendProgress = 0.0;
    });

    final result = await zipAndUploadVideo(
      videoPath: path,
      uid: user.uid,
      getIdToken: () => ref.read(authStateProvider.notifier).getIdToken(),
      onProgress: (p) {
        if (mounted) setState(() => _sendProgress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sendProgress = 0.0;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kayıt başarıyla gönderildi.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ref.read(authStateProvider.notifier).signOut();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gönderilemedi.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startRecording(CameraController controller) async {
    setState(() {
      _recState = RecState.recording;
      _seconds = 0;
      _warning75 = false;
      _beepPlayed = false;
      _timeUpShown = false;
      _errorMsg = null;
      _lastRecordedPath = null;
    });
    _inactivityTimer?.cancel(); // Pause sign-out countdown during recording

    try {
      await controller.startVideoRecording();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _seconds++;
          if (_seconds == 75) {
            _warning75 = true;
            if (!_beepPlayed) {
              _beepPlayed = true;
              SystemSound.play(SystemSoundType.alert);
            }
          }
          if (_seconds >= 90) {
            _recordTimer?.cancel();
            _stopRecording();
          }
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _recState = RecState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      setState(() => _recState = RecState.idle);
      return;
    }

    setState(() => _recState = RecState.finalizing);

    try {
      final file = await _cameraController!.stopVideoRecording();
      if (!mounted) return;

      final user = ref.read(currentUserProvider);
      final doctor = Doctor(
        doctorId: user?.uid ?? 'unknown',
        name: user?.username ?? '',
      );
      final outputDir = Directory(saveDir);
      await outputDir.create(recursive: true);
      final outputPath = recordingPath(doctor);
      await file.saveTo(outputPath);

      if (mounted) {
        setState(() {
          _recState = RecState.finished;
          _lastRecordedPath = outputPath;
          _timeUpShown = _seconds >= 90;
          _beepPlayed = false;
          _recordingAttempts++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recState = RecState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = _recState == RecState.recording;
    final isFinalizing = _recState == RecState.finalizing;
    final isFinished = _recState == RecState.finished;
    final isError = _recState == RecState.error;
    final canStart = _recState == RecState.idle || isFinished || isError;

    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: Scaffold(
      backgroundColor: const Color(0xFF1A1D2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252836),
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Masaüstü Kayıt'),
                  ],
                ),
              ),
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _warning75
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _warning75 ? Colors.orange : Colors.white24,
                      width: _warning75 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 28,
                        color: _warning75 ? Colors.orange : Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(_seconds),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _warning75 ? Colors.orange : Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
            tooltip: 'Çıkış yap',
          ),
        ],
      ),
      body: isFinished && _lastRecordedPath != null
          ? RecordedVideoPreview(
              videoPath: _lastRecordedPath!,
              wasTimeUp: _timeUpShown,
              onRecordAgain: _onRecordAgain,
              theme: theme,
              canRecordAgain: _recordingAttempts < _maxRecordingAttempts,
              attemptsRemaining: _maxRecordingAttempts - _recordingAttempts,
              onSendPressed: _onSendPressed,
              isSending: _isSending,
              sendProgress: _sendProgress,
            )
          : Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreview(theme),
                    if (_warning75 && isRecording)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.amber,
                                width: 6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isRecording
                                ? 'Kayıt devam ediyor...'
                                : _recordingAttempts >= _maxRecordingAttempts
                                    ? 'Kayıt limitine ulaşıldı'
                                    : 'Hazır olunca başlat',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_recordingAttempts >= _maxRecordingAttempts) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Oturum başına en fazla $_maxRecordingAttempts kayıt',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canStart || isRecording
                                ? () => _onStartStop()
                                : null,
                            borderRadius: BorderRadius.circular(40),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRecording
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRecording
                                            ? Colors.red
                                            : Colors.green)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isRecording
                                    ? Icons.stop_rounded
                                    : Icons.fiber_manual_record_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_errorMsg != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: IndicatorChip(
                icon: Icons.error_outline_rounded,
                label: _errorMsg!,
                color: Colors.red.shade400,
              ),
            ),

          if (_timeUpShown && isFinalizing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252836),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade400),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_off_rounded,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Süre doldu',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kayıt 90. saniyede durduruldu.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (isFinalizing && !_timeUpShown)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      'Kayıt kaydediliyor...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    if (_cameraError != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(
                'Kamera kullanılamıyor',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize?.width ?? 1,
              height: _cameraController!.value.previewSize?.height ?? 1,
              child: CameraPreview(_cameraController!),
            ),
          ),
          CustomPaint(
            painter: FramingOverlayPainter(),
          ),
        ],
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'Kamera yükleniyor...',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
