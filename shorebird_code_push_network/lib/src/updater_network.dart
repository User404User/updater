import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'package:shorebird_code_push_network/src/generated/updater_bindings.g.dart';
import 'package:shorebird_code_push_network/src/network_init.dart';
import 'package:shorebird_code_push_network/src/shorebird_updater.dart';
import 'package:shorebird_code_push_network/src/updater.dart';

export 'network_init.dart' show NetworkUpdaterConfig, NetworkUpdaterInitializer;

/// {@template updater_network}
/// 网络版本的 Updater，加载独立的动态库避免与引擎库冲突
/// {@endtemplate}
class UpdaterNetwork extends Updater {
  /// Configuration used to initialize the network library
  static NetworkUpdaterConfig? _config;
  
  /// {@macro updater_network}
  UpdaterNetwork() {
    // 立即触发库加载
    _ensureLibraryLoaded();
  }
  
  /// Create and initialize the network updater with configuration
  static Future<UpdaterNetwork?> createAndInitialize(NetworkUpdaterConfig config) async {
    _config = config;
    
    // Initialize the native library
    final initialized = await NetworkUpdaterInitializer.initialize(config);
    if (!initialized) {
      debugPrint('Failed to initialize network updater');
      return null;
    }
    
    try {
      return UpdaterNetwork();
    } catch (e) {
      debugPrint('Failed to create UpdaterNetwork instance: $e');
      return null;
    }
  }

  /// Test if the network library is available and can be loaded.
  /// Returns true if successful, false if there's an error.
  static bool testLibraryAvailability() {
    try {
      if (Platform.isIOS) {
        // iOS requires async initialization
        debugPrint('iOS library availability test skipped (requires async init)');
        return true;
      } else {
        final bindings = networkBindings;
        // Try to call a simple function to verify the library works
        bindings.shorebird_current_boot_patch_number();
        return true;
      }
    } on Exception catch (e) {
      debugPrint('Library availability test failed: $e');
      return false;
    }
  }

  /// Ensure the native library is loaded when instance is created
  void _ensureLibraryLoaded() {
    try {
      debugPrint('Starting UpdaterNetwork initialization...');
      
      if (Platform.isIOS) {
        // iOS bindings are already initialized in createAndInitialize
        debugPrint('iOS bindings already initialized');
      } else {
        // 触发 networkBindings getter，立即加载库
        final bindings = networkBindings;
        debugPrint('Network library bindings created successfully');
        
        // 在 Android 上验证标准函数
        bindings.shorebird_current_boot_patch_number();
        debugPrint('Android network library verification successful');
      }
      
      debugPrint('UpdaterNetwork initialization completed successfully');
    } on Exception catch (e) {
      debugPrint('Failed to load network library during initialization: $e');
      rethrow; // 重新抛出异常，让调用者知道初始化失败
    }
  }

  /// The ffi bindings to the network library.
  static UpdaterBindings? _bindings;
  

  /// The method channel for platform-specific operations.
  static const MethodChannel _channel = MethodChannel('shorebird_code_push_network');

  /// Get bindings, loading the network library
  static UpdaterBindings get networkBindings {
    if (_bindings != null) return _bindings!;
    
    if (Platform.isAndroid) {
      _loadAndroidLibrary();
    } else if (Platform.isIOS) {
      // iOS doesn't need to load library
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} not supported for network library'
      );
    }
    
    return _bindings!;
  }
  


  /// Load Android dynamic library with proper error handling
  static void _loadAndroidLibrary() {
    try {
      debugPrint('Loading Android network library...');
      
      // Method 1: Try to load through plugin channel
      try {
        _channel.invokeMethod('loadLibrary').then((result) {
          if (result == true) {
            debugPrint('Android library pre-loaded via plugin');
          }
        }).catchError((error) {
          debugPrint('Plugin pre-load failed: $error');
        });
      } catch (e) {
        debugPrint('Plugin channel not available: $e');
      }
      
      // Method 2: Direct FFI loading with multiple attempts
      ffi.DynamicLibrary? library;
      
      // Try different library names/paths
      final libraryNames = [
        'libshorebird_updater_network.so',
        'shorebird_updater_network',
        'libshorebird_updater_network',
      ];
      
      Exception? lastError;
      for (final libName in libraryNames) {
        try {
          debugPrint('Attempting to load: $libName');
          library = ffi.DynamicLibrary.open(libName);
          debugPrint('Successfully loaded: $libName');
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          debugPrint('Failed to load $libName: $e');
        }
      }
      
      if (library == null) {
        throw Exception(
          'Failed to load Android network library. Last error: $lastError'
        );
      }
      
      _bindings = UpdaterBindings(library);
      debugPrint('Android network library loaded successfully');
      
    } catch (e) {
      throw Exception('Failed to load Android network library: $e');
    }
  }

  /// The currently active patch number.
  @override
  Future<int?> currentPatchNumber() async {
    if (Platform.isIOS) {
      return await ShorebirdCodePush().currentPatchNumber();
    }
    return networkBindings.shorebird_current_boot_patch_number();
  }

  /// The next patch number that will be loaded.
  @override
  Future<int?> nextPatchNumber() async {
    if (Platform.isIOS) {
      return await ShorebirdCodePush().nextPatchNumber();
    }
    return networkBindings.shorebird_next_boot_patch_number();
  }

  /// Downloads the latest patch, if available.
  @override
  void downloadUpdate() {
    if (Platform.isIOS) {
       ShorebirdCodePush().downloadUpdateIfAvailable();
    } else {
      networkBindings.shorebird_update();
    }
  }

  /// Whether a new patch is available for download.
  @override
  Future<bool> checkForDownloadableUpdate({UpdateTrack? track}) async {

    if (Platform.isIOS) {
      return ShorebirdCodePush().isNewPatchAvailableForDownload();
    }

    final trackPtr = track == null 
      ? ffi.nullptr 
      : track.name.toNativeUtf8().cast<Char>();

    return networkBindings.shorebird_check_for_downloadable_update(trackPtr);
  }

  /// Downloads the latest patch and returns an [UpdateResult].
  @override
  Pointer<UpdateResult> update({UpdateTrack? track}) {
    final trackPtr = track == null 
      ? ffi.nullptr 
      : track.name.toNativeUtf8().cast<Char>();
    if (Platform.isIOS) {
      // return iosBindings.shorebird_update_with_result_net(trackPtr);
    }
    return networkBindings.shorebird_update_with_result(trackPtr);
  }

  /// Frees an update result allocated by the updater.
  @override
  void freeUpdateResult(Pointer<UpdateResult> ptr) {
    if (Platform.isIOS) {
      // iosBindings.shorebird_free_update_result_net(ptr);
    } else {
      networkBindings.shorebird_free_update_result(ptr);
    }
  }

  /// Update the base URL for patch checking and downloading.
  @override
  bool updateBaseUrl(String baseUrl) {
    debugPrint('UpdaterNetwork.updateBaseUrl called with: $baseUrl');
    
    try {
      bool result;
      if (Platform.isIOS) {
        debugPrint('iOS: Updating API host mapping');
        // 从sURL中提取host
        final uri = Uri.tryParse(baseUrl);
        if (uri == null || uri.host.isEmpty) {
          debugPrint('Invalid URL: $baseUrl');
          return false;
        }
        
        debugPrint('Extracted host: ${uri.host}');
        
        // 通过method channel调用原生方法更新host映射
        _channel.invokeMethod('updateBaseUrl', {
          'baseUrl': baseUrl,
        }).then((value) {
          debugPrint('iOS updateBaseUrl result: $value');
        }).catchError((error) {
          debugPrint('iOS updateBaseUrl error: $error');
        });
        
        result = true;
      } else {
        debugPrint('Calling Android function: shorebird_update_base_url');
        final urlPtr = baseUrl.toNativeUtf8().cast<Char>();
        result = networkBindings.shorebird_update_base_url(urlPtr);
        malloc.free(urlPtr);
      }
      
      debugPrint('updateBaseUrl result: $result');
      return result;
    } catch (e) {
      debugPrint('ERROR in updateBaseUrl: $e');
      rethrow;
    }
  }
  
  /// Update the download URL for patches.
  /// Pass null to clear the custom download URL and revert to using base_url.
  bool updateDownloadUrl(String? downloadUrl) {
    debugPrint('UpdaterNetwork.updateDownloadUrl called with: $downloadUrl');
    
    try {
      bool result;
      if (Platform.isIOS) {
        if (downloadUrl == null) {
          // 清除自定义CDN主机
          debugPrint('iOS: Clearing CDN host mapping');
          _channel.invokeMethod('updateDownloadUrl', {
            'downloadUrl': null,
          }).then((value) {
            debugPrint('iOS updateDownloadUrl (clear) result: $value');
          }).catchError((error) {
            debugPrint('iOS updateDownloadUrl (clear) error: $error');
          });
          result = true;
        } else {
          debugPrint('iOS: Updating CDN host mapping');
          // 从sURL中提取host
          final uri = Uri.tryParse(downloadUrl);
          if (uri == null || uri.host.isEmpty) {
            debugPrint('Invalid URL: $downloadUrl');
            return false;
          }
          
          debugPrint('Extracted host: ${uri.host}');
          
          // 通过method channel调用原生方法更新host映射
          _channel.invokeMethod('updateDownloadUrl', {
            'downloadUrl': downloadUrl,
          }).then((value) {
            debugPrint('iOS updateDownloadUrl result: $value');
          }).catchError((error) {
            debugPrint('iOS updateDownloadUrl error: $error');
          });
          
          result = true;
        }
      } else {
        // Android
        if (downloadUrl == null) {
          result = networkBindings.shorebird_update_download_url(nullptr);
        } else {
          final urlPtr = downloadUrl.toNativeUtf8().cast<Char>();
          result = networkBindings.shorebird_update_download_url(urlPtr);
          malloc.free(urlPtr);
        }
      }
      
      debugPrint('updateDownloadUrl result: $result');
      return result;
    } catch (e) {
      debugPrint('ERROR in updateDownloadUrl: $e');
      rethrow;
    }
  }
  
  /// Add a custom host mapping for domain redirection
  /// This allows any domain to be redirected to a mirror domain
  static Future<bool> addHostMapping(String originalHost, String redirectHost) async {
    debugPrint('UpdaterNetwork.addHostMapping: $originalHost -> $redirectHost');
    
    if (Platform.isIOS) {
      try {
        final result = await _channel.invokeMethod('addHostMapping', {
          'originalHost': originalHost,
          'redirectHost': redirectHost,
        });
        debugPrint('iOS addHostMapping result: $result');
        return result == true;
      } catch (e) {
        debugPrint('iOS addHostMapping error: $e');
        return false;
      }
    } else {
      // Android doesn't need this as it uses URL-based approach
      debugPrint('Android: Host mapping not needed (uses URL-based approach)');
      return true;
    }
  }
  
  /// Remove a host mapping
  static Future<bool> removeHostMapping(String originalHost) async {
    debugPrint('UpdaterNetwork.removeHostMapping: $originalHost');
    
    if (Platform.isIOS) {
      try {
        final result = await _channel.invokeMethod('removeHostMapping', {
          'originalHost': originalHost,
        });
        debugPrint('iOS removeHostMapping result: $result');
        return result == true;
      } catch (e) {
        debugPrint('iOS removeHostMapping error: $e');
        return false;
      }
    } else {
      debugPrint('Android: Host mapping removal not needed');
      return true;
    }
  }
  
  /// Clear all host mappings
  static Future<bool> clearAllHostMappings() async {
    debugPrint('UpdaterNetwork.clearAllHostMappings');
    
    if (Platform.isIOS) {
      try {
        final result = await _channel.invokeMethod('clearAllHostMappings');
        debugPrint('iOS clearAllHostMappings result: $result');
        return result == true;
      } catch (e) {
        debugPrint('iOS clearAllHostMappings error: $e');
        return false;
      }
    } else {
      debugPrint('Android: Host mapping clearing not needed');
      return true;
    }
  }
}
