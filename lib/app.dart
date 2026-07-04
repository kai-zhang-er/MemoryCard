import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/memory_repository.dart';
import 'services/photo_library_service.dart';

class MemoryCardsApp extends StatelessWidget {
  const MemoryCardsApp({
    super.key,
    required this.repository,
    required this.photoLibraryServiceFactory,
  });

  final MemoryRepository repository;
  final PhotoLibraryService Function() photoLibraryServiceFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Cards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
        useMaterial3: true,
      ),
      home: HomeScreen(
        repository: repository,
        photoLibraryServiceFactory: photoLibraryServiceFactory,
      ),
    );
  }
}
