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
#include <resolv.h>
#include <netinet/tcp.h>

// DNS 相关原始函数指针
static int (*orig_getaddrinfo)(const char *node, const char *service,
                               const struct addrinfo *hints,
                               struct addrinfo **res);
static struct hostent* (*orig_gethostbyname)(const char *name);

// socket 相关函数
static int (*orig_connect)(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

// 存储自定义主机地址映射
typedef struct {
    char *original_host;
    char *redirect_host;
} HostMapping;

#define MAX_HOST_MAPPINGS 10
static HostMapping host_mappings[MAX_HOST_MAPPINGS];
static int host_mapping_count = 0;
static pthread_mutex_t host_mutex = PTHREAD_MUTEX_INITIALIZER;

// 兼容旧接口
static char *custom_api_host = NULL;
static char *custom_cdn_host = NULL;

// Hook 后的 gethostbyname 函数
struct hostent* hooked_gethostbyname(const char *name) {
    if (!name) {
        return orig_gethostbyname(name);
    }
    
    NSLog(@"🌐 [NetworkHook] DNS查询2 (gethostbyname): %s", name);
    
    pthread_mutex_lock(&host_mutex);
    
    const char *target_name = name;
    
    // 检查是否需要重定向 API 域名
    if (strcmp(name, "api.shorebird.dev") == 0 && custom_api_host) {
        target_name = custom_api_host;
        NSLog(@"[NetworkHook] 重定向 api.shorebird.dev -> %s", custom_api_host);
    }
    // 检查是否需要重定向 CDN 域名
    else if (strcmp(name, "cdn.shorebird.cloud") == 0 && custom_cdn_host) {
        target_name = custom_cdn_host;
        NSLog(@"[NetworkHook] 重定向 cdn.shorebird.cloud -> %s", custom_cdn_host);
    }
    
    pthread_mutex_unlock(&host_mutex);
    
    return orig_gethostbyname(target_name);
}

// Hook 后的 getaddrinfo 函数
int my_getaddrinfo(const char *node, const char *service,
                   const struct addrinfo *hints,
                   struct addrinfo **res) {
    if (!node) {
        return orig_getaddrinfo(node, service, hints, res);
    }
    
    // 记录所有 DNS 查询的域名
    NSLog(@"🌐 [NetworkHook] DNS查询1 (getaddrinfo): %s", node);
    
    pthread_mutex_lock(&host_mutex);
    
    const char *target_node = node;
    const char *original_node = node;
    
    // 先检查通用映射表
    for (int i = 0; i < host_mapping_count; i++) {
        if (host_mappings[i].original_host && 
            strcmp(node, host_mappings[i].original_host) == 0) {
            target_node = host_mappings[i].redirect_host;
            NSLog(@"🔄 [NetworkHook] 域名重定向: %s -> %s", node, target_node);
            break;
        }
    }
    
    // 兼容旧的特定域名检查
    if (target_node == node) {
        if (strcmp(node, "api.shorebird.dev") == 0 && custom_api_host) {
            target_node = custom_api_host;
            NSLog(@"[NetworkHook] 重定向 api.shorebird.dev -> %s", custom_api_host);
        }
        else if (strcmp(node, "cdn.shorebird.cloud") == 0 && custom_cdn_host) {
            target_node = custom_cdn_host;
            NSLog(@"[NetworkHook] 重定向 cdn.shorebird.cloud -> %s", custom_cdn_host);
        }
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

// Hook 后的 connect 函数 - 简化版，只在必要时打印
int hooked_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (addr && addr->sa_family == AF_INET) {
        struct sockaddr_in *addr_in = (struct sockaddr_in *)addr;
        int port = ntohs(addr_in->sin_port);
        
        // 只对 HTTP/HTTPS 端口进行日志记录
        if (port == 80 || port == 443 || port == 8080 || port == 8443) {
            char addr_str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(addr_in->sin_addr), addr_str, INET_ADDRSTRLEN);
            
            char host[NI_MAXHOST];
            // 尝试反向查询域名
            if (getnameinfo(addr, addrlen, host, sizeof(host), NULL, 0, NI_NUMERICSERV) == 0) {
                NSLog(@"🔗 [NetworkHook] 连接到: %s:%d", host, port);
            } else {
                NSLog(@"🔗 [NetworkHook] 连接到: %s:%d", addr_str, port);
            }
        }
    }
    
    return orig_connect(sockfd, addr, addrlen);
}

// 在模块加载时自动执行 Hook
__attribute__((constructor))
static void init_hook() {
    NSLog(@"🚀 [ShorebirdNetworkHook] 正在初始化网络 Hook (精简版)...");
    
    struct rebinding rebindings[] = {
        // DNS 查询
        {"getaddrinfo", my_getaddrinfo, (void **)&orig_getaddrinfo},
        {"gethostbyname", hooked_gethostbyname, (void **)&orig_gethostbyname},
        {"connect", hooked_connect, (void **)&orig_connect},
    };
    
    int result = rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));
    
    if (result == 0) {
        NSLog(@"✅ [ShorebirdNetworkHook] 网络 Hook 初始化成功！");
    } else {
        NSLog(@"⚠️ [ShorebirdNetworkHook] 部分 Hook 初始化失败: %d", result);
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

// 添加通用的域名映射
void shorebird_add_host_mapping(const char *original_host, const char *redirect_host) {
    if (!original_host || !redirect_host) return;
    
    pthread_mutex_lock(&host_mutex);
    
    // 先检查是否已存在
    for (int i = 0; i < host_mapping_count; i++) {
        if (host_mappings[i].original_host && 
            strcmp(host_mappings[i].original_host, original_host) == 0) {
            // 更新现有映射
            free(host_mappings[i].redirect_host);
            host_mappings[i].redirect_host = strdup(redirect_host);
            pthread_mutex_unlock(&host_mutex);
            NSLog(@"[NetworkHook] 更新域名映射: %s -> %s", original_host, redirect_host);
            return;
        }
    }
    
    // 添加新映射
    if (host_mapping_count < MAX_HOST_MAPPINGS) {
        host_mappings[host_mapping_count].original_host = strdup(original_host);
        host_mappings[host_mapping_count].redirect_host = strdup(redirect_host);
        host_mapping_count++;
        NSLog(@"[NetworkHook] 添加域名映射: %s -> %s", original_host, redirect_host);
    } else {
        NSLog(@"[NetworkHook] 域名映射表已满，无法添加新映射");
    }
    
    pthread_mutex_unlock(&host_mutex);
}

// 移除域名映射
void shorebird_remove_host_mapping(const char *original_host) {
    if (!original_host) return;
    
    pthread_mutex_lock(&host_mutex);
    
    for (int i = 0; i < host_mapping_count; i++) {
        if (host_mappings[i].original_host && 
            strcmp(host_mappings[i].original_host, original_host) == 0) {
            free(host_mappings[i].original_host);
            free(host_mappings[i].redirect_host);
            
            // 移动后面的元素
            for (int j = i; j < host_mapping_count - 1; j++) {
                host_mappings[j] = host_mappings[j + 1];
            }
            
            host_mapping_count--;
            NSLog(@"[NetworkHook] 移除域名映射: %s", original_host);
            break;
        }
    }
    
    pthread_mutex_unlock(&host_mutex);
}

// 清空所有域名映射
void shorebird_clear_all_host_mappings(void) {
    pthread_mutex_lock(&host_mutex);
    
    for (int i = 0; i < host_mapping_count; i++) {
        free(host_mappings[i].original_host);
        free(host_mappings[i].redirect_host);
    }
    
    host_mapping_count = 0;
    NSLog(@"[NetworkHook] 清空所有域名映射");
    
    pthread_mutex_unlock(&host_mutex);
}