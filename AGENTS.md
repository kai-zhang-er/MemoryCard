# Repository Guidelines

## Project Structure & Module Organization

Memory Cards is an offline-first Flutter MVP for local photo memory review across iOS, Android, and Windows. App code lives in `lib/`, tests in `test/`, and platform scaffolds in `android/`, `ios/`, `windows/`, and `web/`.

- `lib/main.dart` and `lib/app.dart`: app startup, platform service selection, theme, and root screen.
- `lib/models/`: serializable data objects such as `MemoryRecord` and `PhotoAsset`.
- `lib/services/`: SQLite storage, photo access, recording, weighted selection, export, and action logic.
- `lib/screens/`: home, memory card, recording, and memory list flows.
- `lib/widgets/` and `lib/utils/`: reusable UI and focused helpers.

Keep privacy-sensitive or platform-specific behavior in services, not directly inside widgets.

## Build, Test, and Development Commands

Use the bundled Flutter SDK if Flutter is not on PATH: `D:\Software\FlutterSDK\flutter\bin\flutter.bat`.

- `flutter pub get`: install dependencies and refresh generated plugin files.
- `flutter analyze`: run Dart and Flutter static checks.
- `flutter test`: run unit, widget, and golden tests.
- `flutter test --update-goldens`: update intentional UI snapshot changes.
- `flutter build windows`: verify desktop builds when Visual Studio Desktop C++ tools are installed.
- `flutter build apk` / `flutter build ios`: build mobile artifacts; iOS requires macOS/Xcode.

## Coding Style & Naming Conventions

Follow Dart defaults: two-space indentation, trailing commas in multiline widget trees, `lower_snake_case.dart` files, `UpperCamelCase` classes, and `lowerCamelCase` members. Run `dart format lib test` before final verification.

Prefer dependency injection for platform services. Mobile photo access uses `PhotoManagerPhotoLibraryService`; Windows uses `WindowsFolderPhotoLibraryService`. Windows SQLite must use `sqflite_common_ffi`; mobile keeps `sqflite`.

## Testing Guidelines

Use `flutter_test`; name test files `*_test.dart`. Cover model serialization, repository behavior, weighted random selection, export JSON shape, photo service scanning, and key widget states. Avoid tests that rely on real device permissions, real photo libraries, or microphone hardware; use fakes and injected services.

Golden tests live under `test/goldens/`. Update them only for intentional visual changes.

## Commit & Pull Request Guidelines

Recent commits use short imperative or task-style messages, for example `Implement task 4 local audio recording` and `task 4 finished`. Keep commits focused and include generated plugin/lockfile changes when dependencies change.

Pull requests should summarize behavior, list verification commands, note platform limitations, and include screenshots for UI changes.

## Security & Privacy Guidelines

Do not upload photos, recordings, or memory records. Do not add accounts, cloud sync, transcription, real photo deletion, or network calls without explicit approval. Photos are read-only: iOS/Android access the photo library; Windows scans a user-selected folder. Store only SQLite metadata, local audio paths, and user-initiated JSON exports.
