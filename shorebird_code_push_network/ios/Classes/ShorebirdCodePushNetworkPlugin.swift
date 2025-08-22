import Flutter
import UIKit

// 导入 C 函数声明
@_silgen_name("shorebird_current_boot_patch_number")
func shorebird_current_boot_patch_number() -> Int32

@_silgen_name("shorebird_current_boot_patch_number_net")
func shorebird_current_boot_patch_number_net() -> Int32

public class ShorebirdCodePushNetworkPlugin: NSObject, FlutterPlugin {
  private static var libraryVerified = false
  private static var libappPathProvider: LibappPathProvider?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "shorebird_code_push_network", binaryMessenger: registrar.messenger())
    let instance = ShorebirdCodePushNetworkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Also register on the channel used by network_init.dart
    let storageChannel = FlutterMethodChannel(name: "dev.shorebird.code_push", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: storageChannel)
    
    // Register the libapp path provider
    libappPathProvider = LibappPathProvider(with: registrar)
    
    // 在插件注册时验证库
    verifyLibrary()
  }
  
  private static func verifyLibrary() {
    print("ShorebirdNetworkPlugin: Verifying iOS library...")
    
    do {
      // 尝试调用标准函数
      let standardResult = shorebird_current_boot_patch_number()
      print("ShorebirdNetworkPlugin: Standard function call successful, result: \(standardResult)")
      
      // 尝试调用 _net 后缀函数
      let netResult = shorebird_current_boot_patch_number_net()
      print("ShorebirdNetworkPlugin: Net function call successful, result: \(netResult)")
      
      libraryVerified = true
      print("ShorebirdNetworkPlugin: Library verification successful")
      
    } catch {
      print("ShorebirdNetworkPlugin: Library verification failed: \(error)")
      libraryVerified = false
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "loadLibrary":
      // iOS uses static linking, library is already loaded
      result(Self.libraryVerified)
    case "isLibraryLoaded":
      result(Self.libraryVerified)
    case "verifyLibrary":
      Self.verifyLibrary()
      result(Self.libraryVerified)
    case "getStoragePaths":
      // Return paths that match the official Shorebird Engine
      // Based on FlutterDartProject.mm, iOS Engine uses:
      // - $HOME/Library/Application Support/shorebird for both storage and cache
      let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
      let appSupportPath = (libraryPath as NSString).appendingPathComponent("Application Support")
      let shorebirdPath = (appSupportPath as NSString).appendingPathComponent("shorebird")
      
      // iOS Engine uses the same path for both storage and cache
      let paths: [String: String] = [
        "appStorageDir": shorebirdPath,  // iOS Engine uses Library/Application Support/shorebird
        "codeCacheDir": shorebirdPath    // iOS Engine uses same path for cache
      ]
      
      print("ShorebirdNetwork: Returning iOS storage paths: \(paths)")
      result(paths)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}