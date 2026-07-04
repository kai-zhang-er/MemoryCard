import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_cards/screens/home_screen.dart';
import 'package:memory_cards/services/memory_repository.dart';
import 'package:memory_cards/services/photo_library_service.dart';

void main() {
  testWidgets('Home screen surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: MemoryRepository(),
          photoLibraryServiceFactory: () =>
              const PhotoManagerPhotoLibraryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_screen_surface.png'),
    );
  });
}
