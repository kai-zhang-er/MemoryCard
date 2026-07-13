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
      theme: MemoryCardsTheme.light,
      home: HomeScreen(
        repository: repository,
        photoLibraryServiceFactory: photoLibraryServiceFactory,
      ),
    );
  }
}

class MemoryCardsTheme {
  const MemoryCardsTheme._();

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D6A4F),
      brightness: Brightness.light,
      surface: const Color(0xFFFFFCF7),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F5EF),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF1B3025),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFFFFFCF7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFFD5DED4)),
      ),
    ),
  );
}
