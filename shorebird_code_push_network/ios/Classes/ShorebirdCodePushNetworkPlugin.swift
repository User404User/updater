import Flutter
import UIKit

// 导入 C 函数声明
// shorebird_init_network 是网络库特有的初始化函数，不需要 _net 后缀
@_silgen_name("shorebird_init_network")
func shorebird_init_network(app_params: UnsafePointer<Void>, config: UnsafePointer<Void>, callbacks: UnsafePointer<Void>) -> Bool

@_silgen_name("shorebird_current_boot_patch_number_net")
func shorebird_current_boot_patch_number_net() -> Int32

@_silgen_name("shorebird_next_boot_patch_number_net")
func shorebird_next_boot_patch_number_net() -> Int32

@_silgen_name("shorebird_check_for_downloadable_update_net")
func shorebird_check_for_downloadable_update_net(track: UnsafePointer<CChar>?) -> Bool

@_silgen_name("shorebird_update_net")
func shorebird_update_net() -> Void

@_silgen_name("shorebird_update_with_result_net")
func shorebird_update_with_result_net(track: UnsafePointer<CChar>?) -> UnsafeRawPointer

@_silgen_name("shorebird_free_update_result_net")
func shorebird_free_update_result_net(result: UnsafeRawPointer) -> Void

@_silgen_name("shorebird_update_base_url_net")
func shorebird_update_base_url_net(base_url: UnsafePointer<CChar>) -> Bool

@_silgen_name("shorebird_update_download_url_net")
func shorebird_update_download_url_net(download_url: UnsafePointer<CChar>?) -> Bool

@_silgen_name("shorebird_get_app_id_net")
func shorebird_get_app_id_net() -> UnsafePointer<CChar>

@_silgen_name("shorebird_get_release_version_net")
func shorebird_get_release_version_net() -> UnsafePointer<CChar>

@_silgen_name("shorebird_free_string_net")
func shorebird_free_string_net(s: UnsafePointer<CChar>) -> Void

// Note: shorebird_download_update_if_available_net is not available in network library

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
    
    // 测试是否能调用 shorebird_init_network（不带 _net 后缀）
    print("ShorebirdNetworkPlugin: Testing shorebird_init_network availability...")
    // 注意：我们不实际调用它，因为需要参数
    
    // 测试 _net 后缀函数
    print("ShorebirdNetworkPlugin: Testing shorebird_current_boot_patch_number_net...")
    let netResult = shorebird_current_boot_patch_number_net()
    print("ShorebirdNetworkPlugin: Net function call successful, result: \(netResult)")
    
    libraryVerified = true
    print("ShorebirdNetworkPlugin: Library verification successful")
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
    case "getSymbolPointer":
      // 获取符号指针地址
      if let args = call.arguments as? [String: Any],
         let symbolName = args["symbolName"] as? String {
        if let pointer = ShorebirdSymbolMapper.getSymbolPointer(name: symbolName) {
          // 返回指针地址的整数值
          result(Int(bitPattern: pointer))
        } else {
          result(FlutterError(code: "SYMBOL_NOT_FOUND",
                             message: "Symbol \(symbolName) not found",
                             details: nil))
        }
      } else {
        result(FlutterError(code: "INVALID_ARGS",
                           message: "Missing symbolName argument",
                           details: nil))
      }
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