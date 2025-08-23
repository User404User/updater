#!/bin/bash

# Shorebird Network Updater 构建脚本
# 构建网络版本的库，用于独立的网络功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBRARY_DIR="$SCRIPT_DIR/library_network"
OUTPUT_DIR="$SCRIPT_DIR/build_network"
PLUGIN_DIR="$SCRIPT_DIR/shorebird_code_push_network"
CARGO_TARGET_DIR="$SCRIPT_DIR/target_network"

log_info "🚀 开始构建 Shorebird Network Updater..."
log_info "项目目录: $LIBRARY_DIR"
log_info "输出目录: $OUTPUT_DIR"

# 🧹 清理所有目标文件 - 确保干净的构建环境
log_info "🧹 清理构建环境..."

# 1. 清理构建输出目录
log_info "   清理构建输出目录: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/android"
mkdir -p "$OUTPUT_DIR/ios"

# 2. 清理 Flutter 插件的 Android jniLibs 目录
ANDROID_JNILIBS_DIR="$PLUGIN_DIR/android/src/main/jniLibs"
if [ -d "$ANDROID_JNILIBS_DIR" ]; then
    log_info "   清理 Android jniLibs 目录: $ANDROID_JNILIBS_DIR"
    rm -rf "$ANDROID_JNILIBS_DIR"/*
    # 重建架构目录结构
    mkdir -p "$ANDROID_JNILIBS_DIR/arm64-v8a"
    mkdir -p "$ANDROID_JNILIBS_DIR/armeabi-v7a"
    mkdir -p "$ANDROID_JNILIBS_DIR/x86_64"
    mkdir -p "$ANDROID_JNILIBS_DIR/x86"
fi

# 3. 清理 Flutter 插件的 iOS 目录中的库文件
IOS_PLUGIN_DIR="$PLUGIN_DIR/ios"
if [ -d "$IOS_PLUGIN_DIR" ]; then
    log_info "   清理 iOS 插件目录中的库文件: $IOS_PLUGIN_DIR"
    # 删除旧的静态库文件
    rm -f "$IOS_PLUGIN_DIR"/libshorebird_updater_network*.a
    rm -f "$IOS_PLUGIN_DIR/shorebird_updater_network.h"
    # 删除旧的 XCFramework
    rm -rf "$IOS_PLUGIN_DIR/ShorebirdUpdaterNetwork.xcframework"
fi

# 4. 清理 Rust 构建缓存
log_info "   清理 Rust 构建缓存: $CARGO_TARGET_DIR"
rm -rf "$CARGO_TARGET_DIR"

log_success "✓ 构建环境清理完成"

cd "$LIBRARY_DIR"

# 为网络版本创建特殊的 Cargo.toml
cat > Cargo_network.toml << 'EOF'
[package]
name = "shorebird_updater_network"
version = "0.1.0"
edition = "2021"

[lib]
# Android 使用动态库，iOS 使用静态库
crate-type = ["cdylib", "staticlib"]

[dependencies]
anyhow = { version = "1.0.69", features = [] }
base64 = "0.22.0"
bipatch = "1.0.0"
comde = { version = "0.2.3", default-features = false, features = ["zstandard"] }
dyn-clone = "1.0.16"
hex = "0.4.3"
http = "1.2.0"
libc = "0.2.98"
log = "0.4.14"
once_cell = "1.17.1"
pipe = "0.4.0"
reqwest = { version = "0.12", default-features = false, features = ["blocking", "json", "rustls-tls"] }
ring = "0.17.8"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0.93"
serde_yaml = "0.9.19"
sha2 = "0.10.6"
url = "2.4.0"
zip = { version = "0.6.4", default-features = false, features = ["deflate"] }

[target.'cfg(target_os = "android")'.dependencies]
android_logger = "0.13.0"
log-panics = { version = "2", default-features = false }

[target.'cfg(any(target_os = "ios", target_os = "macos"))'.dependencies]
log-panics = { version = "2", features = ["with-backtrace"] }
oslog = "0.2.0"

[target.'cfg(any(target_os = "linux", target_os = "windows"))'.dependencies]
simple_logger = "5.0.0"

[build-dependencies]
cbindgen = "0.24.0"
EOF

# 备份原始 Cargo.toml
cp Cargo.toml Cargo.toml.backup
cp Cargo_network.toml Cargo.toml

# 构建 Android
log_info "🤖 构建 Android 网络库..."
export CARGO_TARGET_DIR

# Android 架构映射函数
get_android_arch() {
    case "$1" in
        "aarch64-linux-android") echo "arm64-v8a" ;;
        "armv7-linux-androideabi") echo "armeabi-v7a" ;;
        "x86_64-linux-android") echo "x86_64" ;;
        "i686-linux-android") echo "x86" ;;
        *) echo "$1" ;;
    esac
}

# 使用 cargo-ndk 构建
if command -v cargo-ndk &> /dev/null; then
    PKG_CONFIG_ALLOW_CROSS=1 cargo ndk \
        -t armeabi-v7a \
        -t arm64-v8a \
        -t x86 \
        -t x86_64 \
        build --release
    
    # 复制 Android 动态库
    ANDROID_TARGETS=(
        "aarch64-linux-android"
        "armv7-linux-androideabi"
        "x86_64-linux-android"
        "i686-linux-android"
    )
    
    for rust_target in "${ANDROID_TARGETS[@]}"; do
        android_arch=$(get_android_arch "$rust_target")
        mkdir -p "$OUTPUT_DIR/android/$android_arch"
        
        if [ -f "$CARGO_TARGET_DIR/$rust_target/release/libshorebird_updater_network.so" ]; then
            cp "$CARGO_TARGET_DIR/$rust_target/release/libshorebird_updater_network.so" \
               "$OUTPUT_DIR/android/$android_arch/"
            log_success "✓ $android_arch/libshorebird_updater_network.so"
        fi
    done
else
    log_error "cargo-ndk 未安装，跳过 Android 构建"
fi

# 构建 iOS
log_info "🍎 构建 iOS 网络库..."
export IPHONEOS_DEPLOYMENT_TARGET="11.0"

# iOS 设备版本 (arm64)
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
cargo build --release --target aarch64-apple-ios

# iOS 模拟器版本
export SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)

# x86_64 模拟器
cargo build --release --target x86_64-apple-ios

# arm64 模拟器 (M1)
cargo build --release --target aarch64-apple-ios-sim

# 创建 XCFramework
log_info "📦 创建 XCFramework..."

# 创建临时目录存放framework
mkdir -p "$OUTPUT_DIR/ios/temp_frameworks/device"
mkdir -p "$OUTPUT_DIR/ios/temp_frameworks/simulator"
DEVICE_FRAMEWORK="$OUTPUT_DIR/ios/temp_frameworks/device/ShorebirdUpdaterNetwork.framework"
SIMULATOR_FRAMEWORK="$OUTPUT_DIR/ios/temp_frameworks/simulator/ShorebirdUpdaterNetwork.framework"

# 创建设备版本 framework
mkdir -p "$DEVICE_FRAMEWORK"
if [ -f "$CARGO_TARGET_DIR/aarch64-apple-ios/release/libshorebird_updater_network.a" ]; then
    cp "$CARGO_TARGET_DIR/aarch64-apple-ios/release/libshorebird_updater_network.a" \
       "$DEVICE_FRAMEWORK/ShorebirdUpdaterNetwork"
    log_success "✓ iOS 设备库 (arm64)"
fi

# 创建模拟器通用库
if [ -f "$CARGO_TARGET_DIR/x86_64-apple-ios/release/libshorebird_updater_network.a" ] && \
   [ -f "$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release/libshorebird_updater_network.a" ]; then
    
    # 创建模拟器版本 framework
    mkdir -p "$SIMULATOR_FRAMEWORK"
    lipo -create \
        "$CARGO_TARGET_DIR/x86_64-apple-ios/release/libshorebird_updater_network.a" \
        "$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release/libshorebird_updater_network.a" \
        -output "$SIMULATOR_FRAMEWORK/ShorebirdUpdaterNetwork"
    log_success "✓ iOS 模拟器通用库"
fi

# 创建 Info.plist 文件（设备版本）
cat > "$DEVICE_FRAMEWORK/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ShorebirdUpdaterNetwork</string>
    <key>CFBundleIdentifier</key>
    <string>dev.shorebird.ShorebirdUpdaterNetwork</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ShorebirdUpdaterNetwork</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

# 创建 Info.plist 文件（模拟器版本）
cat > "$SIMULATOR_FRAMEWORK/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ShorebirdUpdaterNetwork</string>
    <key>CFBundleIdentifier</key>
    <string>dev.shorebird.ShorebirdUpdaterNetwork</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ShorebirdUpdaterNetwork</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneSimulator</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

# 创建 Headers 目录并复制头文件
mkdir -p "$DEVICE_FRAMEWORK/Headers"
mkdir -p "$SIMULATOR_FRAMEWORK/Headers"
if [ -f "include/updater.h" ]; then
    cp "include/updater.h" "$DEVICE_FRAMEWORK/Headers/"
    cp "include/updater.h" "$SIMULATOR_FRAMEWORK/Headers/"
fi

# 创建 XCFramework
if [ -f "$DEVICE_FRAMEWORK/ShorebirdUpdaterNetwork" ] && [ -f "$SIMULATOR_FRAMEWORK/ShorebirdUpdaterNetwork" ]; then
    xcodebuild -create-xcframework \
        -framework "$DEVICE_FRAMEWORK" \
        -framework "$SIMULATOR_FRAMEWORK" \
        -output "$OUTPUT_DIR/ios/ShorebirdUpdaterNetwork.xcframework"
    
    if [ $? -eq 0 ]; then
        log_success "✓ XCFramework 创建成功"
        # 清理临时文件
        rm -rf "$OUTPUT_DIR/ios/temp_frameworks"
    else
        log_error "✗ XCFramework 创建失败"
    fi
else
    log_error "✗ Framework 文件不存在，无法创建 XCFramework"
fi

# 生成头文件
log_info "📄 生成头文件..."
if [ -f "include/updater.h" ]; then
    cp "include/updater.h" "$OUTPUT_DIR/shorebird_updater_network.h"
    log_success "✓ 头文件已复制"
fi

# 恢复原始 Cargo.toml
mv Cargo.toml.backup Cargo.toml
rm -f Cargo_network.toml

# 复制构建产物到 Flutter 插件目录
log_info "📋 复制文件到 Flutter 插件..."

# 复制 Android 库
if [ -d "$OUTPUT_DIR/android" ]; then
    cp -r "$OUTPUT_DIR/android"/* "$PLUGIN_DIR/android/src/main/jniLibs/"
    log_success "✓ Android 库已复制到插件"
fi

# 复制 iOS XCFramework
if [ -d "$OUTPUT_DIR/ios/ShorebirdUpdaterNetwork.xcframework" ]; then
    # 先删除旧的静态库文件
    rm -f "$PLUGIN_DIR/ios/libshorebird_updater_network"*.a
    rm -f "$PLUGIN_DIR/ios/shorebird_updater_network.h"
    
    # 复制 XCFramework
    cp -r "$OUTPUT_DIR/ios/ShorebirdUpdaterNetwork.xcframework" "$PLUGIN_DIR/ios/"
    log_success "✓ iOS XCFramework 已复制到插件"
fi

# 生成使用说明
cat > "$OUTPUT_DIR/README.md" << 'EOF'
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
EOF

log_success "🎉 构建完成！"
log_info "输出目录: $OUTPUT_DIR"

# 显示构建结果
echo ""
log_info "📁 构建产物："
find "$OUTPUT_DIR" -type f -name "*.so" -o -name "*.a" | sort