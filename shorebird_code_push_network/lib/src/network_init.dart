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

          appStorageDir = "";
          codeCacheDir = "";
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
      
      // Set libapp path for iOS file callbacks
      if (Platform.isIOS && config.originalLibappPaths != null && config.originalLibappPaths!.isNotEmpty) {
        // Use the original native path, not Flutter's modified path

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
              //初始化hook
              urlResult = true;
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
        result = true;
      } else {
        // Use standard bindings for Android
        final bindings = UpdaterNetwork.networkBindings;
        result = bindings.shorebird_init_network(appParams, networkConfig, fileCallbacks);
      }
      
      debugPrint('[NetworkUpdater] Native init result: $result');
      
      if (result) {
        // Verify initialization by getting app ID
        if (Platform.isIOS) {
         //初始化hook可以
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
  
  // Global pointer to hold the FileCallbacks to prevent premature garbage collection
  static Pointer<FileCallbacks>? _fileCallbacksPtr;
  
  /// Create file callbacks for the native library
  static FileCallbacks _createFileCallbacks() {
    // Free any existing callbacks
    if (_fileCallbacksPtr != null) {
      malloc.free(_fileCallbacksPtr!);
    }
    
    _fileCallbacksPtr = malloc<FileCallbacks>();
    
    // Set the function pointers
    _fileCallbacksPtr!.ref.open = Pointer.fromFunction<Pointer<Void> Function()>(_fileOpen);
    _fileCallbacksPtr!.ref.read = Pointer.fromFunction<UintPtr Function(Pointer<Void>, Pointer<Uint8>, UintPtr)>(_fileRead, 0);
    _fileCallbacksPtr!.ref.seek = Pointer.fromFunction<Int64 Function(Pointer<Void>, Int64, Int32)>(_fileSeek, 0);
    _fileCallbacksPtr!.ref.close = Pointer.fromFunction<Void Function(Pointer<Void>)>(_fileClose);
    
    debugPrint('[FileCallbacks] Created callbacks:');
    debugPrint('[FileCallbacks]   open: ${_fileCallbacksPtr!.ref.open.address.toRadixString(16)}');
    debugPrint('[FileCallbacks]   read: ${_fileCallbacksPtr!.ref.read.address.toRadixString(16)}');
    debugPrint('[FileCallbacks]   seek: ${_fileCallbacksPtr!.ref.seek.address.toRadixString(16)}');
    debugPrint('[FileCallbacks]   close: ${_fileCallbacksPtr!.ref.close.address.toRadixString(16)}');
    
    // Return the struct value - native code expects FileCallbacks by value
    // But we keep the pointer globally to prevent garbage collection
    return _fileCallbacksPtr!.ref;
  }
  
  // File handle for iOS
  static RandomAccessFile? _currentFile;
  static String? _libappPath;  // Always use original path for all read operations
  
  // Store libapp path for file callbacks
  static void _setLibappPath(String path) {
    _libappPath = path;
    debugPrint('[FileCallbacks] Set original libapp path: $path');
  }
  
  // Verify iOS libapp file is accessible
  static Future<void> _prepareIOSLibapp(String originalPath) async {
    debugPrint('[FileCallbacks] Verifying iOS libapp accessibility: $originalPath');
    
    try {
      // Try to access the original file directly
      File? sourceFile;
      String? actualSourcePath = originalPath;
      
      // Try original path first
      sourceFile = File(originalPath);
      if (!sourceFile.existsSync()) {
        debugPrint('[FileCallbacks] Source file does not exist at: $originalPath');
        
        // Try without /private prefix
        if (originalPath.startsWith('/private')) {
          final altPath = originalPath.substring(8);
          debugPrint('[FileCallbacks] Trying alternative path: $altPath');
          final altFile = File(altPath);
          if (altFile.existsSync()) {
            sourceFile = altFile;
            actualSourcePath = altPath;
            debugPrint('[FileCallbacks] Found file at alternative path');
          }
        }
      }
      
      // If still not found, this is a critical error
      if (sourceFile == null || !sourceFile.existsSync()) {
        debugPrint('[FileCallbacks] CRITICAL ERROR: Cannot find source file');
        debugPrint('[FileCallbacks] Original path: $originalPath');
        throw Exception('Source file not found at any expected location');
      }
      
      debugPrint('[FileCallbacks] Source file found at: $actualSourcePath');
      debugPrint('[FileCallbacks] Source file size: ${sourceFile.lengthSync()} bytes');
      
      // Test read access to verify iOS allows direct bundle file reading
      debugPrint('[FileCallbacks] Testing read access to bundle file...');
      final testFile = sourceFile.openSync(mode: FileMode.read);
      final testBytes = testFile.readSync(16); // Read first 16 bytes
      testFile.closeSync();
      
      if (testBytes.length > 0) {
        debugPrint('[FileCallbacks] ✅ Direct bundle file access confirmed');
        debugPrint('[FileCallbacks] Test read successful: ${testBytes.length} bytes');
        debugPrint('[FileCallbacks] First bytes: ${testBytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      } else {
        throw Exception('Cannot read from bundle file');
      }
      
      // Store the accessible path - always use original for all operations
      _libappPath = actualSourcePath;
      debugPrint('[FileCallbacks] ✅ iOS libapp ready for direct access: $_libappPath');
      
    } catch (e) {
      debugPrint('[FileCallbacks] ERROR accessing iOS libapp: $e');
      debugPrint('[FileCallbacks] This may cause hash verification and patch operations to fail');
      // Store the path anyway - let the actual operations handle the error
      _libappPath = originalPath;
    }
  }
  
  // Real file callback implementations for iOS
  static Pointer<Void> _fileOpen() {
    debugPrint('[FileCallbacks] === _fileOpen called ===');
    
    // Always use original path for all read operations
    // This ensures hash calculation is correct and bundle files are accessible
    final pathToUse = _libappPath;
    
    if (pathToUse == null) {
      debugPrint('[FileCallbacks] ERROR: No libapp path set');
      debugPrint('[FileCallbacks] _libappPath: $_libappPath');
      return nullptr;
    }
    
    debugPrint('[FileCallbacks] Using original bundle path: $pathToUse');
    debugPrint('[FileCallbacks] This ensures correct hash calculation and direct bundle access');
    
    try {
      // Close any existing file first
      if (_currentFile != null) {
        debugPrint('[FileCallbacks] Closing existing file');
        try {
          _currentFile!.closeSync();
        } catch (e) {
          debugPrint('[FileCallbacks] Error closing existing file: $e');
        }
        _currentFile = null;
      }
      
      debugPrint('[FileCallbacks] Checking if file exists: $pathToUse');
      final file = File(pathToUse);
      final exists = file.existsSync();
      debugPrint('[FileCallbacks] File exists: $exists');
      
      if (!exists) {
        debugPrint('[FileCallbacks] CRITICAL ERROR: File does not exist at: $pathToUse');
        debugPrint('[FileCallbacks] This should not happen if _prepareIOSLibapp succeeded');
        
        // List directory contents for debugging
        if (pathToUse.contains('/')) {
          final dir = Directory(pathToUse.substring(0, pathToUse.lastIndexOf('/')));
          if (dir.existsSync()) {
            debugPrint('[FileCallbacks] Directory contents:');
            dir.listSync().forEach((entity) {
              debugPrint('[FileCallbacks]   - ${entity.path}');
            });
          }
        }
        
        return nullptr;
      }
      
      debugPrint('[FileCallbacks] Opening file for reading...');
      _currentFile = file.openSync(mode: FileMode.read);
      final length = _currentFile!.lengthSync();
      debugPrint('[FileCallbacks] File opened successfully, length: $length bytes');
      
      // Verify we can read from the file
      try {
        final testBytes = _currentFile!.readSync(4);
        debugPrint('[FileCallbacks] Test read successful, first 4 bytes: ${testBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        _currentFile!.setPositionSync(0); // Reset position
      } catch (e) {
        debugPrint('[FileCallbacks] ERROR: Test read failed: $e');
      }
      
      // Use a non-zero pointer value to indicate success
      debugPrint('[FileCallbacks] Returning success pointer');
      return Pointer<Void>.fromAddress(1);
    } catch (e) {
      debugPrint('[FileCallbacks] ERROR opening file: $e');
      debugPrint('[FileCallbacks] Stack trace: ${StackTrace.current}');
      return nullptr;
    }
  }
  
  static int _fileRead(Pointer<Void> handle, Pointer<Uint8> buffer, int count) {
    debugPrint('[FileCallbacks] _fileRead called, handle: ${handle.address}, count: $count');
    
    if (handle.address == 0) {
      debugPrint('[FileCallbacks] ERROR: Invalid handle');
      return 0;
    }
    
    if (_currentFile == null) {
      debugPrint('[FileCallbacks] ERROR: No current file');
      return 0;
    }
    
    try {
      final position = _currentFile!.positionSync();
      debugPrint('[FileCallbacks] Current position: $position, requesting $count bytes');
      
      final bytes = _currentFile!.readSync(count);
      final bytesRead = bytes.length;
      debugPrint('[FileCallbacks] Read $bytesRead bytes');
      
      if (bytes.isEmpty) {
        debugPrint('[FileCallbacks] No bytes read (EOF?)');
        return 0;
      }
      
      // Copy bytes to the buffer
      for (var i = 0; i < bytes.length; i++) {
        buffer[i] = bytes[i];
      }
      
      if (bytesRead < 10) {
        debugPrint('[FileCallbacks] Read data: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      }
      
      return bytesRead;
    } catch (e) {
      debugPrint('[FileCallbacks] ERROR reading file: $e');
      debugPrint('[FileCallbacks] Stack trace: ${StackTrace.current}');
      return 0;
    }
  }
  
  static int _fileSeek(Pointer<Void> handle, int offset, int whence) {
    debugPrint('[FileCallbacks] _fileSeek called, handle: ${handle.address}, offset: $offset, whence: $whence');
    
    if (handle.address == 0) {
      debugPrint('[FileCallbacks] ERROR: Invalid handle');
      return 0;
    }
    
    if (_currentFile == null) {
      debugPrint('[FileCallbacks] ERROR: No current file');
      return 0;
    }
    
    try {
      int position;
      final fileLength = _currentFile!.lengthSync();
      debugPrint('[FileCallbacks] File length: $fileLength');
      
      // whence: 0 = SEEK_SET, 1 = SEEK_CUR, 2 = SEEK_END
      switch (whence) {
        case 0: // SEEK_SET
          debugPrint('[FileCallbacks] SEEK_SET to offset $offset');
          _currentFile!.setPositionSync(offset);
          position = offset;
          break;
        case 1: // SEEK_CUR
          final currentPos = _currentFile!.positionSync();
          position = currentPos + offset;
          debugPrint('[FileCallbacks] SEEK_CUR from $currentPos to $position');
          _currentFile!.setPositionSync(position);
          break;
        case 2: // SEEK_END
          position = fileLength + offset;
          debugPrint('[FileCallbacks] SEEK_END to $position (length: $fileLength, offset: $offset)');
          _currentFile!.setPositionSync(position);
          break;
        default:
          debugPrint('[FileCallbacks] ERROR: Unknown whence value: $whence');
          return 0;
      }
      
      final newPos = _currentFile!.positionSync();
      debugPrint('[FileCallbacks] Seek completed, new position: $newPos');
      return position;
    } catch (e) {
      debugPrint('[FileCallbacks] ERROR seeking file: $e');
      debugPrint('[FileCallbacks] Stack trace: ${StackTrace.current}');
      return 0;
    }
  }
  
  static void _fileClose(Pointer<Void> handle) {
    debugPrint('[FileCallbacks] _fileClose called, handle: ${handle.address}');
    
    if (handle.address == 0) {
      debugPrint('[FileCallbacks] Warning: Invalid handle in close');
      return;
    }
    
    if (_currentFile == null) {
      debugPrint('[FileCallbacks] Warning: No current file to close');
      return;
    }
    
    try {
      _currentFile!.closeSync();
      _currentFile = null;
      debugPrint('[FileCallbacks] File closed successfully');
    } catch (e) {
      debugPrint('[FileCallbacks] ERROR closing file: $e');
      debugPrint('[FileCallbacks] Stack trace: ${StackTrace.current}');
    }
  }
  
  /// Check if the network updater is initialized
  static bool get isInitialized => _initialized;
  
  /// Reset initialization state (mainly for testing)
  @visibleForTesting
  static void reset() {
    _initialized = false;
  }
}