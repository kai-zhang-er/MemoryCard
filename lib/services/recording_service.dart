import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract class RecordingService {
  Future<bool> hasPermission();

  Future<RecordingStartResult> start(String assetId, {DateTime? now});

  Future<String?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class RecordRecordingService implements RecordingService {
  RecordRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _activeRelativePath;

  @override
  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  @override
  Future<RecordingStartResult> start(String assetId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final relativePath = RecordingPathBuilder.relativePath(assetId, timestamp);
    final absolutePath = await _absolutePathFor(relativePath);
    await Directory(p.dirname(absolutePath)).create(recursive: true);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: absolutePath,
    );
    _activeRelativePath = relativePath;
    return RecordingStartResult(
      absolutePath: absolutePath,
      relativePath: relativePath,
    );
  }

  @override
  Future<String?> stop() async {
    final relativePath = _activeRelativePath;
    await _recorder.stop();
    _activeRelativePath = null;
    return relativePath;
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    _activeRelativePath = null;
  }

  @override
  Future<void> dispose() {
    return _recorder.dispose();
  }

  Future<String> _absolutePathFor(String relativePath) async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, relativePath);
  }
}

class RecordingStartResult {
  const RecordingStartResult({
    required this.absolutePath,
    required this.relativePath,
  });

  final String absolutePath;
  final String relativePath;
}

class RecordingPathBuilder {
  static String relativePath(String assetId, DateTime now) {
    final safeAssetId = assetId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    return p.posix.join(
      'audio',
      now.year.toString(),
      'memory_${now.microsecondsSinceEpoch}_$safeAssetId.m4a',
    );
  }
}
