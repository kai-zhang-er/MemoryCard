# Repository Guidelines

## Project Structure & Module Organization

This repository is for the Flutter MVP of **Memory Cards**, an offline-first mobile photo memory app. Keep app code in `lib/`, tests in `test/`, and static files in `assets/`.

Recommended layout:

- `lib/main.dart` and `lib/app.dart`: entry point, routing, and theme.
- `lib/models/`: data objects such as `memory_record.dart` and `photo_asset.dart`.
- `lib/services/`: photo access, SQLite storage, recording, weighted random selection, and export logic.
- `lib/screens/`: home, memory card, recording, and memory list flows.
- `lib/widgets/`: reusable UI pieces such as photo cards and action buttons.
- `lib/utils/`: focused helpers for dates, JSON, and formatting.

Keep business logic out of widgets when it belongs in a service or model.

## Build, Test, and Development Commands

Use standard Flutter commands:

- `flutter pub get`: install dependencies.
- `flutter run`: run on a connected simulator or device.
- `flutter analyze`: run static analysis and lint checks.
- `flutter test`: run unit and widget tests.
- `flutter build apk`: build an Android release artifact.
- `flutter build ios`: build an iOS release artifact on macOS.

Run `flutter analyze` and `flutter test` before submitting changes.

## Coding Style & Naming Conventions

Follow Dart and Flutter defaults: two-space indentation, trailing commas for readable widget trees, and `dart format` formatting. Use `lower_snake_case.dart` for files, `UpperCamelCase` for classes, and `lowerCamelCase` for methods, variables, and fields.

Use clear service names such as `MemoryRepository`, `PhotoLibraryService`, and `ExportService`. Add short comments only where privacy or platform behavior needs clarification.

## Testing Guidelines

Use Flutter's built-in `flutter_test` framework. Put tests in `test/` and name files with `_test.dart`, for example `memory_repository_test.dart`.

Prioritize tests for data serialization, repository behavior, weighted photo selection, and JSON export. Widget tests should cover marking a photo important, skipping, and showing saved records.

## Commit & Pull Request Guidelines

No Git history is available yet, so use concise imperative commit messages going forward, such as `Add memory repository` or `Implement JSON export`.

Pull requests should include a summary, tests run, screenshots or recordings for UI changes, and any iOS or Android permission configuration changes. Link related issues when available.

## Security & Privacy Guidelines

The MVP must not upload photos, recordings, or memory records. Do not add cloud sync, accounts, real photo deletion, transcription, or network calls without explicit product approval. Original photo assets are read-only; store only app-owned metadata and local recording paths.
