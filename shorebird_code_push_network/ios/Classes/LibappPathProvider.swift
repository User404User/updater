import Flutter
import Foundation

class LibappPathProvider: NSObject {
    private let channel: FlutterMethodChannel
    
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getLibappPaths() -> [String]? {
        // On iOS, the AOT compiled code is in App.framework/App
        let appFrameworkPath = Bundle.main.bundlePath + "/Frameworks/App.framework/App"
        
        // Check if the file exists
        if FileManager.default.fileExists(atPath: appFrameworkPath) {
            print("[LibappPathProvider] Found App at: \(appFrameworkPath)")
            return [appFrameworkPath]
        }
        
        print("[LibappPathProvider] App.framework/App not found at expected path")
        return nil
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
    
    private func getStoragePaths() -> [String: String] {
        let fileManager = FileManager.default
        
        // Get the application support directory
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, 
                                           in: .userDomainMask).first?.path ?? ""
        
        // Get the caches directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, 
                                      in: .userDomainMask).first?.path ?? ""
        
        print("[LibappPathProvider] App support dir: \(appSupportDir)")
        print("[LibappPathProvider] Cache dir: \(cacheDir)")
        
        return [
            "appStorageDir": appSupportDir,
            "codeCacheDir": cacheDir
        ]
    }
}