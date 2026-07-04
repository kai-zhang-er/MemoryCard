import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'services/memory_repository.dart';
import 'services/photo_library_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final MemoryRepository repository;
  final PhotoLibraryService photoLibraryService;
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
    sqfliteFfiInit();
    repository = MemoryRepository(databaseFactory: databaseFactoryFfi);
    photoLibraryService = WindowsFolderPhotoLibraryService();
  } else {
    repository = MemoryRepository();
    photoLibraryService = const PhotoManagerPhotoLibraryService();
  }

  runApp(
    MemoryCardsApp(
      repository: repository,
      photoLibraryServiceFactory: () => photoLibraryService,
    ),
  );
}
