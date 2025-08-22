# Shorebird Updater Initialization Parameters

This document explains how the official Shorebird updater obtains its initialization parameters.

## Overview

The Shorebird updater is initialized through the `shorebird_init` function in the Flutter engine, which passes several key parameters:

1. **app_id** - Unique identifier for the app
2. **release_version** - Version of the current release
3. **app_storage_dir** - Persistent storage directory
4. **code_cache_dir** - Temporary cache directory
5. **original_libapp_paths** - Paths to the original AOT libraries

## Parameter Sources

### 1. app_id

- **Source**: `shorebird.yaml` file
- **Location**: Embedded in the app bundle during `shorebird release`
- **Example**: `app_id: 1692ba14-0c8d-490e-9593-13815d2ac1cf`
- **How it's obtained**: The Flutter engine reads the YAML file from the app bundle and passes its content to `shorebird_init`

### 2. release_version

- **Source**: `pubspec.yaml` version field
- **Example**: `1.0.0+1`
- **How it's obtained**: The Flutter engine extracts this from the app's metadata during initialization
- **Note**: This is the version that was built with `shorebird release`

### 3. app_storage_dir

- **Purpose**: Persistent storage for updater state that survives app updates
- **Platform-specific paths**:
  - **Android**: `getFilesDir()` - typically `/data/data/<package>/files`
  - **iOS**: `NSDocumentDirectory` - typically `<app_sandbox>/Documents`
- **How it's obtained**: The Flutter engine uses platform APIs to get the appropriate directory

### 4. code_cache_dir

- **Purpose**: Temporary storage for downloaded patches
- **Platform-specific paths**:
  - **Android**: `getCacheDir()` - typically `/data/data/<package>/cache`
  - **iOS**: `NSCachesDirectory` - typically `<app_sandbox>/Library/Caches`
- **How it's obtained**: The Flutter engine uses platform APIs to get the cache directory
- **Note**: The updater creates a `downloads` subdirectory within this path

### 5. original_libapp_paths

- **Purpose**: Paths to the original AOT-compiled Dart code
- **Platform-specific**:
  - **Android**: Array of paths like `/data/app/<package>/base.apk!/lib/<arch>/libapp.so`
    - Architectures: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`
  - **iOS**: Single path to `App.framework/App` inside the app bundle
- **How it's obtained**: The Flutter engine knows where it loaded the AOT code from

## Initialization Flow

```c
// In the Flutter engine (C++)
AppParameters params = {
  .release_version = "1.0.0+1",              // from pubspec.yaml
  .original_libapp_paths = libapp_paths,     // platform-specific AOT paths
  .original_libapp_paths_size = count,       // number of paths
  .app_storage_dir = "/path/to/documents",   // persistent storage
  .code_cache_dir = "/path/to/cache",        // temporary storage
};

FileCallbacks callbacks = {
  .open = open_callback,
  .read = read_callback,
  .seek = seek_callback,
  .close = close_callback,
};

const char* yaml_content = "<content of shorebird.yaml>";

bool success = shorebird_init(&params, callbacks, yaml_content);
```

## Data Flow

1. **Flutter Engine** collects all parameters from various sources
2. **shorebird_init** (C API) receives the parameters
3. **Rust updater** parses YAML and creates internal configuration:
   ```rust
   UpdateConfig {
       storage_dir: PathBuf::from(app_storage_dir),
       download_dir: PathBuf::from(code_cache_dir).join("downloads"),
       app_id: yaml.app_id,
       release_version: release_version,
       channel: yaml.channel.unwrap_or("stable"),
       auto_update: yaml.auto_update.unwrap_or(true),
       base_url: yaml.base_url.unwrap_or("https://api.shorebird.dev"),
       libapp_path: PathBuf::from(original_libapp_paths[0]),
       // ... other fields
   }
   ```

## Directory Structure Created

After initialization, the updater creates:

```
app_storage_dir/
└── shorebird_updater/    # Shorebird updater directory
    ├── state.json        # Persistent state (current patch, etc.)
    ├── patches_state.json # Patches state
    └── patches/          # Installed patches
        └── <patch_number>/
            └── dlc.vmcode # Patch artifact

code_cache_dir/
└── shorebird_updater/    # Shorebird updater directory
    └── downloads/        # Temporary download directory
        └── <patch_files> # Downloaded but not installed patches
```

## Example Implementation

See `shorebird_code_push_network/example/lib/test_init_params.dart` for a demonstration of how to obtain these parameters in a Flutter app.

## Important Notes

1. The initialization happens automatically when a Shorebird-enabled app starts
2. Dart/Flutter code cannot directly call `shorebird_init` - it's called by the engine
3. The parameters are platform-specific and managed by the Flutter engine
4. The `shorebird.yaml` file is embedded during `shorebird release` command
5. All paths must be absolute paths, not relative paths