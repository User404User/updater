//
//  ShorebirdNetworkHookManager.m
//  shorebird_code_push_network
//

#import "ShorebirdNetworkHookManager.h"
#import "ShorebirdURLSessionHook.h"
#import "ShorebirdNetworkHook.h"
#import "ShorebirdCFNetworkHook.h"

@implementation ShorebirdNetworkHookManager {
    BOOL _isInitialized;
}

+ (instancetype)shared {
    static ShorebirdNetworkHookManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ShorebirdNetworkHookManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
        // 自动启动所有 Hook
        [self startAllHooks];
    }
    return self;
}

- (void)startAllHooks {
    if (_isInitialized) {
        NSLog(@"[NetworkHookManager] Hooks already initialized");
        return;
    }
    
    NSLog(@"[NetworkHookManager] Starting all network hooks...");
    
    // 1. Socket 层和 DNS Hook 已经通过 __attribute__((constructor)) 自动启动
    NSLog(@"[NetworkHookManager] Socket and DNS hooks auto-started");
    
    // 2. CFNetwork Hook 也通过 __attribute__((constructor)) 自动启动
    NSLog(@"[NetworkHookManager] CFNetwork hooks auto-started");
    
    // 3. 启动 NSURLSession Hook
    [ShorebirdURLSessionHook startMonitoring];
    NSLog(@"[NetworkHookManager] NSURLSession hooks started");
    
    _isInitialized = YES;
    NSLog(@"[NetworkHookManager] All network hooks initialized successfully");
    
    // 打印启动信息
    NSLog(@"[NetworkHookManager] ================================================");
    NSLog(@"[NetworkHookManager] Shorebird Network Hooks Active:");
    NSLog(@"[NetworkHookManager] - DNS Resolution (getaddrinfo)");
    NSLog(@"[NetworkHookManager] - Socket Operations (socket, connect, send, recv)");
    NSLog(@"[NetworkHookManager] - NSURLSession (dataTask, downloadTask, uploadTask)");
    NSLog(@"[NetworkHookManager] - CFNetwork (CFHTTPMessage, CFReadStream)");
    NSLog(@"[NetworkHookManager] ================================================");
}

- (BOOL)isInitialized {
    return _isInitialized;
}

@end

// 在库加载时自动初始化
__attribute__((constructor))
static void initialize_network_hooks() {
    // 确保 Hook Manager 被创建并初始化
    [ShorebirdNetworkHookManager shared];
}