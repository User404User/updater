# Shorebird Updater 库构建指南

本文档详细介绍如何构建Shorebird Updater静态库，生成Android全架构和iOS（真机+模拟器A芯片）的库文件。

## 📋 前置要求

### 系统要求
- macOS（用于构建iOS库）
- Xcode 12.0+（用于iOS构建和lipo工具）
- Android NDK r23+（推荐使用最新版本）

### 开发工具
- **Rust 工具链**: 1.80.0+
- **cargo-ndk**: 用于Android交叉编译
- **Python 3**: 某些构建脚本需要

### 环境变量
```bash
# Android NDK（推荐使用最新版本）
export ANDROID_NDK_ROOT=/path/to/android/ndk
export NDK_HOME=$ANDROID_NDK_ROOT

# 可选：设置特定的NDK版本
export ANDROID_NDK_ROOT=/Users/username/Library/Android/sdk/ndk/26.1.10909125
```

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装 Rust（如果未安装）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 安装 cargo-ndk
cargo install cargo-ndk

# 添加 Android 目标架构
rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

# 添加 iOS 目标架构
rustup target add \
    aarch64-apple-ios \
    x86_64-apple-ios \
    aarch64-apple-ios-sim
```

### 2. 执行构建

```bash
# 进入项目目录
cd /path/to/updater

# 执行构建脚本
./build_updater.sh
```

## 📁 输出格式

构建完成后，将在 `build_output/` 目录生成以下文件：

```
build_output/
├── android/
│   ├── armeabi-v7a/
│   │   └── libupdater.a          # ARM 32位
│   ├── arm64-v8a/
│   │   └── libupdater.a          # ARM 64位（主流）
│   ├── x86/
│   │   └── libupdater.a          # x86 32位模拟器
│   ├── x86_64/
│   │   └── libupdater.a          # x86 64位模拟器
│   └── updater.h                 # Android 头文件
└── ios/
    ├── libupdater_device.a       # iOS 真机 (arm64)
    ├── libupdater_simulator.a    # iOS 模拟器 (x86_64 + arm64)
    └── updater.h                 # iOS 头文件
```

## 🔧 构建流程详解

### Android 构建

1. **使用 cargo-ndk**: 专门为Android交叉编译设计，处理NDK工具链配置
2. **支持架构**:
   - `armeabi-v7a`: 32位ARM设备（老旧设备）
   - `arm64-v8a`: 64位ARM设备（现代设备主流）
   - `x86`: 32位x86模拟器
   - `x86_64`: 64位x86模拟器
3. **输出**: 每个架构生成独立的静态库文件

### iOS 构建

1. **直接使用 cargo**: 利用Xcode工具链进行交叉编译
2. **支持架构**:
   - `aarch64-apple-ios`: iOS真机ARM64
   - `x86_64-apple-ios`: Intel Mac模拟器
   - `aarch64-apple-ios-sim`: Apple Silicon Mac模拟器
3. **合并策略**:
   - 真机版本: 仅包含 `arm64`
   - 模拟器版本: 合并 `x86_64` + `arm64`（支持A芯片Mac）

## ⚙️ 构建参数

### 关键环境变量

```bash
# Android NDK 配置
ANDROID_NDK_ROOT=/path/to/ndk    # NDK根目录
NDK_HOME=$ANDROID_NDK_ROOT       # NDK主目录（兼容性）

# iOS SDK 配置（自动检测）
SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONEOS_DEPLOYMENT_TARGET="11.0"

# 交叉编译配置
PKG_CONFIG_ALLOW_CROSS=1         # 允许交叉编译
```

### cargo-ndk 参数

```bash
# 构建所有Android架构
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86 -t x86_64 build --release

# 构建特定架构
cargo ndk -t arm64-v8a build --release
```

### cargo 参数

```bash
# iOS设备构建
cargo build --release --target aarch64-apple-ios

# iOS模拟器构建
cargo build --release --target x86_64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
```

## ⚠️ 注意事项

### 1. NDK 版本兼容性
- **最低要求**: NDK r23+
- **推荐版本**: NDK 26.1.10909125 或更新
- **问题排查**: 如果构建失败，尝试更新到最新NDK版本

### 2. Rust 依赖问题
- 某些C依赖库（如ring, zstd-sys）需要对应的系统工具链
- 如果遇到链接错误，确保NDK工具链正确配置
- Android API Level 21+ 是最低要求

### 3. iOS 构建环境
- 必须在macOS上构建iOS库
- Xcode Command Line Tools 必须安装：`xcode-select --install`
- 确保Xcode许可协议已接受：`sudo xcodebuild -license accept`

### 4. 文件大小优化
- Release模式构建已启用最高优化
- 静态库较大（30-40MB）是正常现象，包含了所有依赖
- 最终应用中会进行进一步的死代码消除

### 5. 架构选择建议
- **Android主流**: 优先支持 `arm64-v8a`
- **Android兼容**: 可添加 `armeabi-v7a` 支持老设备
- **模拟器调试**: 包含 `x86_64` 和 `x86` 用于模拟器测试
- **iOS模拟器**: `libupdater_simulator.a` 同时支持Intel和Apple Silicon Mac

## 🐛 常见问题

### Q1: Android构建失败 - "NDK versions less than r23 are not supported"
```bash
# 问题原因：使用了过旧的NDK版本（如ndk-bundle）
# 解决方案：脚本已自动检测最新NDK版本

# 手动设置NDK版本（如果自动检测失败）
export ANDROID_NDK_ROOT=/Users/username/Library/Android/sdk/ndk/26.1.10909125
export NDK_HOME=$ANDROID_NDK_ROOT

# 验证NDK版本
echo $ANDROID_NDK_ROOT
ls $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/
```

### Q2: 构建脚本报错 "declare: -A: invalid option"
```bash
# 问题原因：Shell兼容性问题（关联数组语法）
# 解决方案：已修复为使用函数替代关联数组

# 如果仍有问题，确保使用bash执行
bash ./build_updater.sh
```

### Q3: Android构建失败 - "Failed to find tool"
```bash
# 解决方案：检查NDK配置
echo $ANDROID_NDK_ROOT
ls $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/

# 确保使用正确的NDK版本
export ANDROID_NDK_ROOT=/Users/username/Library/Android/sdk/ndk/26.1.10909125
```

### Q4: iOS构建失败 - SDK路径问题
```bash
# 解决方案：重新设置Xcode路径
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcrun --sdk iphoneos --show-sdk-path
```

### Q5: cargo-ndk 命令未找到
```bash
# 解决方案：安装cargo-ndk
cargo install cargo-ndk

# 验证安装
cargo ndk --version
```

### Q6: 链接错误 - "undefined symbol"
```bash
# 解决方案：清理重新构建
cargo clean
./build_updater.sh
```

### Q7: iOS模拟器库缺少ARM64架构
```bash
# 验证架构
lipo -info build_output/ios/libupdater_simulator.a

# 应该输出：Architectures in the fat file: ... are: x86_64 arm64
```

## 📊 性能优化

### 构建时间优化
```bash
# 使用多核编译
export CARGO_BUILD_JOBS=8

# 启用增量编译（开发时）
export CARGO_INCREMENTAL=1
```

### 输出大小优化
```bash
# 已在 Cargo.toml 中配置：
# [profile.release]
# lto = true              # 链接时优化
# codegen-units = 1       # 更好的优化
# strip = true            # 移除符号表
```

## 🔄 自动化构建

构建脚本 `build_updater.sh` 提供以下功能：

1. **环境检查**: 验证所需工具是否安装
2. **智能NDK检测**: 自动查找并使用最新的NDK版本（r23+）
3. **依赖安装**: 自动添加缺失的目标架构
4. **Shell兼容性**: 修复关联数组兼容性问题，支持多种Shell
5. **清理构建**: 可选择清理之前的构建产物
6. **错误处理**: 详细的错误信息和解决建议
7. **构建报告**: 生成详细的构建结果报告

### 最新修复项目 (v1.0.1)
- ✅ **NDK版本自动检测**: 优先使用r23+版本，避免ndk-bundle兼容性问题
- ✅ **Shell兼容性修复**: 替换关联数组为函数调用，支持更多Shell环境
- ✅ **构建路径优化**: 确保构建产物正确复制到输出目录

## 📝 更新日志

### v1.0.1 (2025-08-18)
- 🐛 修复NDK版本检测问题：自动使用最新NDK而非ndk-bundle
- 🐛 修复Shell兼容性问题：替换关联数组为函数调用
- ✨ 增强构建脚本错误处理和用户体验
- 📚 更新常见问题解决方案

### v1.0.0 (2025-08-18)
- 初始版本
- 支持Android全架构构建（armeabi-v7a, arm64-v8a, x86, x86_64）
- 支持iOS真机和模拟器构建（包含Apple Silicon支持）
- 添加updateBaseUrl API支持
- 完整的构建文档和脚本

## 📞 技术支持

如遇到构建问题，请检查：

1. **环境配置**: 确保所有前置要求满足
2. **工具版本**: 使用推荐的工具版本
3. **清理重建**: 尝试清理后重新构建
4. **日志分析**: 查看详细的构建日志定位问题

构建成功后，生成的库文件可直接用于Flutter引擎集成或其他原生项目中。