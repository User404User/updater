import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Helper class to get the correct libapp.so paths on different platforms
class LibappPathHelper {
  static const _platform = MethodChannel('dev.shorebird.code_push_network/libapp');
  
  /// Get the libapp paths for the current platform
  static Future<List<String>?> getLibappPaths() async {
    if (Platform.isAndroid) {
      return _getAndroidLibappPaths();
    } else if (Platform.isIOS) {
      return null;
    }
    return null;
  }
  
  /// Get Android libapp paths
  /// Note: On Android, we need to provide paths that the native code can use to find libapp.so
  static Future<List<String>?> _getAndroidLibappPaths() async {
    try {
      // Try to get actual paths from native code
      final result = await _platform.invokeMethod<List<dynamic>>('getLibappPaths');
      if (result != null && result.isNotEmpty) {
        debugPrint('[LibappPathHelper] Got Android libapp paths from native: $result');
        return result.cast<String>();
      }
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to get native libapp paths: $e');
    }
    
    // Fallback: let the network library handle empty paths
    debugPrint('[LibappPathHelper] Using empty libapp paths for Android');
    return null;
  }

  
  /// Get the architecture-specific library directory name
  static Future<String> getArchLibraryDir() async {
    if (!Platform.isAndroid) return '';
    
    try {
      final arch = await _platform.invokeMethod<String>('getDeviceArchitecture');
      debugPrint('[LibappPathHelper] Device architecture: $arch');
      return arch ?? 'arm64-v8a';
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to get architecture: $e');
      return 'arm64-v8a'; // Default to most common
    }
  }
  
  /// Get detailed app information for debugging
  static Future<Map<String, dynamic>?> getAppInfo() async {
    try {
      final result = await _platform.invokeMethod<Map<dynamic, dynamic>>('getAppInfo');
      if (result != null) {
        debugPrint('[LibappPathHelper] App info: $result');
        return result.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to get app info: $e');
    }
    return null;
  }
  
  /// Debug framework/library locations (useful when paths are not found)
  static Future<Map<String, dynamic>?> debugLocations() async {
    try {
      if (Platform.isAndroid) {
        final result = await _platform.invokeMethod<Map<dynamic, dynamic>>('debugLibappLocations');
        if (result != null) {
          debugPrint('[LibappPathHelper] Android debug info:');
          _printDebugInfo(result);
          return result.cast<String, dynamic>();
        }
      } else if (Platform.isIOS) {
        final result = await _platform.invokeMethod<Map<dynamic, dynamic>>('debugFrameworkLocations');
        if (result != null) {
          debugPrint('[LibappPathHelper] iOS debug info:');
          _printDebugInfo(result);
          return result.cast<String, dynamic>();
        }
      }
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to get debug locations: $e');
    }
    return null;
  }
  
  /// Extract libapp.so from APK (Android only)
  static Future<String?> extractLibapp() async {
    if (!Platform.isAndroid) return null;
    
    try {
      final result = await _platform.invokeMethod<String>('extractLibapp');
      debugPrint('[LibappPathHelper] Extracted libapp to: $result');
      return result;
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to extract libapp: $e');
      return null;
    }
  }
  
  /// For development/testing: manually provide libapp paths
  /// Use this when you have extracted the APK and know the exact paths
  static List<String> getManualLibappPaths({
    required String basePath,
    String? architecture,
  }) {
    if (Platform.isAndroid) {
      // For Android, construct the full path
      final arch = architecture ?? 'arm64-v8a';
      final libappPath = path.join(basePath, 'lib', arch, 'libapp.so');
      debugPrint('[LibappPathHelper] Manual Android libapp path: $libappPath');
      
      // Android expects two paths: library name and full path
      return ['libapp.so', libappPath];
    } else if (Platform.isIOS) {
      // For iOS, it's App.framework/App
      final appPath = path.join(basePath, 'Frameworks', 'App.framework', 'App');
      debugPrint('[LibappPathHelper] Manual iOS app path: $appPath');
      return [appPath];
    }
    return [];
  }
  
  /// Check if a file exists and is readable
  static Future<bool> fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }
  
  /// Get storage paths from the native platform
  static Future<Map<String, String>?> getStoragePaths() async {
    try {
      final result = await _platform.invokeMethod<Map<dynamic, dynamic>>('getStoragePaths');
      if (result != null) {
        debugPrint('[LibappPathHelper] Got storage paths: $result');
        return result.cast<String, String>();
      }
    } catch (e) {
      debugPrint('[LibappPathHelper] Failed to get storage paths: $e');
    }
    return null;
  }
  
  /// Helper to print debug info in a readable format
  static void _printDebugInfo(Map<dynamic, dynamic> info, {String prefix = ''}) {
    info.forEach((key, value) {
      if (value is Map) {
        debugPrint('$prefix$key:');
        _printDebugInfo(value, prefix: '$prefix  ');
      } else if (value is List) {
        debugPrint('$prefix$key: [');
        for (var item in value) {
          if (item is Map) {
            _printDebugInfo(item, prefix: '$prefix  ');
          } else {
            debugPrint('$prefix  $item');
          }
        }
        debugPrint('$prefix]');
      } else {
        debugPrint('$prefix$key: $value');
      }
    });
  }
}

/// Example usage in your initialization code:
/// 
/// ```dart
/// // Basic usage
/// final config = NetworkUpdaterConfig(
///   appId: 'your-app-id',
///   releaseVersion: '1.0.0+1',
///   originalLibappPaths: await LibappPathHelper.getLibappPaths(),
///   // ... other config
/// );
/// 
/// // Debug when paths are not found
/// if (config.originalLibappPaths == null || config.originalLibappPaths!.isEmpty) {
///   final debugInfo = await LibappPathHelper.debugLocations();
///   print('Debug info: $debugInfo');
///   
///   // On Android, try extracting from APK
///   if (Platform.isAndroid) {
///     final extractedPath = await LibappPathHelper.extractLibapp();
///     if (extractedPath != null) {
///       config = config.copyWith(
///         originalLibappPaths: ['libapp.so', extractedPath],
///       );
///     }
///   }
/// }
/// ```