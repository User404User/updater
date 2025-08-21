# Shorebird Code Push Network 版本

这是 Shorebird Code Push 的网络专用版本，避免与 Flutter Engine 内置版本冲突。

## 修改总览

### 1. 文件重命名
- **Dart 包**: `shorebird_code_push` → `shorebird_code_push_network`
- **Rust 库**: `library/` → `library_network/`
- **主库文件**: `shorebird_code_push.dart` → `shorebird_code_push_network.dart`
- **Rust 源文件**: `updater.rs` → `updater_network.rs`, `network.rs` → `network_client.rs`

### 2. 库文件名称
- **Android**: `libshorebird_updater_network.so` (避免与 `libupdater.so` 冲突)
- **iOS**: `libshorebird_updater_network.a` (避免与 `libupdater.a` 冲突)

### 3. iOS 符号冲突解决
- 为 iOS 平台导出了 `_net` 后缀的函数版本
- 自动降级处理：如果找不到 `_net` 函数，使用原始函数

### 4. 包命名空间隔离
- 所有 import 路径使用 `package:shorebird_code_push_network/`
- 避免与原版 `package:shorebird_code_push/` 冲突

## 构建方法

```bash
# 构建网络版本库
./build_network.sh

# 输出位置
# - Android: build_network/android/*/libshorebird_updater_network.so
# - iOS: build_network/ios/libshorebird_updater_network*.a
```

## 使用方法

### 1. pubspec.yaml
```yaml
dependencies:
  shorebird_code_push_network:
    path: ../path/to/shorebird_code_push_network
```

### 2. Dart 代码
```dart
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';

void main() async {
  // 检查更新
  final hasUpdate = await ShorebirdCodePushNetwork.isNewPatchAvailableForDownload();
  
  if (hasUpdate) {
    // 下载补丁到与原生版本相同的路径
    await ShorebirdCodePushNetwork.downloadUpdateIfAvailable();
    print('补丁已下载，下次启动时生效');
  }
  
  // 动态设置服务器 URL
  ShorebirdCodePushNetwork.updateBaseUrl('https://your-server.com');
  
  // 获取补丁信息
  final currentPatch = await ShorebirdCodePushNetwork.getCurrentPatch();
  final nextPatch = await ShorebirdCodePushNetwork.getNextPatch();
}
```

### 3. Android 集成
```gradle
android {
    // 将 .so 文件复制到 jniLibs 目录
    // app/src/main/jniLibs/arm64-v8a/libshorebird_updater_network.so
    // app/src/main/jniLibs/armeabi-v7a/libshorebird_updater_network.so
    // app/src/main/jniLibs/x86_64/libshorebird_updater_network.so
    // app/src/main/jniLibs/x86/libshorebird_updater_network.so
}
```

### 4. iOS 集成
在 Xcode 中：
1. 将 `libshorebird_updater_network.a` 添加到项目
2. 在 Build Settings → Library Search Paths 中添加库路径
3. 在 Build Settings → Other Linker Flags 中添加 `-lshorebird_updater_network`

## 关键特性

- ✅ **完全避免冲突**：文件名、包名、符号名都不同
- ✅ **功能一致**：与原版 API 完全相同
- ✅ **状态同步**：补丁保存到相同路径，与原生引擎状态一致
- ✅ **自动初始化**：参数从 shorebird.yaml 自动获取，无需手动配置
- ✅ **跨平台支持**：Android (.so) 和 iOS (.a) 都支持
- ✅ **降级处理**：iOS 上如果符号冲突，自动使用备用方案

## 工作原理

1. **网络库下载补丁** → 保存到 `{cache_dir}/patches/{number}/dlc.vmcode`
2. **更新状态文件** → `{cache_dir}/patches_state.json`
3. **应用重启时** → 原生 Flutter Engine 读取状态文件，加载新补丁
4. **完整兼容** → 与原生引擎的补丁管理系统完全兼容

这样就实现了网络功能与引擎功能的完全分离，同时保持状态同步！