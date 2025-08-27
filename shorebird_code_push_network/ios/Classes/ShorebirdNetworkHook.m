//
//  ShorebirdNetworkHook.m
//  shorebird_code_push_network
//

#import <Foundation/Foundation.h>
#import "fishhook.h"
#include <netdb.h>
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <dlfcn.h>

// 原始函数指针
static int (*orig_getaddrinfo)(const char *node, const char *service,
                               const struct addrinfo *hints,
                               struct addrinfo **res);

// socket 相关函数
static int (*orig_connect)(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
static int (*orig_socket)(int domain, int type, int protocol);
static ssize_t (*orig_send)(int sockfd, const void *buf, size_t len, int flags);
static ssize_t (*orig_recv)(int sockfd, void *buf, size_t len, int flags);
static ssize_t (*orig_sendto)(int sockfd, const void *buf, size_t len, int flags,
                             const struct sockaddr *dest_addr, socklen_t addrlen);
static ssize_t (*orig_recvfrom)(int sockfd, void *buf, size_t len, int flags,
                               struct sockaddr *src_addr, socklen_t *addrlen);

// 高层 API hook
typedef void* (*CFReadStreamCreateWithBytesNoCopy_t)(void *alloc, const void *bytes, long long length, void *bytesDeallocator);
typedef void* (*CFWriteStreamCreateWithBuffer_t)(void *alloc, void *buffer, long long bufferCapacity);

static CFReadStreamCreateWithBytesNoCopy_t orig_CFReadStreamCreateWithBytesNoCopy = NULL;
static CFWriteStreamCreateWithBuffer_t orig_CFWriteStreamCreateWithBuffer = NULL;

// 存储自定义主机地址
static char *custom_api_host = NULL;
static char *custom_cdn_host = NULL;
static pthread_mutex_t host_mutex = PTHREAD_MUTEX_INITIALIZER;

// Hook 后的 getaddrinfo 函数
int my_getaddrinfo(const char *node, const char *service,
                   const struct addrinfo *hints,
                   struct addrinfo **res) {
    if (!node) {
        return orig_getaddrinfo(node, service, hints, res);
    }
    
    pthread_mutex_lock(&host_mutex);
    
    const char *target_node = node;
    
    // 检查是否需要重定向 API 域名
    if (strcmp(node, "api.shorebird.dev") == 0 && custom_api_host) {
        target_node = custom_api_host;
        NSLog(@"[ShorebirdNetworkHook] Redirecting api.shorebird.dev to %s", custom_api_host);
    }
    // 检查是否需要重定向 CDN 域名
    else if (strcmp(node, "cdn.shorebird.cloud") == 0 && custom_cdn_host) {
        target_node = custom_cdn_host;
        NSLog(@"[ShorebirdNetworkHook] Redirecting cdn.shorebird.cloud to %s", custom_cdn_host);
    }
    
    pthread_mutex_unlock(&host_mutex);
    
    // 如果目标是 IP 地址，直接构造 addrinfo
    struct in_addr addr;
    if (inet_pton(AF_INET, target_node, &addr) == 1) {
        struct addrinfo *result = (struct addrinfo *)calloc(1, sizeof(struct addrinfo));
        struct sockaddr_in *sockaddr = (struct sockaddr_in *)calloc(1, sizeof(struct sockaddr_in));
        
        sockaddr->sin_family = AF_INET;
        sockaddr->sin_port = htons(service ? atoi(service) : 0);
        sockaddr->sin_addr = addr;
        
        result->ai_family = AF_INET;
        result->ai_socktype = hints ? hints->ai_socktype : SOCK_STREAM;
        result->ai_protocol = hints ? hints->ai_protocol : 0;
        result->ai_addrlen = sizeof(struct sockaddr_in);
        result->ai_addr = (struct sockaddr *)sockaddr;
        result->ai_canonname = strdup(node);
        result->ai_next = NULL;
        
        *res = result;
        return 0;
    }
    
    // 否则使用原始函数解析
    return orig_getaddrinfo(target_node, service, hints, res);
}

// 打印 socket 地址信息
static void log_socket_address(const char *func_name, const struct sockaddr *addr) {
    if (!addr) return;
    
    char addr_str[INET6_ADDRSTRLEN];
    int port = 0;
    
    if (addr->sa_family == AF_INET) {
        struct sockaddr_in *addr_in = (struct sockaddr_in *)addr;
        inet_ntop(AF_INET, &(addr_in->sin_addr), addr_str, INET_ADDRSTRLEN);
        port = ntohs(addr_in->sin_port);
        NSLog(@"[NetworkHook] %s: IPv4 %s:%d", func_name, addr_str, port);
    } else if (addr->sa_family == AF_INET6) {
        struct sockaddr_in6 *addr_in6 = (struct sockaddr_in6 *)addr;
        inet_ntop(AF_INET6, &(addr_in6->sin6_addr), addr_str, INET6_ADDRSTRLEN);
        port = ntohs(addr_in6->sin6_port);
        NSLog(@"[NetworkHook] %s: IPv6 [%s]:%d", func_name, addr_str, port);
    }
}

// Hook 后的 connect 函数
int hooked_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    log_socket_address("connect", addr);
    return orig_connect(sockfd, addr, addrlen);
}

// Hook 后的 socket 函数
int hooked_socket(int domain, int type, int protocol) {
    int fd = orig_socket(domain, type, protocol);
    
    const char *domain_str = "UNKNOWN";
    const char *type_str = "UNKNOWN";
    
    switch (domain) {
        case AF_INET: domain_str = "AF_INET"; break;
        case AF_INET6: domain_str = "AF_INET6"; break;
        case AF_UNIX: domain_str = "AF_UNIX"; break;
    }
    
    // iOS 不支持 SOCK_NONBLOCK 和 SOCK_CLOEXEC，直接使用 type
    switch (type) {
        case SOCK_STREAM: type_str = "SOCK_STREAM"; break;
        case SOCK_DGRAM: type_str = "SOCK_DGRAM"; break;
        case SOCK_RAW: type_str = "SOCK_RAW"; break;
    }
    
    NSLog(@"[NetworkHook] socket: fd=%d, domain=%s, type=%s, protocol=%d", 
          fd, domain_str, type_str, protocol);
    return fd;
}

// Hook 后的 send 函数
ssize_t hooked_send(int sockfd, const void *buf, size_t len, int flags) {
    ssize_t result = orig_send(sockfd, buf, len, flags);
    NSLog(@"[NetworkHook] send: fd=%d, len=%zu, sent=%zd, flags=%d", 
          sockfd, len, result, flags);
    
    // 打印前 100 字节的数据（如果是文本）
    if (result > 0 && buf) {
        NSData *data = [NSData dataWithBytes:buf length:MIN(result, 100)];
        NSString *preview = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (preview) {
            NSLog(@"[NetworkHook] send data preview: %@...", preview);
        }
    }
    
    return result;
}

// Hook 后的 recv 函数
ssize_t hooked_recv(int sockfd, void *buf, size_t len, int flags) {
    ssize_t result = orig_recv(sockfd, buf, len, flags);
    NSLog(@"[NetworkHook] recv: fd=%d, requested=%zu, received=%zd, flags=%d", 
          sockfd, len, result, flags);
    
    // 打印前 100 字节的数据（如果是文本）
    if (result > 0 && buf) {
        NSData *data = [NSData dataWithBytes:buf length:MIN(result, 100)];
        NSString *preview = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (preview) {
            NSLog(@"[NetworkHook] recv data preview: %@...", preview);
        }
    }
    
    return result;
}

// Hook 后的 sendto 函数
ssize_t hooked_sendto(int sockfd, const void *buf, size_t len, int flags,
                      const struct sockaddr *dest_addr, socklen_t addrlen) {
    log_socket_address("sendto", dest_addr);
    ssize_t result = orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
    NSLog(@"[NetworkHook] sendto: fd=%d, len=%zu, sent=%zd", sockfd, len, result);
    return result;
}

// Hook 后的 recvfrom 函数
ssize_t hooked_recvfrom(int sockfd, void *buf, size_t len, int flags,
                        struct sockaddr *src_addr, socklen_t *addrlen) {
    ssize_t result = orig_recvfrom(sockfd, buf, len, flags, src_addr, addrlen);
    if (result > 0 && src_addr) {
        log_socket_address("recvfrom", src_addr);
    }
    NSLog(@"[NetworkHook] recvfrom: fd=%d, received=%zd", sockfd, result);
    return result;
}

// 在模块加载时自动执行 Hook
__attribute__((constructor))
static void init_hook() {
    NSLog(@"[ShorebirdNetworkHook] Initializing network hooks...");
    
    struct rebinding rebindings[] = {
        {"getaddrinfo", my_getaddrinfo, (void **)&orig_getaddrinfo},
        {"connect", hooked_connect, (void **)&orig_connect},
        {"socket", hooked_socket, (void **)&orig_socket},
        {"send", hooked_send, (void **)&orig_send},
        {"recv", hooked_recv, (void **)&orig_recv},
        {"sendto", hooked_sendto, (void **)&orig_sendto},
        {"recvfrom", hooked_recvfrom, (void **)&orig_recvfrom},
    };
    
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    
    if (result == 0) {
        NSLog(@"[ShorebirdNetworkHook] Network hooks initialized successfully");
    } else {
        NSLog(@"[ShorebirdNetworkHook] Failed to initialize some hooks: %d", result);
    }
}

// 设置自定义 API 主机
void shorebird_set_custom_api_host(const char *api_host) {
    pthread_mutex_lock(&host_mutex);
    
    if (custom_api_host) {
        free(custom_api_host);
        custom_api_host = NULL;
    }
    
    if (api_host) {
        custom_api_host = strdup(api_host);
    }
    
    pthread_mutex_unlock(&host_mutex);
    NSLog(@"[ShorebirdNetworkHook] Custom API host set to: %s", api_host ?: "nil");
}

// 设置自定义 CDN 主机
void shorebird_set_custom_cdn_host(const char *cdn_host) {
    pthread_mutex_lock(&host_mutex);
    
    if (custom_cdn_host) {
        free(custom_cdn_host);
        custom_cdn_host = NULL;
    }
    
    if (cdn_host) {
        custom_cdn_host = strdup(cdn_host);
    }
    
    pthread_mutex_unlock(&host_mutex);
    NSLog(@"[ShorebirdNetworkHook] Custom CDN host set to: %s", cdn_host ?: "nil");
}

// 获取当前的自定义 API 主机
const char* shorebird_get_custom_api_host(void) {
    pthread_mutex_lock(&host_mutex);
    const char *host = custom_api_host;
    pthread_mutex_unlock(&host_mutex);
    return host;
}

// 获取当前的自定义 CDN 主机
const char* shorebird_get_custom_cdn_host(void) {
    pthread_mutex_lock(&host_mutex);
    const char *host = custom_cdn_host;
    pthread_mutex_unlock(&host_mutex);
    return host;
}