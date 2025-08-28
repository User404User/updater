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

# iOS 使用原生实现，不需要生成库文件

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

# iOS 使用原生实现，不需要构建库
log_info "🍎 iOS 使用原生实现，跳过库构建"

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

# iOS 不需要复制库文件
log_info "✓ iOS 使用原生实现，无需复制库文件"

# 生成使用说明
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# Shorebird Network Updater

这是 Shorebird Updater 的网络版本，用于独立的网络功能。

## 文件说明

### Android
- `android/*/libshorebird_updater_network.so` - 各架构的动态库

### iOS
- iOS 使用原生实现，无需额外库文件

### 头文件
- `shorebird_updater_network.h` - C API 头文件

## 使用方法

### Android
将对应架构的 .so 文件复制到 `app/src/main/jniLibs/{架构}/`

### iOS
iOS 使用原生实现

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