# Flutter 中使用 Shorebird Code Push 完整指南

本文档详细介绍如何在 Flutter 应用中集成和使用 `shorebird_code_push` 插件。

## 📦 安装

### 1. 添加依赖

在你的 `pubspec.yaml` 文件中添加：

```yaml
dependencies:
  shorebird_code_push: ^0.1.0
```

然后运行：

```bash
flutter pub get
```

### 2. 平台特定配置

#### Android 配置

确保你的 `android/app/build.gradle` 中的 `minSdkVersion` 至少为 21：

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // 必须 >= 21
        targetSdkVersion 34
        // ...
    }
}
```

#### iOS 配置

确保你的 `ios/Runner/Info.plist` 中设置了正确的部署目标：

```xml
<key>MinimumOSVersion</key>
<string>11.0</string>
```

## 🚀 基本使用

### 1. 导入库

```dart
import 'package:shorebird_code_push/shorebird_code_push.dart';
```

### 2. 创建更新器实例

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ShorebirdUpdater updater = ShorebirdUpdater();
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(updater: updater),
    );
  }
}
```

### 3. 检查当前补丁版本

```dart
class MyHomePage extends StatefulWidget {
  final ShorebirdUpdater updater;
  
  const MyHomePage({Key? key, required this.updater}) : super(key: key);
  
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? currentPatchInfo;
  
  @override
  void initState() {
    super.initState();
    _getCurrentPatch();
  }
  
  Future<void> _getCurrentPatch() async {
    try {
      final patch = await widget.updater.readCurrentPatch();
      setState(() {
        currentPatchInfo = patch != null 
          ? 'Current patch: ${patch.number}' 
          : 'No patches installed';
      });
    } catch (e) {
      print('Error reading current patch: $e');
    }
  }
}
```

## 🔄 更新功能实现

### 1. 检查并下载更新

```dart
class UpdateManager {
  final ShorebirdUpdater updater = ShorebirdUpdater();
  
  /// 检查是否有可用更新
  Future<bool> checkForUpdates() async {
    try {
      final status = await updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }
  
  /// 下载并安装更新
  Future<bool> downloadUpdate() async {
    try {
      await updater.update();
      return true;
    } on UpdateException catch (e) {
      print('Update failed: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error during update: $e');
      return false;
    }
  }
  
  /// 检查并自动更新
  Future<void> autoUpdate() async {
    final hasUpdate = await checkForUpdates();
    if (hasUpdate) {
      print('New update available, downloading...');
      final success = await downloadUpdate();
      if (success) {
        print('Update downloaded successfully! Restart app to apply.');
      }
    } else {
      print('App is up to date');
    }
  }
}
```

### 2. 带 UI 的更新流程

```dart
class UpdateWidget extends StatefulWidget {
  @override
  _UpdateWidgetState createState() => _UpdateWidgetState();
}

class _UpdateWidgetState extends State<UpdateWidget> {
  final UpdateManager updateManager = UpdateManager();
  bool isChecking = false;
  bool isUpdating = false;
  String statusMessage = '';
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(statusMessage),
        if (isChecking || isUpdating)
          CircularProgressIndicator(),
        ElevatedButton(
          onPressed: isChecking || isUpdating ? null : _checkAndUpdate,
          child: Text(isUpdating ? 'Updating...' : 'Check for Updates'),
        ),
      ],
    );
  }
  
  Future<void> _checkAndUpdate() async {
    setState(() {
      isChecking = true;
      statusMessage = 'Checking for updates...';
    });
    
    try {
      final hasUpdate = await updateManager.checkForUpdates();
      
      if (hasUpdate) {
        setState(() {
          isChecking = false;
          isUpdating = true;
          statusMessage = 'Downloading update...';
        });
        
        final success = await updateManager.downloadUpdate();
        
        setState(() {
          isUpdating = false;
          statusMessage = success 
            ? 'Update downloaded! Restart to apply.' 
            : 'Update failed. Please try again.';
        });
        
        if (success) {
          _showRestartDialog();
        }
      } else {
        setState(() {
          isChecking = false;
          statusMessage = 'App is up to date!';
        });
      }
    } catch (e) {
      setState(() {
        isChecking = false;
        isUpdating = false;
        statusMessage = 'Error: $e';
      });
    }
  }
  
  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Ready'),
        content: Text('A new update has been downloaded. Please restart the app to apply the changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 可以在这里实现应用重启逻辑
              _restartApp();
            },
            child: Text('Restart Now'),
          ),
        ],
      ),
    );
  }
  
  void _restartApp() {
    // 注意：Flutter 应用无法直接重启自己
    // 你可能需要使用 restart_app 插件或其他方法
    print('App restart requested');
  }
}
```

## 🎯 高级功能

### 1. 指定更新通道

```dart
class AdvancedUpdateManager {
  final ShorebirdUpdater updater = ShorebirdUpdater();
  
  /// 检查指定通道的更新
  Future<bool> checkForUpdatesOnTrack(UpdateTrack track) async {
    try {
      final status = await updater.checkForUpdate(track: track);
      return status == UpdateStatus.outdated;
    } catch (e) {
      print('Error checking for updates on track ${track.name}: $e');
      return false;
    }
  }
  
  /// 从指定通道下载更新
  Future<bool> updateFromTrack(UpdateTrack track) async {
    try {
      await updater.update(track: track);
      return true;
    } catch (e) {
      print('Error updating from track ${track.name}: $e');
      return false;
    }
  }
  
  /// Beta 通道更新
  Future<void> updateFromBeta() async {
    final hasUpdate = await checkForUpdatesOnTrack(UpdateTrack.beta);
    if (hasUpdate) {
      await updateFromTrack(UpdateTrack.beta);
    }
  }
  
  /// 自定义通道更新
  Future<void> updateFromCustomTrack(String trackName) async {
    final track = UpdateTrack(trackName);
    final hasUpdate = await checkForUpdatesOnTrack(track);
    if (hasUpdate) {
      await updateFromTrack(track);
    }
  }
}
```

### 2. 动态更新服务器 URL

```dart
class ServerConfigManager {
  
  /// 更新到自定义服务器
  static bool updateToCustomServer(String serverUrl) {
    final success = ShorebirdCodePush.updateBaseUrl(serverUrl);
    if (success) {
      print('Successfully switched to custom server: $serverUrl');
    } else {
      print('Failed to switch to custom server: $serverUrl');
    }
    return success;
  }
  
  /// 根据地区选择服务器
  static bool updateToRegionalServer(String region) {
    final Map<String, String> regionalServers = {
      'us': 'https://us.api.shorebird.dev',
      'eu': 'https://eu.api.shorebird.dev', 
      'asia': 'https://asia.api.shorebird.dev',
    };
    
    final serverUrl = regionalServers[region];
    if (serverUrl != null) {
      return updateToCustomServer(serverUrl);
    } else {
      print('Unknown region: $region');
      return false;
    }
  }
  
  /// 企业环境配置
  static bool updateToEnterpriseServer(String companyDomain) {
    final enterpriseUrl = 'https://updates.$companyDomain';
    return updateToCustomServer(enterpriseUrl);
  }
}
```

### 3. 应用启动时的自动更新

```dart
class AppStartupManager {
  static Future<void> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 检查是否有离线更新需要应用
    await _checkForOfflineUpdates();
    
    // 启动后台更新检查
    _startBackgroundUpdateCheck();
    
    runApp(MyApp());
  }
  
  static Future<void> _checkForOfflineUpdates() async {
    try {
      final updater = ShorebirdUpdater();
      final patch = await updater.readCurrentPatch();
      
      if (patch != null) {
        print('App is running patch version: ${patch.number}');
      } else {
        print('App is running the base version (no patches)');
      }
    } catch (e) {
      print('Error checking current patch: $e');
    }
  }
  
  static void _startBackgroundUpdateCheck() {
    // 应用启动后 30 秒开始检查更新
    Timer(Duration(seconds: 30), () async {
      final updateManager = UpdateManager();
      await updateManager.autoUpdate();
    });
  }
}

// 在 main.dart 中使用
void main() async {
  await AppStartupManager.initializeApp();
}
```

## 📱 完整示例应用

```dart
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorebird Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ShorebirdUpdater updater = ShorebirdUpdater();
  String currentPatchInfo = 'Loading...';
  String updateStatus = '';
  bool isUpdating = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentPatch();
  }
  
  Future<void> _loadCurrentPatch() async {
    try {
      final patch = await updater.readCurrentPatch();
      setState(() {
        currentPatchInfo = patch != null 
          ? 'Patch #${patch.number}' 
          : 'Base version';
      });
    } catch (e) {
      setState(() {
        currentPatchInfo = 'Error: $e';
      });
    }
  }
  
  Future<void> _checkForUpdate() async {
    setState(() {
      isUpdating = true;
      updateStatus = 'Checking for updates...';
    });
    
    try {
      final status = await updater.checkForUpdate();
      
      if (status == UpdateStatus.outdated) {
        setState(() {
          updateStatus = 'Update available! Downloading...';
        });
        
        await updater.update();
        
        setState(() {
          updateStatus = 'Update downloaded! Restart to apply.';
          isUpdating = false;
        });
        
        // 重新加载当前补丁信息
        await _loadCurrentPatch();
      } else {
        setState(() {
          updateStatus = 'App is up to date!';
          isUpdating = false;
        });
      }
    } on UpdateException catch (e) {
      setState(() {
        updateStatus = 'Update failed: ${e.message}';
        isUpdating = false;
      });
    } catch (e) {
      setState(() {
        updateStatus = 'Error: $e';
        isUpdating = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shorebird Code Push Demo'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Version',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(currentPatchInfo),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(updateStatus.isEmpty ? 'Ready to check for updates' : updateStatus),
                    if (isUpdating) ...[
                      SizedBox(height: 8),
                      LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isUpdating ? null : _checkForUpdate,
              child: Text(isUpdating ? 'Updating...' : 'Check for Updates'),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // 演示自定义服务器切换
                final success = ShorebirdCodePush.updateBaseUrl('https://custom.example.com');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Switched to custom server' 
                      : 'Failed to switch server'),
                  ),
                );
              },
              child: Text('Switch to Custom Server'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔧 错误处理

### 常见错误类型

```dart
Future<void> handleUpdateWithErrorHandling() async {
  try {
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) {
      await updater.update();
    }
  } on UpdateException catch (e) {
    // Shorebird 特定的更新错误
    switch (e.code) {
      case UpdateExceptionCode.networkError:
        print('Network error: Check internet connection');
        break;
      case UpdateExceptionCode.invalidPatch:
        print('Invalid patch: Patch file is corrupted');
        break;
      case UpdateExceptionCode.insufficientStorage:
        print('Not enough storage space for update');
        break;
      default:
        print('Update error: ${e.message}');
    }
  } on PlatformException catch (e) {
    // 平台特定错误
    print('Platform error: ${e.message}');
  } catch (e) {
    // 其他错误
    print('Unexpected error: $e');
  }
}
```

## 🛠️ 最佳实践

### 1. 更新时机

- **应用启动时**: 后台检查更新，不阻塞 UI
- **用户手动触发**: 提供"检查更新"按钮
- **定时检查**: 每24小时检查一次
- **网络状态变化**: WiFi连接时检查更新

### 2. 用户体验

- **渐进式下载**: 显示下载进度
- **后台更新**: 不干扰用户正常使用
- **重启提醒**: 下载完成后提示用户重启应用
- **回滚机制**: 更新失败时自动回滚

### 3. 性能优化

- **缓存管理**: 定期清理旧的补丁文件
- **增量更新**: 只下载变更部分
- **压缩传输**: 使用压缩减少下载大小
- **错误重试**: 网络错误时自动重试

这份文档涵盖了在 Flutter 应用中使用 `shorebird_code_push` 的所有重要方面，包括基本使用、高级功能、错误处理和最佳实践。