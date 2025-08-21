# Shorebird Network Updater

这是 Shorebird Updater 的网络版本，用于独立的网络功能。

## 文件说明

### Android
- `android/*/libshorebird_updater_network.so` - 各架构的动态库

### iOS
- `ios/ShorebirdUpdaterNetwork.xcframework` - XCFramework（包含设备和模拟器版本）

### 头文件
- `shorebird_updater_network.h` - C API 头文件

## 使用方法

### Android
将对应架构的 .so 文件复制到 `app/src/main/jniLibs/{架构}/`

### iOS
1. 将 `ShorebirdUpdaterNetwork.xcframework` 添加到 Xcode 项目
2. 在 Frameworks, Libraries, and Embedded Content 中添加 XCFramework
3. 设置为 "Do Not Embed"

### Flutter
使用 `ShorebirdCodePushNetwork` 类：

```dart
import 'package:shorebird_code_push/shorebird_code_push.dart';

// 检查更新
final hasUpdate = await ShorebirdCodePushNetwork.isNewPatchAvailableForDownload();

// 下载更新
if (hasUpdate) {
  await ShorebirdCodePushNetwork.downloadUpdateIfAvailable();
}
```
