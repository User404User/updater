import 'dart:io';

import 'package:shorebird_code_push/shorebird_code_push.dart';
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

    if(Platform.isIOS){
      return ShorebirdCodePush().isNewPatchAvailableForDownload();
    }

    final status = await _updater.checkForUpdate(track: track);
    return status == UpdateStatus.outdated;
  }

  /// 下载可用的更新
  static Future<void> downloadUpdateIfAvailable({
    UpdateTrack? track,
  }) async {

    if(Platform.isIOS){

       await ShorebirdCodePush().downloadUpdateIfAvailable();
       return;
    }
    try {
      await _updater.update(track: track);
    } on Exception {
      // 静默处理错误以保持兼容性
    }
  }

  /// 更新服务器基础 URL
  static bool updateBaseUrl(String baseUrl) {
    if(Platform.isIOS){
      // iOS 使用 UpdaterNetwork 的实现
      final updaterNetwork = (_updater as ShorebirdUpdaterImpl).updater as UpdaterNetwork;
      return updaterNetwork.updateBaseUrl(baseUrl);
    }else{
      return _updater.updateBaseUrl(baseUrl);
    }
  }
  
  /// 更新补丁下载 URL
  /// 传入 null 以清除自定义下载 URL 并恢复使用 baseUrl
  static bool updateDownloadUrl(String? downloadUrl) {
    // iOS 和 Android 都使用 UpdaterNetwork 的实现
    final updaterNetwork = (_updater as ShorebirdUpdaterImpl).updater as UpdaterNetwork;
    return updaterNetwork.updateDownloadUrl(downloadUrl);
  }

  /// 获取当前补丁信息
  static Future<Patch?> getCurrentPatch() async {
    if(Platform.isIOS){

      int? num = await ShorebirdCodePush().currentPatchNumber();
      return Patch(number: num ?? 0);
    }else{
      return _updater.readCurrentPatch();
    }


  }

  /// 获取下一个补丁信息
  static Future<Patch?> getNextPatch() async {
    if(Platform.isIOS){
      int? num = await ShorebirdCodePush().nextPatchNumber();
      return Patch(number: num ?? 0);
    }
    return _updater.readNextPatch();
  }
  
  /// 添加自定义域名映射（仅iOS有效）
  static Future<bool> addHostMapping(String originalHost, String redirectHost) {
    return UpdaterNetwork.addHostMapping(originalHost, redirectHost);
  }
  
  /// 移除域名映射（仅iOS有效）
  static Future<bool> removeHostMapping(String originalHost) {
    return UpdaterNetwork.removeHostMapping(originalHost);
  }
  
  /// 清空所有域名映射（仅iOS有效）
  static Future<bool> clearAllHostMappings() {
    return UpdaterNetwork.clearAllHostMappings();
  }
}
