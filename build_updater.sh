#!/bin/bash

# Shorebird Updater 统一构建脚本
# 生成 Android 全架构和 iOS（真机+模拟器A芯片）静态库
# 
# 用法: ./build_updater.sh [选项]
# 选项:
#   --clean         清理之前的构建产物
#   --android-only  仅构建Android库
#   --ios-only      仅构建iOS库
#   --help         显示此帮助信息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
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

# 显示帮助信息
show_help() {
    cat << EOF
Shorebird Updater 构建脚本

用法: $0 [选项]

选项:
  --clean         清理之前的构建产物
  --android-only  仅构建Android库
  --ios-only      仅构建iOS库
  --help         显示此帮助信息

示例:
  $0                    # 构建所有平台
  $0 --clean           # 清理后构建所有平台
  $0 --android-only    # 仅构建Android
  $0 --ios-only        # 仅构建iOS

输出格式:
  build_output/
  ├── android/
  │   ├── armeabi-v7a/libupdater.a
  │   ├── arm64-v8a/libupdater.a
  │   ├── x86/libupdater.a
  │   ├── x86_64/libupdater.a
  │   └── updater.h
  └── ios/
      ├── libupdater_device.a      (arm64)
      ├── libupdater_simulator.a   (x86_64 + arm64)
      └── updater.h

EOF
}

# 解析命令行参数
CLEAN_BUILD=false
ANDROID_ONLY=false
IOS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --android-only)
            ANDROID_ONLY=true
            shift
            ;;
        --ios-only)
            IOS_ONLY=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查当前目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBRARY_DIR="$SCRIPT_DIR/library"
OUTPUT_DIR="$SCRIPT_DIR/build_output"

if [ ! -d "$LIBRARY_DIR" ]; then
    log_error "Library directory not found: $LIBRARY_DIR"
    exit 1
fi

log_info "🚀 开始构建 Shorebird Updater 库..."
log_info "项目目录: $LIBRARY_DIR"
log_info "输出目录: $OUTPUT_DIR"

# 清理构建产物
if [ "$CLEAN_BUILD" = true ]; then
    log_info "🧹 清理之前的构建产物..."
    rm -rf "$OUTPUT_DIR"
    rm -rf "$SCRIPT_DIR/target"
    cd "$LIBRARY_DIR"
    cargo clean
    cd "$SCRIPT_DIR"
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

cd "$LIBRARY_DIR"

# 检查构建环境
check_environment() {
    log_info "🔍 检查构建环境..."
    
    # 检查 Rust
    if ! command -v rustc &> /dev/null; then
        log_error "Rust 未安装，请先安装 Rust: https://rustup.rs/"
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        log_error "Cargo 未安装，请检查 Rust 安装"
        exit 1
    fi
    
    log_info "Rust 版本: $(rustc --version)"
    log_info "Cargo 版本: $(cargo --version)"
    
    # 检查 cargo-ndk (仅在需要Android构建时)
    if [ "$IOS_ONLY" != true ]; then
        if ! command -v cargo &> /dev/null || ! cargo ndk --version &> /dev/null; then
            log_error "cargo-ndk 未安装，请运行: cargo install cargo-ndk"
            exit 1
        fi
        log_info "cargo-ndk 版本: $(cargo ndk --version)"
    fi
    
    # 检查 Xcode (仅在需要iOS构建时)
    if [ "$ANDROID_ONLY" != true ]; then
        if ! command -v xcodebuild &> /dev/null; then
            log_error "Xcode 未安装，无法构建 iOS 库"
            exit 1
        fi
        log_info "Xcode 版本: $(xcodebuild -version | head -1)"
    fi
}

# 安装必要的目标架构
install_targets() {
    log_info "📦 安装必要的 Rust 目标架构..."
    
    if [ "$IOS_ONLY" != true ]; then
        # Android 目标架构
        ANDROID_TARGETS=(
            "aarch64-linux-android"   # ARM64
            "armv7-linux-androideabi" # ARM
            "x86_64-linux-android"    # x86_64
            "i686-linux-android"      # x86
        )
        
        for target in "${ANDROID_TARGETS[@]}"; do
            rustup target add "$target" || log_warning "无法添加目标 $target"
        done
    fi
    
    if [ "$ANDROID_ONLY" != true ]; then
        # iOS 目标架构
        IOS_TARGETS=(
            "aarch64-apple-ios"       # iOS ARM64 (设备)
            "x86_64-apple-ios"        # iOS x86_64 (模拟器)
            "aarch64-apple-ios-sim"   # iOS ARM64 (模拟器 - M1 Mac)
        )
        
        for target in "${IOS_TARGETS[@]}"; do
            rustup target add "$target" || log_warning "无法添加目标 $target"
        done
    fi
}

# 检查并配置 Android NDK
setup_android_ndk() {
    if [ "$IOS_ONLY" = true ]; then
        return 0
    fi
    
    log_info "🔧 配置 Android NDK..."
    
    # 检查 NDK 环境变量
    if [ -z "$ANDROID_NDK_ROOT" ] && [ -z "$NDK_HOME" ]; then
        log_warning "未设置 ANDROID_NDK_ROOT 或 NDK_HOME 环境变量"
        
        # 优先查找最新的 NDK 版本，而不是 ndk-bundle
        if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
            # 查找支持的NDK版本（过滤掉过旧的版本）
            AVAILABLE_NDKS=$(ls "$HOME/Library/Android/sdk/ndk" | grep -E '^(2[3-9]|[3-9][0-9])' | sort -V | tail -n 1)
            if [ -z "$AVAILABLE_NDKS" ]; then
                # 如果没有找到r23+版本，尝试找最新的数字版本
                AVAILABLE_NDKS=$(ls "$HOME/Library/Android/sdk/ndk" | grep -E '^[0-9]+\.' | sort -V | tail -n 1)
            fi
            if [ -n "$AVAILABLE_NDKS" ]; then
                export ANDROID_NDK_ROOT="$HOME/Library/Android/sdk/ndk/$AVAILABLE_NDKS"
                export NDK_HOME="$ANDROID_NDK_ROOT"
                log_info "自动发现 Android NDK: $ANDROID_NDK_ROOT"
            fi
        elif [ -d "$HOME/Android/Sdk/ndk" ]; then
            AVAILABLE_NDKS=$(ls "$HOME/Android/Sdk/ndk" | grep -E '^(2[3-9]|[3-9][0-9])' | sort -V | tail -n 1)
            if [ -z "$AVAILABLE_NDKS" ]; then
                AVAILABLE_NDKS=$(ls "$HOME/Android/Sdk/ndk" | grep -E '^[0-9]+\.' | sort -V | tail -n 1)
            fi
            if [ -n "$AVAILABLE_NDKS" ]; then
                export ANDROID_NDK_ROOT="$HOME/Android/Sdk/ndk/$AVAILABLE_NDKS"
                export NDK_HOME="$ANDROID_NDK_ROOT"
                log_info "自动发现 Android NDK: $ANDROID_NDK_ROOT"
            fi
        fi
        
        # 如果上面没找到，再尝试 ndk-bundle 作为备选
        if [ -z "$ANDROID_NDK_ROOT" ]; then
            POSSIBLE_NDK_PATHS=(
                "$HOME/Android/Sdk/ndk-bundle"
                "$HOME/Library/Android/sdk/ndk-bundle"
                "/usr/local/android-ndk"
                "/opt/android-ndk"
            )
            
            for ndk_path in "${POSSIBLE_NDK_PATHS[@]}"; do
                if [ -d "$ndk_path" ]; then
                    export ANDROID_NDK_ROOT="$ndk_path"
                    export NDK_HOME="$ndk_path"
                    log_warning "使用旧版 NDK: $ANDROID_NDK_ROOT"
                    break
                fi
            done
        fi
    fi
    
    if [ -z "$ANDROID_NDK_ROOT" ]; then
        log_error "未找到 Android NDK，请设置 ANDROID_NDK_ROOT 环境变量"
        log_error "示例: export ANDROID_NDK_ROOT=/path/to/android/ndk"
        exit 1
    fi
    
    log_success "Android NDK 配置完成: $ANDROID_NDK_ROOT"
}

# 构建 Android 库
build_android() {
    if [ "$IOS_ONLY" = true ]; then
        return 0
    fi
    
    log_info "🤖 开始构建 Android 库..."
    
    mkdir -p "$OUTPUT_DIR/android"
    
    # Android 目标架构映射（使用函数而非关联数组以兼容所有shell）
    get_android_arch() {
        case "$1" in
            "aarch64-linux-android") echo "arm64-v8a" ;;
            "armv7-linux-androideabi") echo "armeabi-v7a" ;;
            "x86_64-linux-android") echo "x86_64" ;;
            "i686-linux-android") echo "x86" ;;
            *) echo "$1" ;;
        esac
    }
    
    # 使用 cargo-ndk 构建所有 Android 架构
    log_info "使用 cargo-ndk 构建 Android 库..."
    
    if PKG_CONFIG_ALLOW_CROSS=1 cargo ndk -t armeabi-v7a -t arm64-v8a -t x86 -t x86_64 build --release; then
        log_success "Android 库构建完成"
        
        # 复制静态库文件到输出目录
        ANDROID_TARGETS=(
            "aarch64-linux-android"
            "armv7-linux-androideabi"
            "x86_64-linux-android"
            "i686-linux-android"
        )
        
        for rust_target in "${ANDROID_TARGETS[@]}"; do
            arch_name=$(get_android_arch "$rust_target")
            mkdir -p "$OUTPUT_DIR/android/$arch_name"
            
            if [ -f "../target/$rust_target/release/libupdater.a" ]; then
                cp "../target/$rust_target/release/libupdater.a" "$OUTPUT_DIR/android/$arch_name/"
                log_info "✓ 复制静态库: $arch_name/libupdater.a"
            else
                log_warning "未找到静态库: target/$rust_target/release/libupdater.a"
            fi
        done
        
        # 复制头文件
        if [ -f "include/updater.h" ]; then
            cp "include/updater.h" "$OUTPUT_DIR/android/"
            log_info "✓ Android 头文件已复制"
        fi
    else
        log_error "Android 库构建失败"
        exit 1
    fi
}

# 构建 iOS 库
build_ios() {
    if [ "$ANDROID_ONLY" = true ]; then
        return 0
    fi
    
    log_info "🍎 开始构建 iOS 库..."
    
    mkdir -p "$OUTPUT_DIR/ios"
    
    # 设置 iOS 环境变量
    export IPHONEOS_DEPLOYMENT_TARGET="11.0"
    
    # iOS 目标架构
    IOS_TARGETS=(
        "aarch64-apple-ios"       # iOS ARM64 (设备)
        "x86_64-apple-ios"        # iOS x86_64 (模拟器)
        "aarch64-apple-ios-sim"   # iOS ARM64 (模拟器 - M1 Mac)
    )
    
    # 构建各个 iOS 架构
    IOS_LIBS=()
    
    for target in "${IOS_TARGETS[@]}"; do
        log_info "构建 iOS 目标: $target"
        
        # 根据目标设置不同的SDK
        case $target in
            "aarch64-apple-ios")
                export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
                ;;
            "x86_64-apple-ios"|"aarch64-apple-ios-sim")
                export SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
                ;;
        esac
        
        if cargo build --release --target "$target"; then
            IOS_LIBS+=("../target/$target/release/libupdater.a")
            log_success "✓ iOS $target 构建完成"
        else
            log_error "iOS $target 构建失败"
            exit 1
        fi
    done
    
    # 创建设备库（仅ARM64）
    if [ -f "../target/aarch64-apple-ios/release/libupdater.a" ]; then
        cp "../target/aarch64-apple-ios/release/libupdater.a" "$OUTPUT_DIR/ios/libupdater_device.a"
        log_info "✓ iOS 设备库创建完成"
    fi
    
    # 创建模拟器库（x86_64 + ARM64）
    SIM_LIBS=()
    if [ -f "../target/x86_64-apple-ios/release/libupdater.a" ]; then
        SIM_LIBS+=("../target/x86_64-apple-ios/release/libupdater.a")
    fi
    if [ -f "../target/aarch64-apple-ios-sim/release/libupdater.a" ]; then
        SIM_LIBS+=("../target/aarch64-apple-ios-sim/release/libupdater.a")
    fi
    
    if [ ${#SIM_LIBS[@]} -gt 0 ]; then
        lipo -create "${SIM_LIBS[@]}" -output "$OUTPUT_DIR/ios/libupdater_simulator.a"
        log_info "✓ iOS 模拟器库创建完成"
        
        # 显示架构信息
        log_info "iOS 库架构信息:"
        log_info "  设备版本: $(lipo -info "$OUTPUT_DIR/ios/libupdater_device.a" | cut -d: -f3-)"
        log_info "  模拟器版本: $(lipo -info "$OUTPUT_DIR/ios/libupdater_simulator.a" | cut -d: -f3-)"
    fi
    
    # 复制头文件
    if [ -f "include/updater.h" ]; then
        cp "include/updater.h" "$OUTPUT_DIR/ios/"
        log_info "✓ iOS 头文件已复制"
    fi
}

# 生成构建报告
generate_report() {
    log_info "📊 生成构建报告..."
    
    BUILD_REPORT="$OUTPUT_DIR/build_report.txt"
    cat > "$BUILD_REPORT" << EOF
Shorebird Updater 库构建报告
==========================

构建时间: $(date)
构建机器: $(uname -a)
Rust 版本: $(rustc --version)
EOF

    if [ "$IOS_ONLY" != true ]; then
        echo "cargo-ndk 版本: $(cargo ndk --version)" >> "$BUILD_REPORT"
        echo "Android NDK: $(basename "$ANDROID_NDK_ROOT" 2>/dev/null || echo "未配置")" >> "$BUILD_REPORT"
    fi
    
    if [ "$ANDROID_ONLY" != true ]; then
        echo "Xcode 版本: $(xcodebuild -version | head -1)" >> "$BUILD_REPORT"
    fi

    echo "" >> "$BUILD_REPORT"
    echo "=== 构建结果 ===" >> "$BUILD_REPORT"
    echo "" >> "$BUILD_REPORT"

    # Android 库信息
    if [ "$IOS_ONLY" != true ] && [ -d "$OUTPUT_DIR/android" ]; then
        echo "Android 静态库 (各架构独立):" >> "$BUILD_REPORT"
        find "$OUTPUT_DIR/android" -name "*.a" | sort | while read file; do
            size=$(du -h "$file" | cut -f1)
            arch=$(basename $(dirname "$file"))
            echo "  $arch: $(basename "$file") ($size)" >> "$BUILD_REPORT"
        done
        echo "" >> "$BUILD_REPORT"
    fi

    # iOS 库信息
    if [ "$ANDROID_ONLY" != true ] && [ -d "$OUTPUT_DIR/ios" ]; then
        echo "iOS 静态库 (按设备类型分组):" >> "$BUILD_REPORT"
        find "$OUTPUT_DIR/ios" -name "*.a" | sort | while read file; do
            size=$(du -h "$file" | cut -f1)
            filename=$(basename "$file")
            if [[ "$filename" == *"device"* ]]; then
                desc="真机版本"
                arch_info="$(lipo -info "$file" | cut -d: -f3-)"
            else
                desc="模拟器版本"
                arch_info="$(lipo -info "$file" | cut -d: -f3-)"
            fi
            echo "  $desc: $filename ($size)" >> "$BUILD_REPORT"
            echo "    架构:$arch_info" >> "$BUILD_REPORT"
        done
        echo "" >> "$BUILD_REPORT"
    fi

    echo "头文件:" >> "$BUILD_REPORT"
    find "$OUTPUT_DIR" -name "*.h" | sort | while read file; do
        echo "  $file" >> "$BUILD_REPORT"
    done

    echo "" >> "$BUILD_REPORT"
    echo "=== 与官方格式对比 ===" >> "$BUILD_REPORT"
    if [ "$IOS_ONLY" != true ]; then
        echo "✓ Android: 全架构独立静态库 (.a 格式)" >> "$BUILD_REPORT"
    fi
    if [ "$ANDROID_ONLY" != true ]; then
        echo "✓ iOS: 按设备类型分组的静态库" >> "$BUILD_REPORT"
        echo "✓ iOS 模拟器: 支持 A 芯片架构 (arm64)" >> "$BUILD_REPORT"
    fi
    echo "✓ 头文件: 各平台包含对应的 updater.h" >> "$BUILD_REPORT"
}

# 显示最终结果
show_results() {
    log_success "🎉 构建完成！"
    log_info "输出目录: $OUTPUT_DIR"
    
    echo ""
    log_info "📁 构建产物目录结构:"
    if command -v tree &> /dev/null; then
        tree "$OUTPUT_DIR"
    else
        find "$OUTPUT_DIR" -type f | sort | sed 's/^/  /'
    fi
    
    echo ""
    log_info "📊 文件大小统计:"
    
    if [ "$IOS_ONLY" != true ] && [ -d "$OUTPUT_DIR/android" ]; then
        echo "Android 库:"
        find "$OUTPUT_DIR/android" -name "*.a" | sort | while read file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            arch=$(basename $(dirname "$file"))
            echo "  $arch: $size"
        done
    fi
    
    if [ "$ANDROID_ONLY" != true ] && [ -d "$OUTPUT_DIR/ios" ]; then
        echo "iOS 库:"
        find "$OUTPUT_DIR/ios" -name "*.a" | sort | while read file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            filename=$(basename "$file")
            echo "  $filename: $size"
        done
    fi
    
    echo ""
    log_info "📋 构建报告: $OUTPUT_DIR/build_report.txt"
    
    echo ""
    log_success "✅ 所有构建任务已完成！"
    echo ""
    log_info "💡 使用提示:"
    echo "  - Android 库位于: $OUTPUT_DIR/android/"
    echo "  - iOS 库位于: $OUTPUT_DIR/ios/"
    echo "  - 可直接用于 Flutter 引擎集成"
}

# 主构建流程
main() {
    check_environment
    install_targets
    setup_android_ndk
    build_android
    build_ios
    generate_report
    show_results
}

# 执行主流程
main

exit 0