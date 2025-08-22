import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Helper to get libapp.so paths on Android
class AndroidLibappHelper {
  static const platform = MethodChannel('dev.shorebird.code_push_network/libapp');
  
  /// Get the actual libapp.so paths from the Android system
  /// Returns a list of paths in the format expected by the updater
  static Future<List<String>?> getLibappPaths() async {
    if (!Platform.isAndroid) return null;
    
    try {
      // Method 1: Try to get from native Android code (most reliable)
      final paths = await _getPathsFromNative();
      if (paths != null && paths.isNotEmpty) {
        debugPrint('[AndroidLibappHelper] Got paths from native: $paths');
        return paths;
      }
    } catch (e) {
      debugPrint('[AndroidLibappHelper] Native method failed: $e');
    }
    
    // Method 2: Try to construct paths based on app info
    try {
      final constructedPaths = await _constructPaths();
      if (constructedPaths != null && constructedPaths.isNotEmpty) {
        debugPrint('[AndroidLibappHelper] Constructed paths: $constructedPaths');
        return constructedPaths;
      }
    } catch (e) {
      debugPrint('[AndroidLibappHelper] Path construction failed: $e');
    }
    
    return null;
  }
  
  /// Get paths from native Android code
  static Future<List<String>?> _getPathsFromNative() async {
    try {
      final result = await platform.invokeMethod<List<dynamic>>('getLibappPaths');
      return result?.cast<String>();
    } on PlatformException catch (e) {
      debugPrint('[AndroidLibappHelper] Platform exception: ${e.message}');
      return null;
    }
  }
  
  /// Construct paths based on app info
  static Future<List<String>?> _constructPaths() async {
    try {
      // Get app info to construct the path
      final Map<String, dynamic> appInfo = await platform.invokeMethod('getAppInfo');
      final String packageName = appInfo['packageName'];
      final String nativeLibraryDir = appInfo['nativeLibraryDir'];
      final String sourceDir = appInfo['sourceDir'];
      
      debugPrint('[AndroidLibappHelper] Package: $packageName');
      debugPrint('[AndroidLibappHelper] Native lib dir: $nativeLibraryDir');
      debugPrint('[AndroidLibappHelper] Source dir: $sourceDir');
      
      // Flutter engine expects two paths:
      // 1. Just "libapp.so" for dlopen
      // 2. Full path to the library
      final paths = <String>['libapp.so'];
      
      // Check if library is extracted
      final extractedPath = '$nativeLibraryDir/libapp.so';
      if (File(extractedPath).existsSync()) {
        paths.add(extractedPath);
        debugPrint('[AndroidLibappHelper] Found extracted libapp.so at: $extractedPath');
      } else {
        // Library is inside APK, construct the virtual path
        // This is what Flutter engine does internally
        final arch = _getCurrentArch();
        final virtualPath = '$nativeLibraryDir/libapp.so';
        paths.add(virtualPath);
        debugPrint('[AndroidLibappHelper] Using virtual path: $virtualPath');
      }
      
      return paths;
    } catch (e) {
      debugPrint('[AndroidLibappHelper] Error constructing paths: $e');
      return null;
    }
  }
  
  /// Get current device architecture
  static String _getCurrentArch() {
    // In production, get this from native code
    // For now, return the most common architecture
    return 'arm64-v8a';
  }
}