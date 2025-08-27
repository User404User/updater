//
//  ShorebirdURLSessionHook.h
//  shorebird_code_push_network
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShorebirdURLSessionHook : NSObject

+ (void)startMonitoring;
+ (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END