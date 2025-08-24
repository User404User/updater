// ignore_for_file: unused_element, unused_field

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'updater_bindings.g.dart';

/// iOS-specific bindings that use method channel to get symbol addresses
/// This avoids the dlsym issue with static libraries in Release mode.
class IOSBindings {
  static const MethodChannel _channel = MethodChannel('shorebird_code_push_network');
  
  // Function pointers
  late final bool Function(ffi.Pointer<AppParameters>, ffi.Pointer<NetworkConfig>, FileCallbacks) _shorebird_init_network;
  late final int Function() _shorebird_current_boot_patch_number_net;
  late final int Function() _shorebird_next_boot_patch_number_net;
  late final bool Function(ffi.Pointer<ffi.Char>) _shorebird_check_for_downloadable_update_net;
  late final void Function() _shorebird_update_net;
  late final ffi.Pointer<UpdateResult> Function(ffi.Pointer<ffi.Char>) _shorebird_update_with_result_net;
  late final void Function(ffi.Pointer<UpdateResult>) _shorebird_free_update_result_net;
  late final bool Function(ffi.Pointer<ffi.Char>) _shorebird_update_base_url_net;
  late final bool Function(ffi.Pointer<ffi.Char>?) _shorebird_update_download_url_net;
  late final ffi.Pointer<ffi.Char> Function() _shorebird_get_app_id_net;
  late final ffi.Pointer<ffi.Char> Function() _shorebird_get_release_version_net;
  late final void Function(ffi.Pointer<ffi.Char>) _shorebird_free_string_net;
  late final bool Function(ffi.Pointer<ffi.Char>) _shorebird_download_update_if_available_net;
  
  bool _initialized = false;
  
  IOSBindings();
  
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    
    print('[IOSBindings] Initializing symbols via method channel...');
    
    try {
      // shorebird_init_network
      _shorebird_init_network = await _getFunction<ffi.Bool Function(ffi.Pointer<AppParameters>, ffi.Pointer<NetworkConfig>, FileCallbacks), bool Function(ffi.Pointer<AppParameters>, ffi.Pointer<NetworkConfig>, FileCallbacks)>(
        'shorebird_init_network',
        (_, __, ___) => false,
      );
      
      // shorebird_current_boot_patch_number_net
      _shorebird_current_boot_patch_number_net = await _getFunction<ffi.Int Function()>(
        'shorebird_current_boot_patch_number_net',
        () => 0,
      );
      
      // shorebird_next_boot_patch_number_net
      _shorebird_next_boot_patch_number_net = await _getFunction<ffi.Int Function()>(
        'shorebird_next_boot_patch_number_net',
        () => 0,
      );
      
      // shorebird_check_for_downloadable_update_net
      _shorebird_check_for_downloadable_update_net = await _getFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_check_for_downloadable_update_net',
        (_) => false,
      );
      
      // shorebird_update_net
      _shorebird_update_net = await _getFunction<ffi.Void Function()>(
        'shorebird_update_net',
        () {},
      );
      
      // shorebird_update_with_result_net
      _shorebird_update_with_result_net = await _getFunction<ffi.Pointer<UpdateResult> Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_update_with_result_net',
        (_) => ffi.nullptr,
      );
      
      // shorebird_free_update_result_net
      _shorebird_free_update_result_net = await _getFunction<ffi.Void Function(ffi.Pointer<UpdateResult>)>(
        'shorebird_free_update_result_net',
        (_) {},
      );
      
      // shorebird_update_base_url_net
      _shorebird_update_base_url_net = await _getFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_update_base_url_net',
        (_) => false,
      );
      
      // shorebird_update_download_url_net
      _shorebird_update_download_url_net = await _getFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_update_download_url_net',
        (_) => false,
      );
      
      // shorebird_get_app_id_net
      _shorebird_get_app_id_net = await _getFunction<ffi.Pointer<ffi.Char> Function()>(
        'shorebird_get_app_id_net',
        () => ffi.nullptr,
      );
      
      // shorebird_get_release_version_net
      _shorebird_get_release_version_net = await _getFunction<ffi.Pointer<ffi.Char> Function()>(
        'shorebird_get_release_version_net',
        () => ffi.nullptr,
      );
      
      // shorebird_free_string_net
      _shorebird_free_string_net = await _getFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_free_string_net',
        (_) {},
      );
      
      // shorebird_download_update_if_available_net
      _shorebird_download_update_if_available_net = await _getFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>(
        'shorebird_download_update_if_available_net',
        (_) => false,
      );
      
      _initialized = true;
      print('[IOSBindings] All symbols initialized successfully');
      
    } catch (e) {
      print('[IOSBindings] ERROR during initialization: $e');
      throw Exception('Failed to initialize iOS bindings: $e');
    }
  }
  
  Future<F> _getFunction<T extends ffi.NativeFunction, F extends Function>(
    String symbolName, 
    F fallback,
  ) async {
    try {
      final address = await _channel.invokeMethod<int>('getSymbolPointer', {
        'symbolName': symbolName,
      });
      
      if (address == null || address == 0) {
        throw Exception('Failed to get address for $symbolName');
      }
      
      print('[IOSBindings] Got address for $symbolName: 0x${address.toRadixString(16)}');
      
      final ptr = ffi.Pointer<ffi.NativeFunction<T>>.fromAddress(address);
      return ptr.asFunction<F>();
    } catch (e) {
      print('[IOSBindings] ERROR: Failed to get $symbolName: $e');
      return fallback;
    }
  }
  
  // Public API methods
  
  /// Initialize the network library
  bool shorebird_init_network(
    ffi.Pointer<AppParameters> app_params,
    ffi.Pointer<NetworkConfig> config,
    FileCallbacks callbacks,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_init_network');
      return false;
    }
    return _shorebird_init_network(app_params, config, callbacks);
  }

  /// Get current boot patch number
  int shorebird_current_boot_patch_number_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_current_boot_patch_number_net');
      return 0;
    }
    return _shorebird_current_boot_patch_number_net();
  }

  /// Get next boot patch number
  int shorebird_next_boot_patch_number_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_next_boot_patch_number_net');
      return 0;
    }
    return _shorebird_next_boot_patch_number_net();
  }

  /// Check for downloadable update
  bool shorebird_check_for_downloadable_update_net(
    ffi.Pointer<ffi.Char> track,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_check_for_downloadable_update_net');
      return false;
    }
    return _shorebird_check_for_downloadable_update_net(track);
  }

  /// Trigger update
  void shorebird_update_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_update_net');
      return;
    }
    _shorebird_update_net();
  }

  /// Update with result
  ffi.Pointer<UpdateResult> shorebird_update_with_result_net(
    ffi.Pointer<ffi.Char> track,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_update_with_result_net');
      return ffi.nullptr;
    }
    return _shorebird_update_with_result_net(track);
  }

  /// Free update result
  void shorebird_free_update_result_net(
    ffi.Pointer<UpdateResult> result,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_free_update_result_net');
      return;
    }
    _shorebird_free_update_result_net(result);
  }

  /// Update base URL
  bool shorebird_update_base_url_net(
    ffi.Pointer<ffi.Char> base_url,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_update_base_url_net');
      return false;
    }
    return _shorebird_update_base_url_net(base_url);
  }

  /// Update download URL
  bool shorebird_update_download_url_net(
    ffi.Pointer<ffi.Char>? download_url,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_update_download_url_net');
      return false;
    }
    return _shorebird_update_download_url_net(download_url ?? ffi.nullptr);
  }

  /// Get app ID
  ffi.Pointer<ffi.Char> shorebird_get_app_id_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_get_app_id_net');
      return ffi.nullptr;
    }
    return _shorebird_get_app_id_net();
  }

  /// Get release version
  ffi.Pointer<ffi.Char> shorebird_get_release_version_net() {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_get_release_version_net');
      return ffi.nullptr;
    }
    return _shorebird_get_release_version_net();
  }

  /// Free string
  void shorebird_free_string_net(
    ffi.Pointer<ffi.Char> s,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_free_string_net');
      return;
    }
    _shorebird_free_string_net(s);
  }

  /// Download update if available
  bool shorebird_download_update_if_available_net(
    ffi.Pointer<ffi.Char> track,
  ) {
    if (!_initialized) {
      print('[IOSBindings] WARNING: Using uninitialized bindings for shorebird_download_update_if_available_net');
      return false;
    }
    return _shorebird_download_update_if_available_net(track);
  }
}