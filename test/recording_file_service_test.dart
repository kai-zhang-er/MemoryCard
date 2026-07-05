import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/services/recording_file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recording_file_service_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resolves relative audio paths under app documents', () async {
    final service = RecordingFileService(
      documentsDirectoryProvider: () async => tempDir,
    );

    final resolved = await service.resolve('audio/2026/memory.m4a');

    expect(resolved, p.join(tempDir.path, 'audio', '2026', 'memory.m4a'));
  });

  test('deletes existing audio files and ignores missing files', () async {
    final service = RecordingFileService(
      documentsDirectoryProvider: () async => tempDir,
    );
    final file = File(p.join(tempDir.path, 'audio', '2026', 'memory.m4a'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);

    await service.deleteIfExists('audio/2026/memory.m4a');
    await service.deleteIfExists('audio/2026/memory.m4a');
    await service.deleteIfExists(null);

    expect(await file.exists(), isFalse);
  });
}
