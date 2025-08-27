//
//  ShorebirdCFNetworkHook.m
//  shorebird_code_push_network
//

#import <Foundation/Foundation.h>
#import "fishhook.h"
#import <CFNetwork/CFNetwork.h>
#import <dlfcn.h>

// CFNetwork 函数指针类型
typedef CFHTTPMessageRef (*CFHTTPMessageCreateRequest_t)(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion);
typedef Boolean (*CFHTTPMessageSetHeaderFieldValue_t)(CFHTTPMessageRef message, CFStringRef headerField, CFStringRef value);
typedef Boolean (*CFHTTPMessageSetBody_t)(CFHTTPMessageRef message, CFDataRef bodyData);
typedef CFReadStreamRef (*CFReadStreamCreateForHTTPRequest_t)(CFAllocatorRef alloc, CFHTTPMessageRef request);

// 原始函数指针
static CFHTTPMessageCreateRequest_t orig_CFHTTPMessageCreateRequest = NULL;
static CFHTTPMessageSetHeaderFieldValue_t orig_CFHTTPMessageSetHeaderFieldValue = NULL;
static CFHTTPMessageSetBody_t orig_CFHTTPMessageSetBody = NULL;
static CFReadStreamCreateForHTTPRequest_t orig_CFReadStreamCreateForHTTPRequest = NULL;

// CFStream 相关
typedef CFReadStreamRef (*CFReadStreamCreateWithBytesNoCopy_t)(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
typedef void (*CFReadStreamOpen_t)(CFReadStreamRef stream);
typedef CFIndex (*CFReadStreamRead_t)(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);

static CFReadStreamCreateWithBytesNoCopy_t orig_CFReadStreamCreateWithBytesNoCopy = NULL;
static CFReadStreamOpen_t orig_CFReadStreamOpen = NULL;
static CFReadStreamRead_t orig_CFReadStreamRead = NULL;

// Hook 后的 CFHTTPMessageCreateRequest
CFHTTPMessageRef hooked_CFHTTPMessageCreateRequest(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion) {
    NSString *method = (__bridge NSString *)requestMethod;
    NSURL *nsURL = (__bridge NSURL *)url;
    NSString *version = (__bridge NSString *)httpVersion;
    
    NSLog(@"[CFNetworkHook] CFHTTPMessageCreateRequest: %@ %@ %@", method, nsURL, version);
    
    return orig_CFHTTPMessageCreateRequest(alloc, requestMethod, url, httpVersion);
}

// Hook 后的 CFHTTPMessageSetHeaderFieldValue
Boolean hooked_CFHTTPMessageSetHeaderFieldValue(CFHTTPMessageRef message, CFStringRef headerField, CFStringRef value) {
    NSString *field = (__bridge NSString *)headerField;
    NSString *val = (__bridge NSString *)value;
    
    NSLog(@"[CFNetworkHook] CFHTTPMessageSetHeaderFieldValue: %@ = %@", field, val);
    
    return orig_CFHTTPMessageSetHeaderFieldValue(message, headerField, value);
}

// Hook 后的 CFHTTPMessageSetBody
Boolean hooked_CFHTTPMessageSetBody(CFHTTPMessageRef message, CFDataRef bodyData) {
    NSData *data = (__bridge NSData *)bodyData;
    NSLog(@"[CFNetworkHook] CFHTTPMessageSetBody: %lu bytes", (unsigned long)data.length);
    
    if (data.length > 0 && data.length < 1000) {
        NSString *bodyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (bodyString) {
            NSLog(@"[CFNetworkHook] Body content: %@", bodyString);
        }
    }
    
    return orig_CFHTTPMessageSetBody(message, bodyData);
}

// Hook 后的 CFReadStreamCreateForHTTPRequest
CFReadStreamRef hooked_CFReadStreamCreateForHTTPRequest(CFAllocatorRef alloc, CFHTTPMessageRef request) {
    NSLog(@"[CFNetworkHook] CFReadStreamCreateForHTTPRequest");
    
    // 尝试获取请求信息
    CFURLRef url = CFHTTPMessageCopyRequestURL(request);
    if (url) {
        NSURL *nsURL = (__bridge NSURL *)url;
        NSLog(@"[CFNetworkHook] Request URL: %@", nsURL);
        CFRelease(url);
    }
    
    CFStringRef method = CFHTTPMessageCopyRequestMethod(request);
    if (method) {
        NSString *nsMethod = (__bridge NSString *)method;
        NSLog(@"[CFNetworkHook] Request Method: %@", nsMethod);
        CFRelease(method);
    }
    
    return orig_CFReadStreamCreateForHTTPRequest(alloc, request);
}

// Hook 后的 CFReadStreamOpen
void hooked_CFReadStreamOpen(CFReadStreamRef stream) {
    NSLog(@"[CFNetworkHook] CFReadStreamOpen: %p", stream);
    orig_CFReadStreamOpen(stream);
}

// Hook 后的 CFReadStreamRead
CFIndex hooked_CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength) {
    CFIndex bytesRead = orig_CFReadStreamRead(stream, buffer, bufferLength);
    
    if (bytesRead > 0) {
        NSLog(@"[CFNetworkHook] CFReadStreamRead: Read %ld bytes", bytesRead);
        
        // 尝试打印数据预览（如果是文本）
        NSData *data = [NSData dataWithBytes:buffer length:MIN(bytesRead, 200)];
        NSString *preview = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (preview) {
            NSLog(@"[CFNetworkHook] Data preview: %@...", preview);
        }
    }
    
    return bytesRead;
}

// 初始化 CFNetwork hooks
void shorebird_init_cfnetwork_hooks(void) {
    NSLog(@"[CFNetworkHook] Initializing CFNetwork hooks...");
    
    struct rebinding rebindings[] = {
        {"CFHTTPMessageCreateRequest", hooked_CFHTTPMessageCreateRequest, (void **)&orig_CFHTTPMessageCreateRequest},
        {"CFHTTPMessageSetHeaderFieldValue", hooked_CFHTTPMessageSetHeaderFieldValue, (void **)&orig_CFHTTPMessageSetHeaderFieldValue},
        {"CFHTTPMessageSetBody", hooked_CFHTTPMessageSetBody, (void **)&orig_CFHTTPMessageSetBody},
        {"CFReadStreamCreateForHTTPRequest", hooked_CFReadStreamCreateForHTTPRequest, (void **)&orig_CFReadStreamCreateForHTTPRequest},
        {"CFReadStreamOpen", hooked_CFReadStreamOpen, (void **)&orig_CFReadStreamOpen},
        {"CFReadStreamRead", hooked_CFReadStreamRead, (void **)&orig_CFReadStreamRead},
    };
    
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    
    if (result == 0) {
        NSLog(@"[CFNetworkHook] CFNetwork hooks initialized successfully");
    } else {
        NSLog(@"[CFNetworkHook] Some CFNetwork hooks failed: %d", result);
    }
}

// 在模块加载时自动执行
__attribute__((constructor))
static void init_cfnetwork_hook() {
    shorebird_init_cfnetwork_hooks();
}