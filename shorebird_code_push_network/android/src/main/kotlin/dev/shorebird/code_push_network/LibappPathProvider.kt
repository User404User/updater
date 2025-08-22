package dev.shorebird.code_push_network

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class LibappPathProvider(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LibappPathProvider"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLibappPaths" -> {
                try {
                    val paths = getLibappPaths()
                    result.success(paths)
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting libapp paths", e)
                    result.error("LIBAPP_PATH_ERROR", e.message, null)
                }
            }
            "getAppInfo" -> {
                try {
                    val info = getAppInfo()
                    result.success(info)
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting app info", e)
                    result.error("APP_INFO_ERROR", e.message, null)
                }
            }
            "getDeviceArchitecture" -> {
                result.success(getDeviceArchitecture())
            }
            "getStoragePaths" -> {
                result.success(getStoragePaths())
            }
            else -> result.notImplemented()
        }
    }

    private fun getLibappPaths(): List<String> {
        val paths = mutableListOf<String>()
        
        // First path is always "libapp.so" for dlopen
        paths.add("libapp.so")
        
        val appInfo = context.applicationInfo
        val nativeLibraryDir = appInfo.nativeLibraryDir
        
        // Try to find the actual libapp.so location
        val libappFile = File(nativeLibraryDir, "libapp.so")
        
        if (libappFile.exists()) {
            // Library is extracted, use the actual path
            Log.d(TAG, "Found extracted libapp.so at: ${libappFile.absolutePath}")
            paths.add(libappFile.absolutePath)
        } else {
            // Library is compressed in APK, construct the expected path
            // This is what Flutter engine expects
            val constructedPath = "$nativeLibraryDir/libapp.so"
            Log.d(TAG, "Using constructed path (library in APK): $constructedPath")
            paths.add(constructedPath)
        }
        
        return paths
    }

    private fun getAppInfo(): Map<String, String> {
        val appInfo = context.applicationInfo
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        
        return mapOf(
            "packageName" to context.packageName,
            "nativeLibraryDir" to appInfo.nativeLibraryDir,
            "sourceDir" to appInfo.sourceDir,
            "versionName" to (packageInfo.versionName ?: "unknown"),
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toString()
            }
        )
    }
    
    private fun getDeviceArchitecture(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
        } else {
            @Suppress("DEPRECATION")
            Build.CPU_ABI
        }
    }
    
    private fun getStoragePaths(): Map<String, String> {
        val appDir = context.filesDir.absolutePath
        val cacheDir = context.cacheDir.absolutePath
        
        Log.d(TAG, "App storage dir: $appDir")
        Log.d(TAG, "Cache dir: $cacheDir")
        
        return mapOf(
            "appStorageDir" to appDir,
            "codeCacheDir" to cacheDir
        )
    }
}