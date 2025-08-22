package dev.shorebird.code_push_network

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

class LibappPathProvider(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LibappPathProvider"
        private var cachedLibappPath: String? = null
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
            "extractLibapp" -> {
                try {
                    val extractedPath = extractLibappFromApk()
                    if (extractedPath != null) {
                        result.success(extractedPath)
                    } else {
                        result.error("EXTRACTION_FAILED", "Failed to extract libapp.so", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error extracting libapp", e)
                    result.error("EXTRACTION_ERROR", e.message, null)
                }
            }
            "debugLibappLocations" -> {
                try {
                    val debugInfo = debugLibappLocations()
                    result.success(debugInfo)
                } catch (e: Exception) {
                    Log.e(TAG, "Error debugging libapp locations", e)
                    result.error("DEBUG_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getLibappPaths(): List<String> {
        val paths = mutableListOf<String>()
        
        // First path is always "libapp.so" for dlopen
        paths.add("libapp.so")
        
        // Check cache first
        cachedLibappPath?.let {
            if (File(it).exists()) {
                Log.d(TAG, "Using cached libapp.so path: $it")
                paths.add(it)
                return paths
            }
        }
        
        val appInfo = context.applicationInfo
        val nativeLibraryDir = appInfo.nativeLibraryDir
        
        // Try to find the actual libapp.so location
        val libappFile = File(nativeLibraryDir, "libapp.so")
        
        if (libappFile.exists()) {
            // Library is extracted, use the actual path
            Log.d(TAG, "Found extracted libapp.so at: ${libappFile.absolutePath}")
            cachedLibappPath = libappFile.absolutePath
            paths.add(libappFile.absolutePath)
        } else {
            // Try to extract from APK
            Log.d(TAG, "libapp.so not found in nativeLibraryDir, attempting to extract from APK")
            val extractedPath = extractLibappFromApk()
            if (extractedPath != null) {
                Log.d(TAG, "Successfully extracted libapp.so to: $extractedPath")
                cachedLibappPath = extractedPath
                paths.add(extractedPath)
            } else {
                // Fallback: construct the expected path
                val constructedPath = "$nativeLibraryDir/libapp.so"
                Log.d(TAG, "Failed to extract, using constructed path: $constructedPath")
                paths.add(constructedPath)
            }
        }
        
        return paths
    }

    private fun getAppInfo(): Map<String, String> {
        val appInfo = context.applicationInfo
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        
        // List all files in nativeLibraryDir
        val nativeLibFiles = try {
            File(appInfo.nativeLibraryDir).listFiles()?.map { it.name }?.joinToString(", ") ?: "empty"
        } catch (e: Exception) {
            "error: ${e.message}"
        }
        
        // Check split APKs
        val splitApks = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            appInfo.splitSourceDirs?.joinToString(", ") ?: "none"
        } else {
            "not supported"
        }
        
        return mapOf(
            "packageName" to context.packageName,
            "nativeLibraryDir" to appInfo.nativeLibraryDir,
            "sourceDir" to appInfo.sourceDir,
            "splitSourceDirs" to splitApks,
            "nativeLibFiles" to nativeLibFiles,
            "versionName" to (packageInfo.versionName ?: "unknown"),
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toString()
            },
            "architecture" to getDeviceArchitecture()
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
    
    private fun extractLibappFromApk(): String? {
        val appInfo = context.applicationInfo
        val arch = getDeviceArchitecture()
        
        // Convert architecture name to lib directory format
        val libArch = when (arch) {
            "arm64-v8a" -> "arm64-v8a"
            "armeabi-v7a" -> "armeabi-v7a"
            "x86" -> "x86"
            "x86_64" -> "x86_64"
            else -> arch
        }
        
        // Find APK containing libapp.so
        val apkPath = findApkContainingLib(appInfo, libArch)
        if (apkPath == null) {
            Log.e(TAG, "Could not find APK containing libapp.so for architecture: $libArch")
            listApkContents(appInfo) // Debug: list all APK contents
            return null
        }
        
        // Extract libapp.so from APK
        return extractLibFromApk(apkPath, libArch)
    }
    
    private fun findApkContainingLib(appInfo: ApplicationInfo, arch: String): String? {
        val libPath = "lib/$arch/libapp.so"
        
        // Check base APK
        Log.d(TAG, "Checking base APK: ${appInfo.sourceDir}")
        if (checkApkContainsFile(appInfo.sourceDir, libPath)) {
            Log.d(TAG, "Found libapp.so in base APK")
            return appInfo.sourceDir
        }
        
        // Check split APKs (API 21+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            appInfo.splitSourceDirs?.forEach { splitApk ->
                Log.d(TAG, "Checking split APK: $splitApk")
                if (checkApkContainsFile(splitApk, libPath)) {
                    Log.d(TAG, "Found libapp.so in split APK: $splitApk")
                    return splitApk
                }
            }
        }
        
        return null
    }
    
    private fun checkApkContainsFile(apkPath: String, filePath: String): Boolean {
        return try {
            ZipFile(apkPath).use { zip ->
                zip.getEntry(filePath) != null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking APK $apkPath: ${e.message}")
            false
        }
    }
    
    private fun extractLibFromApk(apkPath: String, arch: String): String? {
        val libPath = "lib/$arch/libapp.so"
        val outputDir = File(context.cacheDir, "shorebird_extracted_libs")
        outputDir.mkdirs()
        
        val outputFile = File(outputDir, "libapp.so")
        
        return try {
            ZipFile(apkPath).use { zip ->
                val entry = zip.getEntry(libPath)
                if (entry == null) {
                    Log.e(TAG, "Entry $libPath not found in APK")
                    return null
                }
                
                zip.getInputStream(entry).use { input ->
                    FileOutputStream(outputFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            
            // Make the file executable
            outputFile.setExecutable(true)
            outputFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting libapp.so: ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    private fun listApkContents(appInfo: ApplicationInfo) {
        try {
            Log.d(TAG, "Listing contents of base APK: ${appInfo.sourceDir}")
            ZipFile(appInfo.sourceDir).use { zip ->
                val entries = zip.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    if (entry.name.contains("lib/") && entry.name.endsWith(".so")) {
                        Log.d(TAG, "  Found library: ${entry.name}")
                    }
                }
            }
            
            // List split APKs
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                appInfo.splitSourceDirs?.forEach { splitApk ->
                    Log.d(TAG, "Listing contents of split APK: $splitApk")
                    try {
                        ZipFile(splitApk).use { zip ->
                            val entries = zip.entries()
                            while (entries.hasMoreElements()) {
                                val entry = entries.nextElement()
                                if (entry.name.contains("lib/") && entry.name.endsWith(".so")) {
                                    Log.d(TAG, "  Found library: ${entry.name}")
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error listing split APK $splitApk: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error listing APK contents: ${e.message}")
        }
    }
    
    private fun debugLibappLocations(): Map<String, Any> {
        val debugInfo = mutableMapOf<String, Any>()
        val appInfo = context.applicationInfo
        
        // 1. Check native library directory
        val nativeLibDir = appInfo.nativeLibraryDir
        debugInfo["nativeLibraryDir"] = nativeLibDir
        
        val nativeLibFiles = try {
            val dir = File(nativeLibDir)
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.map { file ->
                    mapOf(
                        "name" to file.name,
                        "size" to file.length(),
                        "canRead" to file.canRead()
                    )
                } ?: emptyList()
            } else {
                listOf(mapOf("error" to "Directory does not exist or is not a directory"))
            }
        } catch (e: Exception) {
            listOf(mapOf("error" to e.message))
        }
        debugInfo["nativeLibFiles"] = nativeLibFiles
        
        // 2. Try to find libapp.so in various locations
        val possiblePaths = mutableListOf<Map<String, Any>>()
        
        // Direct path
        val directPath = File(nativeLibDir, "libapp.so")
        possiblePaths.add(mapOf(
            "path" to directPath.absolutePath,
            "exists" to directPath.exists(),
            "canRead" to directPath.canRead()
        ))
        
        // Parent directories
        var parentDir = File(nativeLibDir).parentFile
        while (parentDir != null && parentDir.absolutePath.contains(context.packageName)) {
            val libDir = File(parentDir, "lib")
            if (libDir.exists()) {
                libDir.listFiles()?.forEach { archDir ->
                    if (archDir.isDirectory) {
                        val libappPath = File(archDir, "libapp.so")
                        possiblePaths.add(mapOf(
                            "path" to libappPath.absolutePath,
                            "exists" to libappPath.exists(),
                            "canRead" to libappPath.canRead()
                        ))
                    }
                }
            }
            parentDir = parentDir.parentFile
        }
        
        debugInfo["possiblePaths"] = possiblePaths
        
        // 3. APK information
        val apkInfo = mutableMapOf<String, Any>()
        apkInfo["sourceDir"] = appInfo.sourceDir
        apkInfo["sourceDirExists"] = File(appInfo.sourceDir).exists()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            apkInfo["splitSourceDirs"] = appInfo.splitSourceDirs?.toList() ?: emptyList<String>()
        }
        
        // Check APK contents
        val arch = getDeviceArchitecture()
        val libPath = "lib/$arch/libapp.so"
        apkInfo["expectedLibPath"] = libPath
        apkInfo["baseApkContainsLib"] = checkApkContainsFile(appInfo.sourceDir, libPath)
        
        debugInfo["apkInfo"] = apkInfo
        
        // 4. Extraction attempt
        val extractionInfo = mutableMapOf<String, Any>()
        val cacheDir = File(context.cacheDir, "shorebird_extracted_libs")
        extractionInfo["extractionDir"] = cacheDir.absolutePath
        extractionInfo["extractionDirExists"] = cacheDir.exists()
        
        val extractedFile = File(cacheDir, "libapp.so")
        extractionInfo["extractedFilePath"] = extractedFile.absolutePath
        extractionInfo["extractedFileExists"] = extractedFile.exists()
        if (extractedFile.exists()) {
            extractionInfo["extractedFileSize"] = extractedFile.length()
            extractionInfo["extractedFileCanRead"] = extractedFile.canRead()
            extractionInfo["extractedFileCanExecute"] = extractedFile.canExecute()
        }
        
        debugInfo["extractionInfo"] = extractionInfo
        
        // 5. System info
        debugInfo["deviceArchitecture"] = getDeviceArchitecture()
        debugInfo["androidVersion"] = Build.VERSION.SDK_INT
        
        return debugInfo
    }
}