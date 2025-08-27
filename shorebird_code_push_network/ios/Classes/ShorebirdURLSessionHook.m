//
//  ShorebirdURLSessionHook.m
//  shorebird_code_push_network
//

#import "ShorebirdURLSessionHook.h"
#import <objc/runtime.h>

@implementation ShorebirdURLSessionHook

static IMP originalDataTaskWithRequestIMP = NULL;
static IMP originalDataTaskWithURLIMP = NULL;

// Hook NSURLSession dataTaskWithRequest:completionHandler:
static NSURLSessionDataTask* hooked_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData *data, NSURLResponse *response, NSError *error)) {
    NSLog(@"[URLSessionHook] dataTaskWithRequest: %@ %@", request.HTTPMethod ?: @"GET", request.URL);
    
    // 打印请求头
    if (request.allHTTPHeaderFields.count > 0) {
        NSLog(@"[URLSessionHook] Headers: %@", request.allHTTPHeaderFields);
    }
    
    // 打印请求体
    if (request.HTTPBody) {
        NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        if (bodyString) {
            NSLog(@"[URLSessionHook] Body: %@", bodyString);
        }
    }
    
    // 包装原始的 completion handler
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"[URLSessionHook] Response: %ld %@", (long)httpResponse.statusCode, response.URL);
            NSLog(@"[URLSessionHook] Response Headers: %@", httpResponse.allHeaderFields);
        }
        
        if (error) {
            NSLog(@"[URLSessionHook] Error: %@", error);
        }
        
        if (data && data.length > 0) {
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (dataString) {
                NSLog(@"[URLSessionHook] Response Data (first 500 chars): %@", 
                      [dataString substringToIndex:MIN(dataString.length, 500)]);
            }
        }
        
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    
    // 调用原始方法
    return ((NSURLSessionDataTask* (*)(id, SEL, NSURLRequest*, void (^)(NSData*, NSURLResponse*, NSError*)))originalDataTaskWithRequestIMP)(self, _cmd, request, wrappedHandler);
}

// Hook NSURLSession dataTaskWithURL:completionHandler:
static NSURLSessionDataTask* hooked_dataTaskWithURL(id self, SEL _cmd, NSURL *url, void (^completionHandler)(NSData *data, NSURLResponse *response, NSError *error)) {
    NSLog(@"[URLSessionHook] dataTaskWithURL: %@", url);
    
    // 包装原始的 completion handler
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"[URLSessionHook] Response: %ld %@", (long)httpResponse.statusCode, response.URL);
        }
        
        if (error) {
            NSLog(@"[URLSessionHook] Error: %@", error);
        }
        
        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };
    
    // 调用原始方法
    return ((NSURLSessionDataTask* (*)(id, SEL, NSURL*, void (^)(NSData*, NSURLResponse*, NSError*)))originalDataTaskWithURLIMP)(self, _cmd, url, wrappedHandler);
}

+ (void)startMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[URLSessionHook] Starting NSURLSession monitoring...");
        
        Class sessionClass = [NSURLSession class];
        
        // Hook dataTaskWithRequest:completionHandler:
        SEL dataTaskWithRequestSelector = @selector(dataTaskWithRequest:completionHandler:);
        Method dataTaskWithRequestMethod = class_getInstanceMethod(sessionClass, dataTaskWithRequestSelector);
        if (dataTaskWithRequestMethod) {
            originalDataTaskWithRequestIMP = method_setImplementation(dataTaskWithRequestMethod, (IMP)hooked_dataTaskWithRequest);
            NSLog(@"[URLSessionHook] Successfully hooked dataTaskWithRequest:completionHandler:");
        }
        
        // Hook dataTaskWithURL:completionHandler:
        SEL dataTaskWithURLSelector = @selector(dataTaskWithURL:completionHandler:);
        Method dataTaskWithURLMethod = class_getInstanceMethod(sessionClass, dataTaskWithURLSelector);
        if (dataTaskWithURLMethod) {
            originalDataTaskWithURLIMP = method_setImplementation(dataTaskWithURLMethod, (IMP)hooked_dataTaskWithURL);
            NSLog(@"[URLSessionHook] Successfully hooked dataTaskWithURL:completionHandler:");
        }
        
        // 也可以 hook 其他方法，如 downloadTask, uploadTask 等
        [self hookDownloadTasks];
        [self hookUploadTasks];
    });
}

+ (void)hookDownloadTasks {
    Class sessionClass = [NSURLSession class];
    
    // Hook downloadTaskWithRequest:
    SEL downloadTaskSelector = @selector(downloadTaskWithRequest:);
    Method downloadTaskMethod = class_getInstanceMethod(sessionClass, downloadTaskSelector);
    if (downloadTaskMethod) {
        IMP originalIMP = method_getImplementation(downloadTaskMethod);
        IMP hookedIMP = imp_implementationWithBlock(^NSURLSessionDownloadTask*(id self, NSURLRequest *request) {
            NSLog(@"[URLSessionHook] downloadTaskWithRequest: %@ %@", request.HTTPMethod ?: @"GET", request.URL);
            return ((NSURLSessionDownloadTask* (*)(id, SEL, NSURLRequest*))originalIMP)(self, downloadTaskSelector, request);
        });
        method_setImplementation(downloadTaskMethod, hookedIMP);
    }
    
    // Hook downloadTaskWithURL:
    SEL downloadTaskWithURLSelector = @selector(downloadTaskWithURL:);
    Method downloadTaskWithURLMethod = class_getInstanceMethod(sessionClass, downloadTaskWithURLSelector);
    if (downloadTaskWithURLMethod) {
        IMP originalIMP = method_getImplementation(downloadTaskWithURLMethod);
        IMP hookedIMP = imp_implementationWithBlock(^NSURLSessionDownloadTask*(id self, NSURL *url) {
            NSLog(@"[URLSessionHook] downloadTaskWithURL: %@", url);
            return ((NSURLSessionDownloadTask* (*)(id, SEL, NSURL*))originalIMP)(self, downloadTaskWithURLSelector, url);
        });
        method_setImplementation(downloadTaskWithURLMethod, hookedIMP);
    }
}

+ (void)hookUploadTasks {
    Class sessionClass = [NSURLSession class];
    
    // Hook uploadTaskWithRequest:fromData:
    SEL uploadTaskSelector = @selector(uploadTaskWithRequest:fromData:);
    Method uploadTaskMethod = class_getInstanceMethod(sessionClass, uploadTaskSelector);
    if (uploadTaskMethod) {
        IMP originalIMP = method_getImplementation(uploadTaskMethod);
        IMP hookedIMP = imp_implementationWithBlock(^NSURLSessionUploadTask*(id self, NSURLRequest *request, NSData *bodyData) {
            NSLog(@"[URLSessionHook] uploadTaskWithRequest: %@ %@", request.HTTPMethod ?: @"POST", request.URL);
            if (bodyData) {
                NSLog(@"[URLSessionHook] Upload data length: %lu bytes", (unsigned long)bodyData.length);
            }
            return ((NSURLSessionUploadTask* (*)(id, SEL, NSURLRequest*, NSData*))originalIMP)(self, uploadTaskSelector, request, bodyData);
        });
        method_setImplementation(uploadTaskMethod, hookedIMP);
    }
}

+ (void)stopMonitoring {
    // 恢复原始实现（如果需要的话）
    NSLog(@"[URLSessionHook] Stopping NSURLSession monitoring...");
}

@end