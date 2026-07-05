import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_playback_service.dart';

class RecordingFileService {
  const RecordingFileService({this.documentsDirectoryProvider});

  final DocumentsDirectoryProvider? documentsDirectoryProvider;

  Future<String> resolve(String relativeAudioPath) async {
    final directoryProvider = documentsDirectoryProvider;
    final directory = directoryProvider == null
        ? await getApplicationDocumentsDirectory()
        : await directoryProvider();
    final trimmedPath = relativeAudioPath.trim();
    if (p.isAbsolute(trimmedPath)) {
      return trimmedPath;
    }
    return p.join(directory.path, p.fromUri(Uri(path: trimmedPath)));
  }

  Future<void> deleteIfExists(String? relativeAudioPath) async {
    final path = relativeAudioPath?.trim();
    if (path == null || path.isEmpty) {
      return;
    }

    final absolutePath = await resolve(path);
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
