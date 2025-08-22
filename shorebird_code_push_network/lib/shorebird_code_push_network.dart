import 'package:shorebird_code_push_network/src/shorebird_updater.dart';
import 'package:shorebird_code_push_network/src/shorebird_updater_io.dart';
import 'package:shorebird_code_push_network/src/updater_network.dart';

export 'src/shorebird_updater.dart'
    show
        Patch,
        ReadPatchException,
        ShorebirdUpdater,
        UpdateException,
        UpdateFailureReason,
        UpdateStatus,
        UpdateTrack;
export 'src/updater_network.dart' 
    show UpdaterNetwork, NetworkUpdaterConfig, NetworkUpdaterInitializer;
export 'src/libapp_path_helper.dart' show LibappPathHelper;

// 导出网络版本的类
export 'src/shorebird_updater_io.dart' show ShorebirdUpdaterImpl;

/// The ShorebirdCodePush class provides a convenient API for checking for and
/// downloading patches.
class ShorebirdCodePush {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Whether the updater is available on the current platform.
  static bool get isAvailable => _updater.isAvailable;

  /// Checks if a new patch is available for download.
  static Future<bool> isNewPatchAvailableForDownload({
    UpdateTrack? track,
  }) async {
    final status = await _updater.checkForUpdate(track: track);
    return status == UpdateStatus.outdated;
  }

  /// Downloads an available update if one exists.
  static Future<void> downloadUpdateIfAvailable({
    UpdateTrack? track,
  }) async {
    try {
      await _updater.update(track: track);
    } on Exception {
      // Silently handle errors for compatibility
    }
  }

  /// Update the base URL for patch checking and downloading.
  /// The base_url parameter must be a valid URL string 
  /// (e.g., "https://api.example.com").
  /// Returns true if the base URL was updated successfully, false otherwise.
  static bool updateBaseUrl(String baseUrl) {
    return _updater.updateBaseUrl(baseUrl);
  }
}

/// 网络版本的 ShorebirdCodePush，用于原生应用集成
/// 使用独立的网络库，避免与引擎内置版本冲突
class ShorebirdCodePushNetwork {
  static final ShorebirdUpdater _updater = ShorebirdUpdaterImpl(
    updater: UpdaterNetwork(),
  );

  /// Whether the network updater is available.
  static bool get isAvailable => _updater.isAvailable;

  /// 检查是否有新补丁可下载
  static Future<bool> isNewPatchAvailableForDownload({
    UpdateTrack? track,
  }) async {
    final status = await _updater.checkForUpdate(track: track);
    return status == UpdateStatus.outdated;
  }

  /// 下载可用的更新
  static Future<void> downloadUpdateIfAvailable({
    UpdateTrack? track,
  }) async {
    try {
      await _updater.update(track: track);
    } on Exception {
      // 静默处理错误以保持兼容性
    }
  }

  /// 更新服务器基础 URL
  static bool updateBaseUrl(String baseUrl) {
    return _updater.updateBaseUrl(baseUrl);
  }
  
  /// 更新补丁下载 URL
  /// 传入 null 以清除自定义下载 URL 并恢复使用 baseUrl
  static bool updateDownloadUrl(String? downloadUrl) {
    final updaterNetwork = (_updater as ShorebirdUpdaterImpl).updater as UpdaterNetwork;
    return updaterNetwork.updateDownloadUrl(downloadUrl);
  }

  /// 获取当前补丁信息
  static Future<Patch?> getCurrentPatch() async {
    return _updater.readCurrentPatch();
  }

  /// 获取下一个补丁信息
  static Future<Patch?> getNextPatch() async {
    return _updater.readNextPatch();
  }
}
