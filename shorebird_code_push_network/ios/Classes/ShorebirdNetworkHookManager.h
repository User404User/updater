//
//  ShorebirdNetworkHookManager.h
//  shorebird_code_push_network
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShorebirdNetworkHookManager : NSObject

+ (instancetype)shared;

// 启动所有网络 Hook
- (void)startAllHooks;

// 是否已经初始化
@property (nonatomic, readonly) BOOL isInitialized;

@end

NS_ASSUME_NONNULL_END