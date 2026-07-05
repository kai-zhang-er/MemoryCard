import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/photo_asset.dart';
import '../services/memory_action_service.dart';
import '../services/memory_repository.dart';
import '../services/recording_service.dart';
import '../utils/date_utils.dart';
import '../widgets/adaptive_photo_card.dart';

class RecordMemoryScreen extends StatefulWidget {
  const RecordMemoryScreen({
    super.key,
    required this.asset,
    required this.memoryRepository,
    required this.recordingService,
    required this.promptQuestion,
    this.thumbnailBytes,
  });

  final PhotoAsset asset;
  final MemoryRepository memoryRepository;
  final RecordingService recordingService;
  final String promptQuestion;
  final Uint8List? thumbnailBytes;

  @override
  State<RecordMemoryScreen> createState() => _RecordMemoryScreenState();
}

class _RecordMemoryScreenState extends State<RecordMemoryScreen> {
  RecordingScreenState _state = RecordingScreenState.initial;
  String? _relativeAudioPath;
  String? _errorMessage;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    widget.recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('讲讲')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.thumbnailBytes != null) ...[
                  AdaptivePhotoCard(
                    imageBytes: widget.thumbnailBytes!,
                    imageWidth: widget.asset.width,
                    imageHeight: widget.asset.height,
                    maxDesktopWidth: 360,
                    maxHeightFactor: 0.28,
                  ),
                  const SizedBox(height: 16),
                ],
                Icon(_state.icon, size: 56),
                const SizedBox(height: 16),
                Text(
                  _state.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.promptQuestion,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前照片：${widget.asset.assetId}\n拍摄时间：${formatNullableDate(widget.asset.createdAt)}',
                  textAlign: TextAlign.center,
                ),
                if (_state == RecordingScreenState.recording) ...[
                  const SizedBox(height: 16),
                  Text(
                    _formatElapsed(_elapsed),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
                if (_relativeAudioPath != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '录音文件：$_relativeAudioPath',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                _buildActions(),
                const SizedBox(height: 12),
                const Text(
                  '录音只保存在本机 App 目录，不上传、不转写。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return switch (_state) {
      RecordingScreenState.initial => FilledButton.icon(
          onPressed: _startRecording,
          icon: const Icon(Icons.mic_none),
          label: const Text('开始录音'),
        ),
      RecordingScreenState.recording => FilledButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop),
          label: const Text('停止录音'),
        ),
      RecordingScreenState.stopped => Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _saveRecording,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
            TextButton.icon(
              onPressed: _discardRecording,
              icon: const Icon(Icons.close),
              label: const Text('不保存'),
            ),
          ],
        ),
      RecordingScreenState.saving => const CircularProgressIndicator(),
      RecordingScreenState.denied => Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: _startRecording,
              child: const Text('重新请求'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('返回'),
            ),
          ],
        ),
      RecordingScreenState.error => Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: _startRecording,
              child: const Text('重试'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('返回'),
            ),
          ],
        ),
    };
  }

  Future<void> _startRecording() async {
    setState(() {
      _state = RecordingScreenState.initial;
      _errorMessage = null;
      _relativeAudioPath = null;
      _elapsed = Duration.zero;
    });

    try {
      final hasPermission = await widget.recordingService.hasPermission();
      if (!hasPermission) {
        if (!mounted) {
          return;
        }
        setState(() {
          _state = RecordingScreenState.denied;
          _errorMessage = '需要麦克风权限才能录制这段回忆。';
        });
        return;
      }

      await widget.recordingService.start(widget.asset.assetId);
      if (!mounted) {
        return;
      }
      _startTimer();
      setState(() => _state = RecordingScreenState.recording);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = RecordingScreenState.error;
        _errorMessage = '录音启动失败：$error';
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await widget.recordingService.stop();
      if (!mounted) {
        return;
      }
      if (path == null || path.isEmpty) {
        setState(() {
          _state = RecordingScreenState.error;
          _errorMessage = '没有拿到录音文件路径，请重试。';
        });
        return;
      }
      setState(() {
        _relativeAudioPath = path;
        _state = RecordingScreenState.stopped;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = RecordingScreenState.error;
        _errorMessage = '停止录音失败：$error';
      });
    }
  }

  Future<void> _saveRecording() async {
    final path = _relativeAudioPath;
    if (path == null || path.isEmpty) {
      return;
    }

    setState(() => _state = RecordingScreenState.saving);
    try {
      await MemoryActionService(widget.memoryRepository).attachAudio(
        widget.asset,
        path,
        promptQuestion: widget.promptQuestion,
      );
      if (!mounted) {
        return;
      }
      _finish(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = RecordingScreenState.error;
        _errorMessage = '保存录音记录失败：$error';
      });
    }
  }

  Future<void> _discardRecording() async {
    await widget.recordingService.cancel();
    if (!mounted) {
      return;
    }
    _finish(false);
  }

  void _finish(bool saved) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(saved);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String _formatElapsed(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

enum RecordingScreenState {
  initial(Icons.mic_none, '说说这张照片'),
  recording(Icons.fiber_manual_record, '正在录音'),
  stopped(Icons.check_circle_outline, '录音已停止'),
  saving(Icons.save_outlined, '正在保存'),
  denied(Icons.lock_outline, '需要麦克风权限'),
  error(Icons.error_outline, '录音遇到问题');

  const RecordingScreenState(this.icon, this.title);

  final IconData icon;
  final String title;
}
