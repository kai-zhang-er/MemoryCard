import 'dart:typed_data';

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

enum PhotoPermissionResult {
  authorized,
  limited,
  denied;

  bool get canAccessPhotos => this == authorized || this == limited;
}
