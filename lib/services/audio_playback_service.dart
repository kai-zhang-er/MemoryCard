import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const audioPlaybackErrorMessage = '录音文件不存在或暂时无法播放';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

abstract class AudioPlaybackController {
  Stream<bool> get playingStream;

  Stream<Duration> get positionStream;

  Stream<Duration?> get durationStream;

  bool get isPlaying;

  Duration get position;

  Duration? get duration;

  Future<void> play(String audioPath);

  Future<void> pause();

  Future<void> dispose();
}

AudioPlaybackController createAudioPlaybackController() {
  return JustAudioPlaybackController();
}

class AudioPlaybackFailure implements Exception {
  const AudioPlaybackFailure([this.message = audioPlaybackErrorMessage]);

  final String message;

  @override
  String toString() => message;
}

class JustAudioPlaybackController implements AudioPlaybackController {
  JustAudioPlaybackController({
    AudioPlayer? player,
    DocumentsDirectoryProvider? documentsDirectoryProvider,
  })  : _player = player ?? AudioPlayer(),
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final AudioPlayer _player;
  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  String? _loadedAbsolutePath;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> play(String audioPath) async {
    try {
      final absolutePath = await resolveAudioPath(
        audioPath,
        documentsDirectoryProvider: _documentsDirectoryProvider,
      );
      if (!await File(absolutePath).exists()) {
        throw const AudioPlaybackFailure();
      }

      if (_loadedAbsolutePath != absolutePath) {
        await _player.setFilePath(absolutePath);
        _loadedAbsolutePath = absolutePath;
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } on AudioPlaybackFailure {
      rethrow;
    } catch (_) {
      throw const AudioPlaybackFailure();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

Future<String> resolveAudioPath(
  String audioPath, {
  DocumentsDirectoryProvider? documentsDirectoryProvider,
}) async {
  final trimmedPath = audioPath.trim();
  if (trimmedPath.isEmpty) {
    throw const AudioPlaybackFailure();
  }
  if (p.isAbsolute(trimmedPath)) {
    return trimmedPath;
  }

  final directory =
      await (documentsDirectoryProvider ?? getApplicationDocumentsDirectory)();
  return p.join(directory.path, p.fromUri(Uri(path: trimmedPath)));
}
