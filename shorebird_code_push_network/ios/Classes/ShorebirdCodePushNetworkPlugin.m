//
//  ShorebirdCodePushNetworkPlugin.m
//  shorebird_code_push_network
//

#import "ShorebirdCodePushNetworkPlugin.h"
#import "ShorebirdNetworkHook.h"

@implementation ShorebirdCodePushNetworkPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"shorebird_code_push_network"
              binaryMessenger:[registrar messenger]];
    ShorebirdCodePushNetworkPlugin *instance = [[ShorebirdCodePushNetworkPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    // 网络 Hook 已经在 ShorebirdNetworkHook.m 中通过 __attribute__((constructor)) 自动初始化
    NSLog(@"[ShorebirdNetwork] Plugin registered, network hooks already initialized");
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSLog(@"[ShorebirdNetwork] Method call: %@", call.method);
    
    if ([@"updateBaseUrl" isEqualToString:call.method]) {
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
    } else if ([@"addHostMapping" isEqualToString:call.method]) {
        // 添加通用域名映射
        NSDictionary *args = call.arguments;
        NSString *originalHost = args[@"originalHost"];
        NSString *redirectHost = args[@"redirectHost"];
        
        if (originalHost && redirectHost) {
            shorebird_add_host_mapping([originalHost UTF8String], [redirectHost UTF8String]);
            NSLog(@"ShorebirdNetwork: Added host mapping %@ -> %@", originalHost, redirectHost);
            result(@YES);
        } else {
            result(@NO);
        }
    } else if ([@"removeHostMapping" isEqualToString:call.method]) {
        // 移除域名映射
        NSDictionary *args = call.arguments;
        NSString *originalHost = args[@"originalHost"];
        
        if (originalHost) {
            shorebird_remove_host_mapping([originalHost UTF8String]);
            NSLog(@"ShorebirdNetwork: Removed host mapping for %@", originalHost);
            result(@YES);
        } else {
            result(@NO);
        }
    } else if ([@"clearAllHostMappings" isEqualToString:call.method]) {
        // 清空所有域名映射
        shorebird_clear_all_host_mappings();
        NSLog(@"ShorebirdNetwork: Cleared all host mappings");
        result(@YES);
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