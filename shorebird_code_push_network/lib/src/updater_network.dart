import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
      final bindings = networkBindings;
      // Try to call a simple function to verify the library works
      bindings.shorebird_current_boot_patch_number();
      return true;
    } on Exception catch (e) {
      debugPrint('Library availability test failed: $e');
      return false;
    }
  }

  /// Ensure the native library is loaded when instance is created
  void _ensureLibraryLoaded() {
    try {
      debugPrint('Starting UpdaterNetwork initialization...');
      
      // 触发 networkBindings getter，立即加载库
      final bindings = networkBindings;
      debugPrint('Network library bindings created successfully');
      
      // 验证库是否正常工作 - 调用平台相关的函数
      if (Platform.isIOS) {
        // 在 iOS 上验证 _net 后缀函数
        bindings.shorebird_current_boot_patch_number_net();
        debugPrint('iOS network library verification successful (_net functions)');
      } else {
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
      _loadIOSLibrary();
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

  /// Load iOS static library with proper verification
  static void _loadIOSLibrary() {
    try {
      debugPrint('Loading iOS network library...');
      
      // iOS uses static linking - library should be already linked
      final library = ffi.DynamicLibrary.process();
      _bindings = UpdaterBindings(library);
      
      // Verify that the library symbols are available
      _verifyIOSLibrarySymbols();
      
      debugPrint('iOS network library loaded successfully');
      
    } catch (e) {
      throw Exception('Failed to load iOS network library: $e');
    }
  }

  /// Verify iOS library symbols are accessible
  static void _verifyIOSLibrarySymbols() {
    if (_bindings == null) return;
    
    try {
      // Verify library works by calling a simple function with _net suffix
      _bindings!.shorebird_current_boot_patch_number_net();
      debugPrint('iOS library verification successful with _net functions');
    } catch (e) {
      debugPrint('iOS library verification warning: $e');
    }
  }

  /// The currently active patch number.
  @override
  int currentPatchNumber() {
    if (Platform.isIOS) {
      return networkBindings.shorebird_current_boot_patch_number_net();
    }
    return networkBindings.shorebird_current_boot_patch_number();
  }

  /// The next patch number that will be loaded.
  @override
  int nextPatchNumber() {
    if (Platform.isIOS) {
      return networkBindings.shorebird_next_boot_patch_number_net();
    }
    return networkBindings.shorebird_next_boot_patch_number();
  }

  /// Downloads the latest patch, if available.
  @override
  void downloadUpdate() {
    if (Platform.isIOS) {
      networkBindings.shorebird_update_net();
    } else {
      networkBindings.shorebird_update();
    }
  }

  /// Whether a new patch is available for download.
  @override
  bool checkForDownloadableUpdate({UpdateTrack? track}) {
    final trackPtr = track == null 
      ? ffi.nullptr 
      : track.name.toNativeUtf8().cast<Char>();
    if (Platform.isIOS) {
      return networkBindings.shorebird_check_for_downloadable_update_net(
        trackPtr
      );
    }
    return networkBindings.shorebird_check_for_downloadable_update(trackPtr);
  }

  /// Downloads the latest patch and returns an [UpdateResult].
  @override
  Pointer<UpdateResult> update({UpdateTrack? track}) {
    final trackPtr = track == null 
      ? ffi.nullptr 
      : track.name.toNativeUtf8().cast<Char>();
    if (Platform.isIOS) {
      return networkBindings.shorebird_update_with_result_net(trackPtr);
    }
    return networkBindings.shorebird_update_with_result(trackPtr);
  }

  /// Frees an update result allocated by the updater.
  @override
  void freeUpdateResult(Pointer<UpdateResult> ptr) {
    if (Platform.isIOS) {
      networkBindings.shorebird_free_update_result_net(ptr);
    } else {
      networkBindings.shorebird_free_update_result(ptr);
    }
  }

  /// Update the base URL for patch checking and downloading.
  @override
  bool updateBaseUrl(String baseUrl) {
    debugPrint('UpdaterNetwork.updateBaseUrl called with: $baseUrl');
    final urlPtr = baseUrl.toNativeUtf8().cast<Char>();
    
    try {
      bool result;
      if (Platform.isIOS) {
        debugPrint('Calling iOS function: shorebird_update_base_url_net');
        result = networkBindings.shorebird_update_base_url_net(urlPtr);
      } else {
        debugPrint('Calling Android function: shorebird_update_base_url');
        result = networkBindings.shorebird_update_base_url(urlPtr);
      }
      
      debugPrint('updateBaseUrl result: $result');
      
      // 释放内存
      malloc.free(urlPtr);
      
      return result;
    } catch (e) {
      debugPrint('ERROR in updateBaseUrl: $e');
      malloc.free(urlPtr);
      rethrow;
    }
  }
  
  /// Get the current app_id from the network library
  String getAppId() {
    debugPrint('Getting app_id from network library...');
    
    Pointer<Char>? resultPtr;
    try {
      if (Platform.isIOS) {
        resultPtr = networkBindings.shorebird_get_app_id_net();
      } else {
        resultPtr = networkBindings.shorebird_get_app_id();
      }
      
      if (resultPtr == nullptr) {
        return 'not-available';
      }
      
      final appId = resultPtr.cast<Utf8>().toDartString();
      
      // Free the string allocated by Rust
      if (Platform.isIOS) {
        networkBindings.shorebird_free_string_net(resultPtr);
      } else {
        networkBindings.shorebird_free_string(resultPtr.cast<Char>());
      }
      
      debugPrint('App ID: $appId');
      return appId;
      
    } catch (e) {
      debugPrint('Error getting app_id: $e');
      return 'error';
    }
  }
  
  /// Get the current release version from the network library
  String getReleaseVersion() {
    debugPrint('Getting release version from network library...');
    
    Pointer<Char>? resultPtr;
    try {
      if (Platform.isIOS) {
        resultPtr = networkBindings.shorebird_get_release_version_net();
      } else {
        resultPtr = networkBindings.shorebird_get_release_version();
      }
      
      if (resultPtr == nullptr) {
        return '0.0.0';
      }
      
      final version = resultPtr.cast<Utf8>().toDartString();
      
      // Free the string allocated by Rust
      if (Platform.isIOS) {
        networkBindings.shorebird_free_string_net(resultPtr);
      } else {
        networkBindings.shorebird_free_string(resultPtr.cast<Char>());
      }
      
      debugPrint('Release version: $version');
      return version;
      
    } catch (e) {
      debugPrint('Error getting release version: $e');
      return '0.0.0';
    }
  }
}
