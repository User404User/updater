package dev.shorebird.code_push_network

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** ShorebirdCodePushNetworkPlugin */
class ShorebirdCodePushNetworkPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var libappPathProvider: LibappPathProvider
  
  companion object {
    private var libraryLoaded = false
    
    init {
      try {
        // 首先加载 JNI 包装器库，它会自动加载主库
        System.loadLibrary("shorebird_network_jni")
        android.util.Log.d("ShorebirdNetwork", "JNI wrapper library loaded successfully")
        
        // 然后尝试加载主库
        System.loadLibrary("shorebird_updater_network")
        libraryLoaded = true
        android.util.Log.d("ShorebirdNetwork", "Main native library loaded successfully")
        
        // 验证库是否正确加载
        if (nativeIsLibraryLoaded()) {
          android.util.Log.d("ShorebirdNetwork", "Native library verification successful")
        } else {
          android.util.Log.w("ShorebirdNetwork", "Native library verification failed")
        }
        
      } catch (e: UnsatisfiedLinkError) {
        android.util.Log.e("ShorebirdNetwork", "Failed to load native libraries: ${e.message}")
        libraryLoaded = false
      }
    }
    
    // 声明原生方法
    @JvmStatic
    external fun nativeIsLibraryLoaded(): Boolean
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "shorebird_code_push_network")
    channel.setMethodCallHandler(this)
    
    // Register the libapp path provider
    libappPathProvider = LibappPathProvider(flutterPluginBinding.applicationContext)
    val libappChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.shorebird.code_push_network/libapp")
    libappChannel.setMethodCallHandler(libappPathProvider)
    
    // Also register on the channel used by network_init.dart
    val storagePaths = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.shorebird.code_push")
    storagePaths.setMethodCallHandler { call, result ->
      when (call.method) {
        "getStoragePaths" -> {
          // Return paths that match the official Shorebird Engine
          // Engine uses context.getFilesDir() for app storage  
          // Engine uses context.getCacheDir() or context.getCodeCacheDir() for cache
          val context = flutterPluginBinding.applicationContext
          val paths = mapOf(
            "appStorageDir" to context.filesDir.absolutePath,  // /data/user/0/.../files
            "codeCacheDir" to (context.codeCacheDir?.absolutePath ?: context.cacheDir.absolutePath)
          )
          android.util.Log.d("ShorebirdNetwork", "Returning storage paths: $paths")
          result.success(paths)
        }
        else -> result.notImplemented()
      }
    }
    
    // Try to load library again if not already loaded
    if (!libraryLoaded) {
      try {
        System.loadLibrary("shorebird_updater_network")
        libraryLoaded = true
        android.util.Log.d("ShorebirdNetwork", "Native library loaded successfully in onAttachedToEngine")
      } catch (e: UnsatisfiedLinkError) {
        android.util.Log.e("ShorebirdNetwork", "Failed to load native library in onAttachedToEngine: ${e.message}")
      }
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "loadLibrary" -> {
        result.success(libraryLoaded)
      }
      "isLibraryLoaded" -> {
        result.success(libraryLoaded)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}