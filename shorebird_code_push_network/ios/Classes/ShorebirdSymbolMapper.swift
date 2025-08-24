import Foundation

// 符号映射器，用于将函数名映射到实际的函数指针
@objc public class ShorebirdSymbolMapper: NSObject {
    @objc public static func getSymbolPointer(name: String) -> UnsafeMutableRawPointer? {
        switch name {
        case "shorebird_init_network":
            return unsafeBitCast(shorebird_init_network as @convention(c) (UnsafePointer<Void>, UnsafePointer<Void>, UnsafePointer<Void>) -> Bool, to: UnsafeMutableRawPointer.self)
        case "shorebird_current_boot_patch_number_net":
            return unsafeBitCast(shorebird_current_boot_patch_number_net as @convention(c) () -> Int32, to: UnsafeMutableRawPointer.self)
        case "shorebird_next_boot_patch_number_net":
            return unsafeBitCast(shorebird_next_boot_patch_number_net as @convention(c) () -> Int32, to: UnsafeMutableRawPointer.self)
        case "shorebird_check_for_downloadable_update_net":
            return unsafeBitCast(shorebird_check_for_downloadable_update_net as @convention(c) (UnsafePointer<CChar>?) -> Bool, to: UnsafeMutableRawPointer.self)
        case "shorebird_update_net":
            return unsafeBitCast(shorebird_update_net as @convention(c) () -> Void, to: UnsafeMutableRawPointer.self)
        case "shorebird_update_with_result_net":
            return unsafeBitCast(shorebird_update_with_result_net as @convention(c) (UnsafePointer<CChar>?) -> UnsafeRawPointer, to: UnsafeMutableRawPointer.self)
        case "shorebird_free_update_result_net":
            return unsafeBitCast(shorebird_free_update_result_net as @convention(c) (UnsafeRawPointer) -> Void, to: UnsafeMutableRawPointer.self)
        case "shorebird_update_base_url_net":
            return unsafeBitCast(shorebird_update_base_url_net as @convention(c) (UnsafePointer<CChar>) -> Bool, to: UnsafeMutableRawPointer.self)
        case "shorebird_update_download_url_net":
            return unsafeBitCast(shorebird_update_download_url_net as @convention(c) (UnsafePointer<CChar>?) -> Bool, to: UnsafeMutableRawPointer.self)
        case "shorebird_get_app_id_net":
            return unsafeBitCast(shorebird_get_app_id_net as @convention(c) () -> UnsafePointer<CChar>, to: UnsafeMutableRawPointer.self)
        case "shorebird_get_release_version_net":
            return unsafeBitCast(shorebird_get_release_version_net as @convention(c) () -> UnsafePointer<CChar>, to: UnsafeMutableRawPointer.self)
        case "shorebird_free_string_net":
            return unsafeBitCast(shorebird_free_string_net as @convention(c) (UnsafePointer<CChar>) -> Void, to: UnsafeMutableRawPointer.self)
        // Note: shorebird_download_update_if_available_net is not available in network library
        default:
            return nil
        }
    }
}