import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_playback_service.dart';

class AudioPlayerTile extends StatefulWidget {
  const AudioPlayerTile({
    super.key,
    required this.audioPath,
    this.controllerFactory = createAudioPlaybackController,
  });

  final String audioPath;
  final AudioPlaybackController Function() controllerFactory;

  @override
  State<AudioPlayerTile> createState() => _AudioPlayerTileState();
}

class _AudioPlayerTileState extends State<AudioPlayerTile> {
  late final AudioPlaybackController _controller;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  var _isPlaying = false;
  var _isBusy = false;
  var _position = Duration.zero;
  Duration? _duration;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory();
    _isPlaying = _controller.isPlaying;
    _position = _controller.position;
    _duration = _controller.duration;

    _subscriptions
      ..add(_controller.playingStream.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
        }
      }))
      ..add(_controller.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      }))
      ..add(_controller.durationStream.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationLabel = _duration == null
        ? _formatDuration(_position)
        : '${_formatDuration(_position)} / ${_formatDuration(_duration!)}';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: _isPlaying
                    ? '\u6682\u505c\u5f55\u97f3'
                    : '\u64ad\u653e\u5f55\u97f3',
                onPressed: _isBusy ? null : _togglePlayback,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Text(
                _isPlaying
                    ? '\u6b63\u5728\u64ad\u653e\u5f55\u97f3'
                    : '\u64ad\u653e\u5f55\u97f3',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              Text(
                durationLabel,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _togglePlayback() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });

    try {
      if (_isPlaying) {
        await _controller.pause();
      } else {
        await _controller.play(widget.audioPath);
      }
    } on AudioPlaybackFailure catch (error) {
      if (mounted) {
        setState(() => _errorText = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = audioPlaybackErrorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
