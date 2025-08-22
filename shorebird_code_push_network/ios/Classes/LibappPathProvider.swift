import Flutter
import Foundation

class LibappPathProvider: NSObject {
    private let channel: FlutterMethodChannel
    
    // Cache for App framework path
    private static var cachedAppFrameworkPath: String?
    
    init(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "dev.shorebird.code_push_network/libapp",
            binaryMessenger: registrar.messenger()
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getLibappPaths":
            result(getLibappPaths())
        case "getBundlePath":
            result(Bundle.main.bundlePath)
        case "getDeviceArchitecture":
            result(getDeviceArchitecture())
        case "getStoragePaths":
            result(getStoragePaths())
        case "getAppInfo":
            result(getAppInfo())
        case "debugFrameworkLocations":
            result(debugFrameworkLocations())
        case "createAppDataProvider":
            if let provider = createAppDataProvider() {
                result(["success": true, "path": provider.appPath])
            } else {
                result(FlutterError(code: "PROVIDER_ERROR", 
                                  message: "Failed to create App data provider", 
                                  details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getLibappPaths() -> [String]? {
        // Check cache first
        if let cachedPath = LibappPathProvider.cachedAppFrameworkPath,
           FileManager.default.fileExists(atPath: cachedPath) {
            print("[LibappPathProvider] Using cached App path: \(cachedPath)")
            return [cachedPath]
        }
        
        // Method 1: Direct path construction
        let directPath = Bundle.main.bundlePath + "/Frameworks/App.framework/App"
        if FileManager.default.fileExists(atPath: directPath) {
            print("[LibappPathProvider] Found App at direct path: \(directPath)")
            LibappPathProvider.cachedAppFrameworkPath = directPath
            return [directPath]
        }
        
        // Method 2: Using Bundle API
        if let frameworkPath = Bundle.main.path(forResource: "App", ofType: "framework") {
            let appPath = frameworkPath + "/App"
            if FileManager.default.fileExists(atPath: appPath) {
                print("[LibappPathProvider] Found App using Bundle API: \(appPath)")
                LibappPathProvider.cachedAppFrameworkPath = appPath
                return [appPath]
            }
        }
        
        // Method 3: Search in Frameworks directory
        let frameworksPath = Bundle.main.bundlePath + "/Frameworks"
        if let frameworks = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
            for framework in frameworks {
                if framework == "App.framework" {
                    let appPath = frameworksPath + "/" + framework + "/App"
                    if FileManager.default.fileExists(atPath: appPath) {
                        print("[LibappPathProvider] Found App in Frameworks directory: \(appPath)")
                        LibappPathProvider.cachedAppFrameworkPath = appPath
                        return [appPath]
                    }
                }
            }
        }
        
        print("[LibappPathProvider] ERROR: App.framework/App not found at any expected location")
        debugFrameworkLocations() // Print debug info
        return nil
    }
    
    private func getAppInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        // Basic app info
        info["bundlePath"] = Bundle.main.bundlePath
        info["bundleIdentifier"] = Bundle.main.bundleIdentifier ?? "unknown"
        info["version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"
        info["buildNumber"] = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "unknown"
        
        // Framework info
        if let appPaths = getLibappPaths(), let appPath = appPaths.first {
            info["appFrameworkPath"] = appPath
            
            // Get file attributes
            if let attributes = try? FileManager.default.attributesOfItem(atPath: appPath) {
                info["appFrameworkSize"] = attributes[.size] ?? 0
                info["appFrameworkModificationDate"] = (attributes[.modificationDate] as? Date)?.description ?? "unknown"
            }
        }
        
        // List Frameworks directory contents
        let frameworksPath = Bundle.main.bundlePath + "/Frameworks"
        if let frameworks = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
            info["frameworksContents"] = frameworks
        }
        
        // Device info
        info["deviceArchitecture"] = getDeviceArchitecture()
        info["systemVersion"] = UIDevice.current.systemVersion
        info["deviceModel"] = UIDevice.current.model
        
        return info
    }
    
    private func debugFrameworkLocations() -> [String: Any] {
        var debugInfo: [String: Any] = [:]
        
        // 1. Check main bundle
        let bundlePath = Bundle.main.bundlePath
        debugInfo["bundlePath"] = bundlePath
        
        // 2. Check expected paths
        var expectedPaths: [[String: Any]] = []
        
        // Direct path
        let directPath = bundlePath + "/Frameworks/App.framework/App"
        expectedPaths.append([
            "path": directPath,
            "exists": FileManager.default.fileExists(atPath: directPath),
            "isReadable": FileManager.default.isReadableFile(atPath: directPath)
        ])
        
        // Framework directory
        let frameworkDir = bundlePath + "/Frameworks/App.framework"
        expectedPaths.append([
            "path": frameworkDir,
            "exists": FileManager.default.fileExists(atPath: frameworkDir),
            "isDirectory": isDirectory(at: frameworkDir)
        ])
        
        debugInfo["expectedPaths"] = expectedPaths
        
        // 3. List Frameworks directory
        let frameworksPath = bundlePath + "/Frameworks"
        if FileManager.default.fileExists(atPath: frameworksPath) {
            var frameworksInfo: [String: Any] = [:]
            frameworksInfo["exists"] = true
            frameworksInfo["isDirectory"] = isDirectory(at: frameworksPath)
            
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
                frameworksInfo["contents"] = contents.map { item -> [String: Any] in
                    let itemPath = frameworksPath + "/" + item
                    var itemInfo: [String: Any] = ["name": item]
                    
                    if item == "App.framework" {
                        // Check App.framework contents
                        if let appContents = try? FileManager.default.contentsOfDirectory(atPath: itemPath) {
                            itemInfo["contents"] = appContents
                            
                            // Check for App binary
                            let appBinaryPath = itemPath + "/App"
                            if FileManager.default.fileExists(atPath: appBinaryPath) {
                                itemInfo["appBinaryExists"] = true
                                if let attrs = try? FileManager.default.attributesOfItem(atPath: appBinaryPath) {
                                    itemInfo["appBinarySize"] = attrs[.size] ?? 0
                                }
                            }
                        }
                    }
                    
                    return itemInfo
                }
            } else {
                frameworksInfo["contents"] = "unable to read"
            }
            
            debugInfo["frameworksDirectory"] = frameworksInfo
        } else {
            debugInfo["frameworksDirectory"] = ["exists": false]
        }
        
        // 4. Check using Bundle API
        if let resourcePath = Bundle.main.resourcePath {
            debugInfo["resourcePath"] = resourcePath
        }
        
        if let frameworkPath = Bundle.main.path(forResource: "App", ofType: "framework") {
            debugInfo["bundleApiFrameworkPath"] = frameworkPath
        }
        
        // 5. System info
        debugInfo["systemInfo"] = [
            "architecture": getDeviceArchitecture(),
            "systemVersion": UIDevice.current.systemVersion,
            "isSimulator": isSimulator()
        ]
        
        // Print debug info
        print("[LibappPathProvider] Debug Framework Locations:")
        print(debugInfo)
        
        return debugInfo
    }
    
    private func getDeviceArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    
    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
    
    private func getStoragePaths() -> [String: String] {
        let fileManager = FileManager.default
        
        // Get the application support directory
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                           in: .userDomainMask).first?.path ?? ""
        
        // Get the caches directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, 
                                      in: .userDomainMask).first?.path ?? ""
        
        // Get documents directory
        let documentsDir = fileManager.urls(for: .documentDirectory,
                                          in: .userDomainMask).first?.path ?? ""
        
        print("[LibappPathProvider] App support dir: \(appSupportDir)")
        print("[LibappPathProvider] Cache dir: \(cacheDir)")
        print("[LibappPathProvider] Documents dir: \(documentsDir)")
        
        return [
            "appStorageDir": appSupportDir,
            "codeCacheDir": cacheDir,
            "documentsDir": documentsDir
        ]
    }
    
    // Create a data provider for App.framework (similar to Android's file handle)
    private func createAppDataProvider() -> AppDataProvider? {
        guard let appPaths = getLibappPaths(),
              let appPath = appPaths.first else {
            return nil
        }
        
        return AppDataProvider(appPath: appPath)
    }
}

// Data provider class for accessing App.framework data
class AppDataProvider {
    let appPath: String
    private var fileHandle: FileHandle?
    
    init?(appPath: String) {
        self.appPath = appPath
        self.fileHandle = FileHandle(forReadingAtPath: appPath)
        
        if fileHandle == nil {
            print("[AppDataProvider] Failed to open file handle for: \(appPath)")
            return nil
        }
        
        print("[AppDataProvider] Successfully created data provider for: \(appPath)")
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    func read(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        guard let fileHandle = fileHandle else { return 0 }
        
        let data = fileHandle.readData(ofLength: length)
        data.copyBytes(to: buffer, count: data.count)
        return data.count
    }
    
    func seek(offset: Int64, whence: Int32) -> Int64 {
        guard let fileHandle = fileHandle else { return -1 }
        
        switch whence {
        case 0: // SEEK_SET
            fileHandle.seek(toFileOffset: UInt64(offset))
        case 1: // SEEK_CUR
            let currentOffset = fileHandle.offsetInFile
            fileHandle.seek(toFileOffset: currentOffset + UInt64(offset))
        case 2: // SEEK_END
            let endOffset = fileHandle.seekToEndOfFile()
            fileHandle.seek(toFileOffset: endOffset + UInt64(offset))
        default:
            return -1
        }
        
        return Int64(fileHandle.offsetInFile)
    }
    
    var fileSize: Int64? {
        guard let fileHandle = fileHandle else { return nil }
        
        let currentOffset = fileHandle.offsetInFile
        let size = fileHandle.seekToEndOfFile()
        fileHandle.seek(toFileOffset: currentOffset) // Restore position
        
        return Int64(size)
    }
}