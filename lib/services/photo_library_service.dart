import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_asset.dart';

abstract class PhotoLibraryService {
  Future<PhotoPermissionResult> requestPermission();

  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80});

  Future<Uint8List?> getThumbnail(String assetId, {int size = 900});

  Future<DateTime?> getPhotoTime(String assetId);

  Future<void> openSettings();
}

class PhotoManagerPhotoLibraryService implements PhotoLibraryService {
  const PhotoManagerPhotoLibraryService();

  @override
  Future<PhotoPermissionResult> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (permission.isAuth) {
      return PhotoPermissionResult.authorized;
    }
    if (permission.hasAccess) {
      return PhotoPermissionResult.limited;
    }
    return PhotoPermissionResult.denied;
  }

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) {
      return const [];
    }

    final count = limit < 1 ? 1 : limit;
    final entities = await paths.first.getAssetListPaged(page: 0, size: count);
    return entities.map(_toPhotoAsset).toList(growable: false);
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    final entity = await AssetEntity.fromId(assetId);
    if (entity == null) {
      return null;
    }
    final safeSize = size < 64 ? 64 : size;
    return entity.thumbnailDataWithSize(ThumbnailSize.square(safeSize));
  }

  @override
  Future<DateTime?> getPhotoTime(String assetId) async {
    final entity = await AssetEntity.fromId(assetId);
    return entity?.createDateTime;
  }

  @override
  Future<void> openSettings() {
    return PhotoManager.openSetting();
  }

  PhotoAsset _toPhotoAsset(AssetEntity entity) {
    return PhotoAsset(
      assetId: entity.id,
      createdAt: entity.createDateTime,
      width: entity.width,
      height: entity.height,
      title: entity.title,
    );
  }
}

typedef DirectoryPicker = Future<String?> Function();

class WindowsFolderPhotoLibraryService implements PhotoLibraryService {
  WindowsFolderPhotoLibraryService({DirectoryPicker? directoryPicker})
      : _directoryPicker = directoryPicker ?? getDirectoryPath;

  static const Set<String> supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  };

  final DirectoryPicker _directoryPicker;
  String? _selectedDirectoryPath;
  List<PhotoAsset>? _cachedAssets;

  @override
  Future<PhotoPermissionResult> requestPermission() async {
    if (_selectedDirectoryPath != null) {
      return PhotoPermissionResult.authorized;
    }

    final directoryPath = await _directoryPicker();
    if (directoryPath == null || directoryPath.isEmpty) {
      return PhotoPermissionResult.folderNotSelected;
    }

    _selectedDirectoryPath = directoryPath;
    _cachedAssets = null;
    return PhotoPermissionResult.authorized;
  }

  @override
  Future<List<PhotoAsset>> getPhotoAssets({int limit = 80}) async {
    final directoryPath = _selectedDirectoryPath;
    if (directoryPath == null) {
      return const [];
    }

    final cached = _cachedAssets;
    if (cached != null) {
      return cached.take(_safeLimit(limit)).toList(growable: false);
    }

    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      _selectedDirectoryPath = null;
      _cachedAssets = const [];
      return const [];
    }

    final files = <File>[];
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (isSupportedImagePath(entity.path)) {
        files.add(entity);
      }
    }

    final assets = <PhotoAsset>[];
    for (final file in files) {
      final stat = await file.stat();
      assets.add(
        PhotoAsset(
          assetId: file.path,
          createdAt: stat.modified,
          title: p.basename(file.path),
        ),
      );
    }
    assets.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    _cachedAssets = assets;
    return assets.take(_safeLimit(limit)).toList(growable: false);
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 900}) async {
    final file = File(assetId);
    if (!isSupportedImagePath(file.path) || !await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<DateTime?> getPhotoTime(String assetId) async {
    final file = File(assetId);
    if (!await file.exists()) {
      return null;
    }
    return (await file.stat()).modified;
  }

  @override
  Future<void> openSettings() async {
    _selectedDirectoryPath = await _directoryPicker();
    _cachedAssets = null;
  }

  bool isSupportedImagePath(String path) {
    return supportedExtensions.contains(p.extension(path).toLowerCase());
  }

  int _safeLimit(int limit) => limit < 1 ? 1 : limit;
}

enum PhotoPermissionResult {
  authorized,
  limited,
  denied,
  folderNotSelected;

  bool get canAccessPhotos => this == authorized || this == limited;

  bool get requiresFolderSelection => this == folderNotSelected;
}
