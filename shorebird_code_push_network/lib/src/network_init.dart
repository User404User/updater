import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  
  static const MethodChannel _channel = MethodChannel('dev.shorebird.code_push');
  
  /// Get storage paths from native platform
  static Future<Map<String, String>?> _getStoragePaths() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStoragePaths');
      if (result != null) {
        return result.cast<String, String>();
      }
    } catch (e) {
      debugPrint('Error getting storage paths from native: $e');
    }
    return null;
  }
  
  /// Initialize the network updater library
  static Future<bool> initialize(NetworkUpdaterConfig config) async {
    if (_initialized) {
      debugPrint('Network updater already initialized');
      return true;
    }
    
    try {
      debugPrint('Initializing network updater...');
      
      // Get platform-specific directories
      // Get storage paths from native platform
      final storagePaths = await _getStoragePaths();
      
      String appStorageDir;
      String codeCacheDir;
      
      if (storagePaths != null) {
        // Use native-provided paths
        appStorageDir = storagePaths['appStorageDir']!;
        codeCacheDir = storagePaths['codeCacheDir']!;
        debugPrint('Using native storage paths');
      } else {
        // Fallback to path_provider
        // IMPORTANT: Must match paths used by official Shorebird Engine!
        // Engine uses context.getFilesDir() which returns /data/user/0/.../files
        // NOT getApplicationDocumentsDirectory() which returns /data/user/0/.../app_flutter
        
        if (Platform.isAndroid) {
          // On Android, we need to use the 'files' directory to match Engine
          final appDir = await getApplicationSupportDirectory();
          appStorageDir = appDir.path.replaceAll('/app_flutter', '/files');
          
          // For cache, use the standard cache directory
          final cacheDir = await getTemporaryDirectory();
          codeCacheDir = cacheDir.path;
          
          debugPrint('Android: Adjusted paths to match Engine');
          debugPrint('  - appStorageDir: $appStorageDir (should contain /files)');
          debugPrint('  - codeCacheDir: $codeCacheDir');
        } else if (Platform.isIOS) {
          // iOS paths are different
          final appDir = await getApplicationDocumentsDirectory();
          final cacheDir = await getTemporaryDirectory();
          appStorageDir = appDir.path;
          codeCacheDir = cacheDir.path;
          debugPrint('iOS: Using standard path_provider paths');
        } else {
          // Other platforms
          final appDir = await getApplicationDocumentsDirectory();
          final cacheDir = await getTemporaryDirectory();
          appStorageDir = appDir.path;
          codeCacheDir = cacheDir.path;
          debugPrint('Other platform: Using standard path_provider paths');
        }
      }
      
      // Match the Engine's expected directory structure
      // Engine expects paths with specific suffixes
      String finalAppStorageDir;
      String finalCodeCacheDir;
      
      // Match official Engine behavior: pass paths with shorebird_updater suffix
      // The Engine's shorebird.cc adds this suffix before calling the updater
      if (Platform.isIOS) {
        // iOS: Native plugin already returns the correct base path with /shorebird
        // Engine adds shorebird_updater suffix to this base
        finalAppStorageDir = '$appStorageDir/shorebird_updater';
        finalCodeCacheDir = '$codeCacheDir/shorebird_updater';
      } else if (Platform.isAndroid) {
        // Android: Engine adds shorebird_updater suffix
        finalAppStorageDir = '$appStorageDir/shorebird_updater';
        finalCodeCacheDir = '$codeCacheDir/shorebird_updater';
      } else {
        // Other platforms: add shorebird_updater suffix
        finalAppStorageDir = '$appStorageDir/shorebird_updater';
        finalCodeCacheDir = '$codeCacheDir/shorebird_updater';
      }
      
      // Don't add /downloads here - the Rust library adds it to match official updater
      final downloadDir = '$finalCodeCacheDir/downloads';
      
      debugPrint('Original app storage dir: $appStorageDir');
      debugPrint('Final app storage dir: $finalAppStorageDir');
      debugPrint('Original code cache dir: $codeCacheDir');
      debugPrint('Final code cache dir: $finalCodeCacheDir');
      debugPrint('Download dir: $downloadDir');
      
      // Create directories if they don't exist
      final storageDir = Directory(finalAppStorageDir);
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
        debugPrint('Created storage directory: $finalAppStorageDir');
      }
      
      final downloadDirectory = Directory(downloadDir);
      if (!await downloadDirectory.exists()) {
        await downloadDirectory.create(recursive: true);
        debugPrint('Created download directory: $downloadDir');
      }
      
      // Initialize the native library with corrected paths
      final result = await _initializeNative(
        appStorageDir: finalAppStorageDir,
        codeCacheDir: finalCodeCacheDir,
        config: config,
      );
      
      if (result) {
        _initialized = true;
        debugPrint('Network updater initialized successfully');
        
        // Set download URL if provided
        if (config.downloadUrl != null) {
          final downloadUrlPtr = config.downloadUrl!.toNativeUtf8().cast<Char>();
          try {
            bool urlResult;
            if (Platform.isIOS) {
              final iosBindings = UpdaterNetwork.iosBindings;
              urlResult = iosBindings.shorebird_update_download_url_net(downloadUrlPtr);
            } else {
              final bindings = UpdaterNetwork.networkBindings;
              urlResult = bindings.shorebird_update_download_url(downloadUrlPtr);
            }
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
  static Future<bool> _initializeNative({
    required String appStorageDir,
    required String codeCacheDir,
    required NetworkUpdaterConfig config,
  }) async {
    debugPrint('[NetworkUpdater] Starting native initialization...');
    debugPrint('[NetworkUpdater] App ID: ${config.appId}');
    debugPrint('[NetworkUpdater] Release version: ${config.releaseVersion}');
    debugPrint('[NetworkUpdater] Channel: ${config.channel}');
    debugPrint('[NetworkUpdater] Auto update: ${config.autoUpdate}');
    debugPrint('[NetworkUpdater] Base URL: ${config.baseUrl ?? 'default'}');
    debugPrint('[NetworkUpdater] Download URL: ${config.downloadUrl ?? 'none'}');
    
    // Allocate memory for parameters
    final appParams = malloc<AppParameters>();
    final networkConfig = malloc<NetworkConfig>();
    final releaseVersionPtr = config.releaseVersion.toNativeUtf8().cast<Char>();
    final appStorageDirPtr = appStorageDir.toNativeUtf8().cast<Char>();
    final codeCacheDirPtr = codeCacheDir.toNativeUtf8().cast<Char>();
    
    // Set up app parameters
    appParams.ref.release_version = releaseVersionPtr;
    appParams.ref.app_storage_dir = appStorageDirPtr;
    appParams.ref.code_cache_dir = codeCacheDirPtr;
    
    // Handle original libapp paths
    Pointer<Pointer<Char>>? libappPathsPtr;
    List<Pointer<Utf8>> allocatedPaths = [];
    
    if (config.originalLibappPaths != null && config.originalLibappPaths!.isNotEmpty) {
      debugPrint('[NetworkUpdater] Setting up libapp paths: ${config.originalLibappPaths}');
      libappPathsPtr = malloc<Pointer<Char>>(config.originalLibappPaths!.length);
      for (int i = 0; i < config.originalLibappPaths!.length; i++) {
        final pathPtr = config.originalLibappPaths![i].toNativeUtf8();
        allocatedPaths.add(pathPtr);
        libappPathsPtr[i] = pathPtr.cast<Char>();
      }
      appParams.ref.original_libapp_paths = libappPathsPtr.cast<Pointer<Char>>();
      appParams.ref.original_libapp_paths_size = config.originalLibappPaths!.length;
    } else {
      debugPrint('[NetworkUpdater] No libapp paths provided');
      appParams.ref.original_libapp_paths = nullptr;
      appParams.ref.original_libapp_paths_size = 0;
    }
    
    // Set up network config
    final appIdPtr = config.appId.toNativeUtf8().cast<Char>();
    final channelPtr = config.channel.toNativeUtf8().cast<Char>();
    final baseUrlPtr = config.baseUrl?.toNativeUtf8().cast<Char>() ?? nullptr;
    final downloadUrlPtr = config.downloadUrl?.toNativeUtf8().cast<Char>() ?? nullptr;
    
    networkConfig.ref.app_id = appIdPtr;
    networkConfig.ref.channel = channelPtr;
    networkConfig.ref.auto_update = config.autoUpdate;
    networkConfig.ref.base_url = baseUrlPtr ?? 'https://api.shorebird.dev'.toNativeUtf8().cast<Char>();
    networkConfig.ref.download_url = downloadUrlPtr;
    networkConfig.ref.patch_public_key = nullptr; // TODO: Add support for patch public key
    
    // Create file callbacks
    final fileCallbacks = _createFileCallbacks();
    
    try {
      // Call initialization function
      debugPrint('[NetworkUpdater] Calling shorebird_init_network...');
      
      bool result;
      if (Platform.isIOS) {
        // Initialize iOS bindings first
        await UpdaterNetwork.initializeIOSBindings();
        
        // Use iOS-specific bindings for initialization
        final iosBindings = UpdaterNetwork.iosBindings;
        result = iosBindings.shorebird_init_network(appParams, networkConfig, fileCallbacks);
      } else {
        // Use standard bindings for Android
        final bindings = UpdaterNetwork.networkBindings;
        result = bindings.shorebird_init_network(appParams, networkConfig, fileCallbacks);
      }
      
      debugPrint('[NetworkUpdater] Native init result: $result');
      
      if (result) {
        // Verify initialization by getting app ID
        if (Platform.isIOS) {
          final iosBindings = UpdaterNetwork.iosBindings;
          final appIdResult = iosBindings.shorebird_get_app_id_net();
          if (appIdResult != nullptr) {
            final appId = appIdResult.cast<Utf8>().toDartString();
            debugPrint('[NetworkUpdater] Verified app ID: $appId');
            iosBindings.shorebird_free_string_net(appIdResult);
          }
          
          // Get release version
          final versionResult = iosBindings.shorebird_get_release_version_net();
          if (versionResult != nullptr) {
            final version = versionResult.cast<Utf8>().toDartString();
            debugPrint('[NetworkUpdater] Verified release version: $version');
            iosBindings.shorebird_free_string_net(versionResult);
          }
        } else {
          final bindings = UpdaterNetwork.networkBindings;
          final appIdResult = bindings.shorebird_get_app_id();
          if (appIdResult != nullptr) {
            final appId = appIdResult.cast<Utf8>().toDartString();
            debugPrint('[NetworkUpdater] Verified app ID: $appId');
            bindings.shorebird_free_string(appIdResult);
          }
          
          // Get release version
          final versionResult = bindings.shorebird_get_release_version();
          if (versionResult != nullptr) {
            final version = versionResult.cast<Utf8>().toDartString();
            debugPrint('[NetworkUpdater] Verified release version: $version');
            bindings.shorebird_free_string(versionResult);
          }
        }
      }
      
      return result;
      
    } finally {
      // Clean up allocated memory
      debugPrint('[NetworkUpdater] Cleaning up allocated memory...');
      malloc.free(appParams);
      malloc.free(networkConfig);
      malloc.free(releaseVersionPtr);
      malloc.free(appStorageDirPtr);
      malloc.free(codeCacheDirPtr);
      malloc.free(appIdPtr);
      malloc.free(channelPtr);
      if (baseUrlPtr != nullptr && config.baseUrl != null) {
        malloc.free(baseUrlPtr);
      }
      if (downloadUrlPtr != nullptr) {
        malloc.free(downloadUrlPtr);
      }
      
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