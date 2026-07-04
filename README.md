# Memory Cards

Memory Cards is an offline-first Flutter MVP for revisiting local photos as lightweight memory cards. It reads local photo metadata and thumbnails, lets the user mark cards as important,待删除, or skipped, and stores optional voice memories locally.

## Privacy

- Photos are read-only and original files are never modified.
- On Windows, the user chooses a local photo folder; the app scans it read-only.
- The app does not upload photos, recordings, or memory records.
- There are no accounts, cloud sync, social sharing, transcription, or AI autobiography features in the MVP.
- Export is user-initiated and writes a local `memories.json` file.

## Local Storage

- Memory records are stored in local SQLite through `MemoryRepository`.
- Audio recordings are stored in the app documents directory under `audio/YYYY/`.
- JSON export writes to the app documents directory under `exports/memories.json`.

## Permissions

- Photo library access is used on iOS/Android to read image assets, thumbnails, and capture dates.
- Windows uses a folder picker instead of system photo-library permission.
- Microphone access is used only when the user taps `讲讲` and starts recording.
- `待删除` is only a local metadata flag. The app never deletes photos from the device library.

## Development

Useful commands:

```sh
flutter pub get
flutter analyze
flutter test
```

This repository includes Android, iOS, Windows, and Web scaffolding. Native Android builds require a configured Android SDK, iOS builds require macOS/Xcode, and Windows builds require Visual Studio with Desktop development with C++.

## Known Limits

- Weighted photo selection is metadata-only and does not understand image content.
- Markdown export and share sheets are not implemented yet.
- Windows photo capture time currently falls back to file modified time when EXIF metadata is not parsed.
- HEIC files are not included in the Windows folder scan until decoding support is confirmed.
- Repeated photo avoidance is best-effort; if all photos are already processed, the app can show a repeat.
- The Task 1 fake-data button is still present as a development aid and should be hidden before a user-facing MVP build.


