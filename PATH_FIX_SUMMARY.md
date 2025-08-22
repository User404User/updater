# Shorebird Updater 路径修复总结

## 问题描述
补丁下载成功但无法被 Flutter Engine 加载，原因是路径不匹配。

## 根本原因
Flutter Engine 期望补丁存储在特定的路径结构中：
- **Android**: `/data/data/<package>/files/shorebird_updater/patches/<patch_number>/dlc.vmcode`
- **iOS**: `~/Library/Application Support/shorebird/shorebird_updater/patches/<patch_number>/dlc.vmcode`

但网络库直接使用平台提供的路径，没有添加必要的后缀。

## 修复内容

### 1. 修改了 `shorebird_code_push_network/lib/src/network_init.dart`
在 Dart 层添加了平台特定的路径后缀：

```dart
if (Platform.isIOS) {
  // iOS: Engine expects shorebird/shorebird_updater suffix
  finalAppStorageDir = '$appStorageDir/shorebird/shorebird_updater';
  finalCodeCacheDir = '$codeCacheDir/shorebird/shorebird_updater';
} else if (Platform.isAndroid) {
  // Android: Engine expects shorebird_updater suffix
  finalAppStorageDir = '$appStorageDir/shorebird_updater';
  finalCodeCacheDir = '$codeCacheDir/shorebird_updater';
}
```

### 2. 保持 Rust 层简单
`library_network/src/config.rs` 中的函数直接使用 Dart 层传入的路径：

```rust
fn get_platform_storage_path(app_storage_dir: &str) -> PathBuf {
    // Use the exact path provided by the Dart layer
    PathBuf::from(app_storage_dir)
}
```

### 3. 添加了详细的日志输出
在多个位置添加了调试日志：
- Dart 层：显示原始路径和修正后的路径
- Rust 层：显示接收到的路径和最终使用的路径

## 影响范围
1. **补丁存储位置**：补丁现在会存储在 Engine 期望的位置
2. **状态文件位置**：`patches_state.json` 也会存储在正确的位置
3. **向后兼容性**：旧的补丁需要重新下载到新位置

## 验证方法
1. 编译并部署更新后的网络库
2. 下载补丁
3. 检查补丁是否存储在正确的路径
4. 重启应用，验证补丁是否被加载

## 注意事项
- 这个修改会改变补丁的存储位置，已下载的补丁需要重新下载
- 确保平台层（iOS/Android）提供的是基础路径，不要重复添加后缀