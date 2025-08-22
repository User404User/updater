import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'generated/updater_bindings.g.dart';
import 'updater_network.dart';

/// Configuration for initializing the network updater
class NetworkUpdaterConfig {
  /// App ID from shorebird.yaml
  final String appId;
  
  /// Release version (e.g., "1.0.0+1")
  final String releaseVersion;
  
  /// Update channel (default: "stable")
  final String channel;
  
  /// Whether to auto-update (default: false for network library)
  final bool autoUpdate;
  
  /// Base URL for the API (can be changed later with updateBaseUrl)
  final String? baseUrl;
  
  /// Download URL for patches (can be changed later with updateDownloadUrl)
  /// If not provided, base URL will be used for domain replacement
  final String? downloadUrl;
  
  /// Optional paths to the original libapp.so files
  final List<String>? originalLibappPaths;

  const NetworkUpdaterConfig({
    required this.appId,
    required this.releaseVersion,
    this.channel = 'stable',
    this.autoUpdate = false,
    this.baseUrl,
    this.downloadUrl,
    this.originalLibappPaths,
  });
}

/// Initialize the network updater with proper configuration
class NetworkUpdaterInitializer {
  static bool _initialized = false;
  
  /// Initialize the network updater library
  static Future<bool> initialize(NetworkUpdaterConfig config) async {
    if (_initialized) {
      debugPrint('Network updater already initialized');
      return true;
    }
    
    try {
      debugPrint('Initializing network updater...');
      
      // Get platform-specific directories
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();
      
      debugPrint('App storage dir: ${appDir.path}');
      debugPrint('Cache dir: ${cacheDir.path}');
      
      // Create directories if they don't exist
      final patchesDir = Directory('${appDir.path}/patches');
      if (!await patchesDir.exists()) {
        await patchesDir.create(recursive: true);
        debugPrint('Created patches directory');
      }
      
      final downloadsDir = Directory('${cacheDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
        debugPrint('Created downloads directory');
      }
      
      // Initialize the native library
      final result = _initializeNative(
        appStorageDir: appDir.path,
        codeCacheDir: cacheDir.path,
        config: config,
      );
      
      if (result) {
        _initialized = true;
        debugPrint('Network updater initialized successfully');
        
        // Set download URL if provided
        if (config.downloadUrl != null) {
          final bindings = UpdaterNetwork.networkBindings;
          final downloadUrlPtr = config.downloadUrl!.toNativeUtf8().cast<Char>();
          try {
            final urlResult = bindings.shorebird_update_download_url(downloadUrlPtr);
            debugPrint('Download URL update result: $urlResult');
          } finally {
            malloc.free(downloadUrlPtr);
          }
        }
      } else {
        debugPrint('Failed to initialize network updater');
      }
      
      return result;
      
    } catch (e) {
      debugPrint('Error initializing network updater: $e');
      return false;
    }
  }
  
  /// Call the native initialization function
  static bool _initializeNative({
    required String appStorageDir,
    required String codeCacheDir,
    required NetworkUpdaterConfig config,
  }) {
    final bindings = UpdaterNetwork.networkBindings;
    
    // Allocate memory for parameters
    final appParams = malloc<AppParameters>();
    final releaseVersionPtr = config.releaseVersion.toNativeUtf8().cast<Char>();
    final appStorageDirPtr = appStorageDir.toNativeUtf8().cast<Char>();
    final codeCacheDirPtr = codeCacheDir.toNativeUtf8().cast<Char>();
    
    // Set up app parameters
    appParams.ref.release_version = releaseVersionPtr;
    appParams.ref.app_storage_dir = appStorageDirPtr;
    appParams.ref.code_cache_dir = codeCacheDirPtr;
    
    // Handle original libapp paths - for network library, let Rust handle empty paths
    Pointer<Pointer<Char>>? libappPathsPtr;
    List<Pointer<Utf8>> allocatedPaths = [];
    
    if (config.originalLibappPaths != null && config.originalLibappPaths!.isNotEmpty) {
      libappPathsPtr = malloc<Pointer<Char>>(config.originalLibappPaths!.length);
      for (int i = 0; i < config.originalLibappPaths!.length; i++) {
        final pathPtr = config.originalLibappPaths![i].toNativeUtf8();
        allocatedPaths.add(pathPtr);
        libappPathsPtr[i] = pathPtr.cast<Char>();
      }
      appParams.ref.original_libapp_paths = libappPathsPtr.cast<Pointer<Char>>();
      appParams.ref.original_libapp_paths_size = config.originalLibappPaths!.length;
    } else {
      // For network library, pass empty array and let Rust handle it
      appParams.ref.original_libapp_paths = nullptr;
      appParams.ref.original_libapp_paths_size = 0;
    }
    
    // Create file callbacks
    final fileCallbacks = _createFileCallbacks();
    
    // Create YAML configuration
    final yamlConfig = '''
app_id: "${config.appId}"
channel: "${config.channel}"
auto_update: ${config.autoUpdate}
${config.baseUrl != null ? 'base_url: "${config.baseUrl}"' : ''}
''';
    
    debugPrint('YAML config:\n$yamlConfig');
    
    final yamlPtr = yamlConfig.toNativeUtf8().cast<Char>();
    
    try {
      // Call initialization function
      bool result;
      if (Platform.isIOS) {
        result = bindings.shorebird_init_net(appParams, fileCallbacks, yamlPtr);
      } else {
        result = bindings.shorebird_init(appParams, fileCallbacks, yamlPtr);
      }
      
      debugPrint('Native init result: $result');
      return result;
      
    } finally {
      // Clean up allocated memory
      malloc.free(appParams);
      malloc.free(releaseVersionPtr);
      malloc.free(appStorageDirPtr);
      malloc.free(codeCacheDirPtr);
      malloc.free(yamlPtr);
      
      if (libappPathsPtr != null) {
        malloc.free(libappPathsPtr);
      }
      for (final ptr in allocatedPaths) {
        malloc.free(ptr);
      }
    }
  }
  
  /// Create file callbacks for the native library
  static FileCallbacks _createFileCallbacks() {
    // For network library, we can use dummy callbacks
    // since we're not actually reading the original libapp files
    final callbacks = malloc<FileCallbacks>();
    
    // Set the function pointers
    callbacks.ref.open = Pointer.fromFunction<Pointer<Void> Function()>(_fileOpen);
    callbacks.ref.read = Pointer.fromFunction<UintPtr Function(Pointer<Void>, Pointer<Uint8>, UintPtr)>(_fileRead, 0);
    callbacks.ref.seek = Pointer.fromFunction<Int64 Function(Pointer<Void>, Int64, Int32)>(_fileSeek, 0);
    callbacks.ref.close = Pointer.fromFunction<Void Function(Pointer<Void>)>(_fileClose);
    
    // Return the struct value, not the pointer
    final result = callbacks.ref;
    malloc.free(callbacks);
    return result;
  }
  
  // Dummy file callback implementations
  static Pointer<Void> _fileOpen() => nullptr;
  static int _fileRead(Pointer<Void> handle, Pointer<Uint8> buffer, int count) => 0;
  static int _fileSeek(Pointer<Void> handle, int offset, int whence) => 0;
  static void _fileClose(Pointer<Void> handle) {}
  
  /// Check if the network updater is initialized
  static bool get isInitialized => _initialized;
  
  /// Reset initialization state (mainly for testing)
  @visibleForTesting
  static void reset() {
    _initialized = false;
  }
}