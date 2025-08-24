// ignore_for_file: unused_element, unused_field

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'updater_bindings.g.dart';

/// iOS-specific bindings that use method channel to get symbol addresses
/// This avoids the dlsym issue with static libraries in Release mode.
class IOSBindings {
  static const MethodChannel _channel = MethodChannel('shorebird_code_push_network');
  
  // Function addresses
  final Map<String, int> _symbolAddresses = {};
  bool _initialized = false;
  
  IOSBindings();
  
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    
    print('[IOSBindings] Initializing symbols via method channel...');
    
    // List of all symbols we need
    final symbols = [
      'shorebird_init_network',
      'shorebird_current_boot_patch_number_net',
      'shorebird_next_boot_patch_number_net',
      'shorebird_check_for_downloadable_update_net',
      'shorebird_update_net',
      'shorebird_update_with_result_net',
      'shorebird_free_update_result_net',
      'shorebird_update_base_url_net',
      'shorebird_update_download_url_net',
      'shorebird_get_app_id_net',
      'shorebird_get_release_version_net',
      'shorebird_free_string_net',
      // 'shorebird_download_update_if_available_net', // Not available in network library
    ];
    
    // Get all symbol addresses
    for (final symbol in symbols) {
      try {
        final address = await _channel.invokeMethod<int>('getSymbolPointer', {
          'symbolName': symbol,
        });
        
        if (address != null && address != 0) {
          _symbolAddresses[symbol] = address;
          print('[IOSBindings] Got address for $symbol: 0x${address.toRadixString(16)}');
        } else {
          print('[IOSBindings] WARNING: Failed to get address for $symbol');
        }
      } catch (e) {
        print('[IOSBindings] ERROR: Failed to get $symbol: $e');
      }
    }
    
    _initialized = true;
    print('[IOSBindings] Initialization complete. Got ${_symbolAddresses.length} symbols.');
  }
  
  // Helper to get function pointer
  ffi.Pointer<T> _getFunctionPointer<T extends ffi.NativeFunction>(String name) {
    final address = _symbolAddresses[name];
    if (address == null || address == 0) {
      throw Exception('Symbol $name not found');
    }
    return ffi.Pointer<T>.fromAddress(address);
  }
  
  /// Initialize the network library
  bool shorebird_init_network(
    ffi.Pointer<AppParameters> app_params,
    ffi.Pointer<NetworkConfig> config,
    FileCallbacks callbacks,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings');
      return false;
    }
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<AppParameters>, ffi.Pointer<NetworkConfig>, FileCallbacks)>>('shorebird_init_network');
      final func = ptr.asFunction<bool Function(ffi.Pointer<AppParameters>, ffi.Pointer<NetworkConfig>, FileCallbacks)>();
      return func(app_params, config, callbacks);
    } catch (e) {
      print('[IOSBindings] ERROR calling shorebird_init_network: $e');
      return false;
    }
  }

  /// Get current boot patch number
  int shorebird_current_boot_patch_number_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings');
      return 0;
    }
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Int Function()>>('shorebird_current_boot_patch_number_net');
      final func = ptr.asFunction<int Function()>();
      return func();
    } catch (e) {
      print('[IOSBindings] ERROR calling shorebird_current_boot_patch_number_net: $e');
      return 0;
    }
  }

  /// Get next boot patch number
  int shorebird_next_boot_patch_number_net() {
    if (!_initialized) return 0;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Int Function()>>('shorebird_next_boot_patch_number_net');
      final func = ptr.asFunction<int Function()>();
      return func();
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return 0;
    }
  }

  /// Check for downloadable update
  bool shorebird_check_for_downloadable_update_net(ffi.Pointer<ffi.Char> track) {
    if (!_initialized) return false;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>>('shorebird_check_for_downloadable_update_net');
      final func = ptr.asFunction<bool Function(ffi.Pointer<ffi.Char>)>();
      return func(track);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return false;
    }
  }

  /// Trigger update
  void shorebird_update_net() {
    if (!_initialized) return;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Void Function()>>('shorebird_update_net');
      final func = ptr.asFunction<void Function()>();
      func();
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
    }
  }

  /// Update with result
  ffi.Pointer<UpdateResult> shorebird_update_with_result_net(ffi.Pointer<ffi.Char> track) {
    if (!_initialized) return ffi.nullptr;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Pointer<UpdateResult> Function(ffi.Pointer<ffi.Char>)>>('shorebird_update_with_result_net');
      final func = ptr.asFunction<ffi.Pointer<UpdateResult> Function(ffi.Pointer<ffi.Char>)>();
      return func(track);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return ffi.nullptr;
    }
  }

  /// Free update result
  void shorebird_free_update_result_net(ffi.Pointer<UpdateResult> result) {
    if (!_initialized) return;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<UpdateResult>)>>('shorebird_free_update_result_net');
      final func = ptr.asFunction<void Function(ffi.Pointer<UpdateResult>)>();
      func(result);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
    }
  }

  /// Update base URL
  bool shorebird_update_base_url_net(ffi.Pointer<ffi.Char> base_url) {
    if (!_initialized) return false;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>>('shorebird_update_base_url_net');
      final func = ptr.asFunction<bool Function(ffi.Pointer<ffi.Char>)>();
      return func(base_url);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return false;
    }
  }

  /// Update download URL
  bool shorebird_update_download_url_net(ffi.Pointer<ffi.Char>? download_url) {
    if (!_initialized) return false;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>>('shorebird_update_download_url_net');
      final func = ptr.asFunction<bool Function(ffi.Pointer<ffi.Char>)>();
      return func(download_url ?? ffi.nullptr);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return false;
    }
  }

  /// Get app ID
  ffi.Pointer<ffi.Char> shorebird_get_app_id_net() {
    if (!_initialized) return ffi.nullptr;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('shorebird_get_app_id_net');
      final func = ptr.asFunction<ffi.Pointer<ffi.Char> Function()>();
      return func();
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return ffi.nullptr;
    }
  }

  /// Get release version
  ffi.Pointer<ffi.Char> shorebird_get_release_version_net() {
    if (!_initialized) return ffi.nullptr;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function()>>('shorebird_get_release_version_net');
      final func = ptr.asFunction<ffi.Pointer<ffi.Char> Function()>();
      return func();
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
      return ffi.nullptr;
    }
  }

  /// Free string
  void shorebird_free_string_net(ffi.Pointer<ffi.Char> s) {
    if (!_initialized) return;
    
    try {
      final ptr = _getFunctionPointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>('shorebird_free_string_net');
      final func = ptr.asFunction<void Function(ffi.Pointer<ffi.Char>)>();
      func(s);
    } catch (e) {
      print('[IOSBindings] ERROR: $e');
    }
  }

  /// Download update if available - NOT AVAILABLE IN NETWORK LIBRARY
  bool shorebird_download_update_if_available_net(ffi.Pointer<ffi.Char> track) {
    print('[IOSBindings] WARNING: shorebird_download_update_if_available_net is not available in network library');
    return false;
  }
}