import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class RecordedVideoPreview extends StatefulWidget {
  const RecordedVideoPreview({
    super.key,
    required this.videoPath,
    required this.wasTimeUp,
    required this.onRecordAgain,
    required this.theme,
    required this.canRecordAgain,
    required this.attemptsRemaining,
  });

  final String videoPath;
  final bool wasTimeUp;
  final VoidCallback onRecordAgain;
  final ThemeData theme;
  final bool canRecordAgain;
  final int attemptsRemaining;

  @override
  State<RecordedVideoPreview> createState() => _RecordedVideoPreviewState();
}

class _RecordedVideoPreviewState extends State<RecordedVideoPreview> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      final dur = _controller.value.duration;
      final pos = _controller.value.position;
      if (pos >= dur - const Duration(milliseconds: 500)) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.wasTimeUp)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_off_rounded, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Recording stopped at 90 seconds',
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade200,
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.canRecordAgain)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade400.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade400),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Maximum recording attempts reached',
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.orange.shade200,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (_controller.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  else
                    const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    ),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller.value.isInitialized &&
                                !_controller.value.isPlaying
                            ? 1
                            : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.play_circle_filled_rounded,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_controller.value.isInitialized)
                IconButton.filled(
                  onPressed: _togglePlay,
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF252836),
                    foregroundColor: Colors.white,
                  ),
                ),
              if (widget.canRecordAgain) ...[
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: widget.onRecordAgain,
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: Text('Record again (${widget.attemptsRemaining} left)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
