//
//  ShorebirdCodePushNetworkPlugin.m
//  shorebird_code_push_network
//

#import "ShorebirdCodePushNetworkPlugin.h"
#import "ShorebirdNetworkHook.h"
#import "ShorebirdURLSessionHook.h"
#import "ShorebirdNetworkHookManager.h"

@implementation ShorebirdCodePushNetworkPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"shorebird_code_push_network"
              binaryMessenger:[registrar messenger]];
    ShorebirdCodePushNetworkPlugin *instance = [[ShorebirdCodePushNetworkPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    // 确保所有网络 Hook 已经初始化
    [[ShorebirdNetworkHookManager shared] startAllHooks];
    NSLog(@"[ShorebirdNetwork] Plugin registered, all network hooks active");
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSLog(@"[ShorebirdNetwork] Method call: %@", call.method);
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"loadLibrary" isEqualToString:call.method]) {
        // iOS 使用官方 shorebird_code_push 包，不需要加载库
        result(@YES);
    } else if ([@"isLibraryLoaded" isEqualToString:call.method]) {
        // iOS 使用官方 shorebird_code_push 包，始终可用
        result(@YES);
    } else if ([@"verifyLibrary" isEqualToString:call.method]) {
        // iOS 使用官方 shorebird_code_push 包，始终验证通过
        result(@YES);
    } else if ([@"getStoragePaths" isEqualToString:call.method]) {
        // 返回与官方 Shorebird Engine 匹配的路径
        // 基于 FlutterDartProject.mm，iOS Engine 使用：
        // - $HOME/Library/Application Support/shorebird 作为存储和缓存
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryPath = [paths firstObject];
        NSString *appSupportPath = [libraryPath stringByAppendingPathComponent:@"Application Support"];
        NSString *shorebirdPath = [appSupportPath stringByAppendingPathComponent:@"shorebird"];
        
        // iOS Engine 对存储和缓存使用相同的路径
        NSDictionary *pathDict = @{
            @"appStorageDir": shorebirdPath,  // iOS Engine 使用 Library/Application Support/shorebird
            @"codeCacheDir": shorebirdPath    // iOS Engine 对缓存使用相同路径
        };
        
        NSLog(@"ShorebirdNetwork: Returning iOS storage paths: %@", pathDict);
        result(pathDict);
    } else if ([@"updateBaseUrl" isEqualToString:call.method]) {
        // 更新 API URL 的 DNS hook
        NSDictionary *args = call.arguments;
        NSString *baseUrl = args[@"baseUrl"];
        
        if (baseUrl) {
            NSURL *url = [NSURL URLWithString:baseUrl];
            NSString *host = [url host];
            
            if (host) {
                shorebird_set_custom_api_host([host UTF8String]);
                NSLog(@"ShorebirdNetwork: Updated API host to %@", host);
                result(@YES);
            } else {
                result(@NO);
            }
        } else {
            result(@NO);
        }
    } else if ([@"updateDownloadUrl" isEqualToString:call.method]) {
        // 更新下载 URL 的 DNS hook
        NSDictionary *args = call.arguments;
        NSString *downloadUrl = args[@"downloadUrl"];
        
        if (downloadUrl) {
            NSURL *url = [NSURL URLWithString:downloadUrl];
            NSString *host = [url host];
            
            if (host) {
                shorebird_set_custom_cdn_host([host UTF8String]);
                NSLog(@"ShorebirdNetwork: Updated CDN host to %@", host);
                result(@YES);
            } else {
                result(@NO);
            }
        } else {
            // 清除自定义 CDN 主机
            shorebird_set_custom_cdn_host(NULL);
            NSLog(@"ShorebirdNetwork: Cleared CDN host");
            result(@YES);
        }
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end