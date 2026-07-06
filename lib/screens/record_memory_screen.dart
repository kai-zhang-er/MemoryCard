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
  Timer? _memoryTextDebounce;
  String? _memoryTextSaveMessage;
  bool _allowPop = false;
  bool _isHandlingPop = false;
  late final TextEditingController _memoryTextController;

  @override
  void initState() {
    super.initState();
    _memoryTextController = TextEditingController();
    _memoryTextController.addListener(_scheduleMemoryTextSave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _memoryTextDebounce?.cancel();
    _memoryTextController.dispose();
    widget.recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u8bb2\u8bb2')),
      body: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _isHandlingPop) {
            return;
          }
          _isHandlingPop = true;
          await _forceSaveMemoryText();
          if (!context.mounted) {
            return;
          }
          setState(() => _allowPop = true);
          Navigator.of(context).pop(result);
        },
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
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
                      '\u5f53\u524d\u7167\u7247\uff1a${widget.asset.assetId}\n\u62cd\u6444\u65f6\u95f4\uff1a${formatNullableDate(widget.asset.createdAt)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _memoryTextController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '\u6587\u5b57\u5907\u6ce8',
                        hintText:
                            '\u4e5f\u53ef\u4ee5\u53ea\u5199\u51e0\u53e5\u8bdd\uff0c\u4e0d\u5f55\u97f3',
                      ),
                    ),
                    if (_memoryTextSaveMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_memoryTextSaveMessage!),
                    ],
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
                        '\u5f55\u97f3\u6587\u4ef6\uff1a$_relativeAudioPath',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildActions(),
                    const SizedBox(height: 12),
                    const Text(
                      '\u5f55\u97f3\u548c\u6587\u5b57\u5907\u6ce8\u53ea\u4fdd\u5b58\u5728\u672c\u673a App \u76ee\u5f55\uff0c\u4e0d\u4e0a\u4f20\u3001\u4e0d\u8f6c\u5199\u3002',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
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
          label: const Text('\u5f00\u59cb\u5f55\u97f3'),
        ),
      RecordingScreenState.recording => FilledButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop),
          label: const Text('\u505c\u6b62\u5f55\u97f3'),
        ),
      RecordingScreenState.stopped => Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _saveRecording,
              icon: const Icon(Icons.save_outlined),
              label: const Text('\u4fdd\u5b58'),
            ),
            TextButton.icon(
              onPressed: _discardRecording,
              icon: const Icon(Icons.close),
              label: const Text('\u4e0d\u4fdd\u5b58'),
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
              child: const Text('\u91cd\u65b0\u8bf7\u6c42'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _allowPop = true);
                Navigator.of(context).pop(false);
              },
              child: const Text('\u8fd4\u56de'),
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
              child: const Text('\u91cd\u8bd5'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('\u8fd4\u56de'),
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
          _errorMessage =
              '\u9700\u8981\u9ea6\u514b\u98ce\u6743\u9650\u624d\u80fd\u5f55\u5236\u8fd9\u6bb5\u56de\u5fc6\u3002';
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
        _errorMessage = '\u5f55\u97f3\u542f\u52a8\u5931\u8d25\uff1a$error';
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _memoryTextDebounce?.cancel();
    try {
      final path = await widget.recordingService.stop();
      if (!mounted) {
        return;
      }
      if (path == null || path.isEmpty) {
        setState(() {
          _state = RecordingScreenState.error;
          _errorMessage =
              '\u6ca1\u6709\u62ff\u5230\u5f55\u97f3\u6587\u4ef6\u8def\u5f84\uff0c\u8bf7\u91cd\u8bd5\u3002';
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
        _errorMessage = '\u505c\u6b62\u5f55\u97f3\u5931\u8d25\uff1a$error';
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
      await _forceSaveMemoryText();
      await MemoryActionService(widget.memoryRepository).attachAudio(
        widget.asset,
        path,
        promptQuestion: widget.promptQuestion,
        memoryText: _memoryTextController.text.trim(),
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
        _errorMessage =
            '\u4fdd\u5b58\u5f55\u97f3\u8bb0\u5f55\u5931\u8d25\uff1a$error';
      });
    }
  }

  Future<void> _discardRecording() async {
    await _forceSaveMemoryText();
    await widget.recordingService.cancel();
    if (!mounted) {
      return;
    }
    _finish(false);
  }

  void _scheduleMemoryTextSave() {
    _memoryTextDebounce?.cancel();
    _memoryTextDebounce = Timer(const Duration(milliseconds: 700), () {
      _forceSaveMemoryText();
    });
  }

  Future<void> _forceSaveMemoryText() async {
    final text = _memoryTextController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _memoryTextSaveMessage = '\u4fdd\u5b58\u4e2d...');
    await MemoryActionService(widget.memoryRepository).saveMemoryText(
      widget.asset,
      text,
      promptQuestion: widget.promptQuestion,
    );
    if (mounted) {
      setState(() => _memoryTextSaveMessage = '\u5df2\u81ea\u52a8\u4fdd\u5b58');
    }
  }

  void _finish(bool saved) {
    setState(() => _allowPop = true);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(saved);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _memoryTextDebounce?.cancel();
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
  initial(Icons.mic_none, '\u8bf4\u8bf4\u8fd9\u5f20\u7167\u7247'),
  recording(Icons.fiber_manual_record, '\u6b63\u5728\u5f55\u97f3'),
  stopped(Icons.check_circle_outline, '\u5f55\u97f3\u5df2\u505c\u6b62'),
  saving(Icons.save_outlined, '\u6b63\u5728\u4fdd\u5b58'),
  denied(Icons.lock_outline, '\u9700\u8981\u9ea6\u514b\u98ce\u6743\u9650'),
  error(Icons.error_outline, '\u5f55\u97f3\u9047\u5230\u95ee\u9898');

  const RecordingScreenState(this.icon, this.title);

  final IconData icon;
  final String title;
}
