# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shorebird Updater is a Rust-based code push system for Flutter applications that enables over-the-air updates. The project consists of:
- Core updater library (`library/`) - Runtime library linked into Flutter Engine
- Network-only version (`library_network/`) - Standalone version for downloading patches
- Patch tool (`patch/`) - Developer tooling to package updates
- Dart bindings (`shorebird_code_push_network/`) - Flutter package for network version

## Essential Commands

### Build Commands
```bash
# Build the network version (all platforms)
./build_network.sh

# Build for Android manually
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86 -t x86_64 build --release

# Build for iOS device
export IPHONEOS_DEPLOYMENT_TARGET="11.0"
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
cargo build --release --target aarch64-apple-ios

# Build for iOS simulator
export SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
cargo build --release --target x86_64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
```

### Test Commands
```bash
# Run all Rust tests
cargo test

# Run tests with output
cargo test -- --nocapture

# Run tests for specific package
cargo test -p library_network
cargo test -p patch

# Run Flutter tests (in shorebird_code_push_network directory)
cd shorebird_code_push_network
flutter test

# Run example app
cd shorebird_code_push_network/example
flutter run
```

### Lint & Quality Commands
```bash
# Format Rust code
cargo fmt

# Check Rust formatting
cargo fmt -- --check

# Run Rust linter
cargo clippy --all-targets --all-features

# Check code without building
cargo check

# Flutter/Dart analysis
cd shorebird_code_push_network
flutter analyze
dart format --set-exit-if-changed .
```

## Architecture

### Workspace Structure
```
updater/
├── library/              # Core updater (linked into libflutter.so)
├── library_network/      # Network-only version (avoids symbol conflicts)
├── patch/                # Patch creation tool
└── shorebird_code_push_network/  # Dart bindings for network version
```

### Key Components

1. **Network Client** (`library_network/src/network_client.rs`) - Handles HTTP requests for downloading patches
2. **Cache Manager** (`library_network/src/cache/`) - Manages patch storage and state persistence
3. **C API** (`library_network/src/c_api/`) - FFI interface for Dart bindings
4. **Updater State** (`library_network/src/cache/updater_state.rs`) - Tracks current patch and update status

### Platform Integration

- **Android**: Produces `.so` files for each architecture (armeabi-v7a, arm64-v8a, x86, x86_64)
- **iOS**: Produces XCFramework with device and simulator architectures
- **Dart FFI**: Uses `ffigen` to generate bindings from C headers

### File Locations

The updater creates these directories at runtime:
```
app_storage_dir/shorebird_updater/
├── state.json
├── patches_state.json
└── patches/{number}/dlc.vmcode

code_cache_dir/shorebird_updater/downloads/
```

## Development Guidelines

1. **Thread Safety**: All public APIs must be thread-safe as they're called from multiple threads
2. **Error Handling**: Fail open - continue with current version on any error
3. **Symbol Names**: Network version uses different library names to avoid conflicts
4. **Trust Model**: Network and disk are untrusted; running software and APK are trusted
5. **State Management**: Always verify patch compatibility before applying

## Common Development Tasks

### Adding a New API
1. Add Rust implementation in `library_network/src/`
2. Expose via C API in `library_network/src/c_api/`
3. Update header file `library_network/include/updater.h`
4. Regenerate Dart bindings: `cd shorebird_code_push_network && dart run ffigen`
5. Add Dart wrapper in `shorebird_code_push_network/lib/src/`

### Working with libapp.so Paths

The network library needs access to libapp.so for patch compression. Here's how to handle it:

#### Android
- libapp.so is located at: `/data/app/~~<random>/<package>/lib/<arch>/libapp.so`
- Use `LibappPathHelper.getLibappPaths()` to get the correct paths automatically
- For testing with extracted APKs: `LibappPathHelper.getManualLibappPaths(basePath: '/path/to/apk', architecture: 'arm64-v8a')`

#### iOS
- App binary is at: `<bundle>/Frameworks/App.framework/App`
- The helper automatically finds the correct path

#### Example Usage
```dart
// Automatic path detection
final libappPaths = await LibappPathHelper.getLibappPaths();

// Initialize with paths
final config = NetworkUpdaterConfig(
  appId: 'your-app-id',
  releaseVersion: '1.0.0+1',
  originalLibappPaths: libappPaths,
);
```

### Testing Changes
1. Build the network library: `./build_network.sh`
2. Run Rust tests: `cargo test`
3. Run Flutter tests: `cd shorebird_code_push_network && flutter test`
4. Test in example app: `cd shorebird_code_push_network/example && flutter run`

### Debugging Tips
- Set `RUST_LOG=debug` for verbose logging
- Check `state.json` and `patches_state.json` for updater state
- Use `cargo test -- --nocapture` to see print statements in tests