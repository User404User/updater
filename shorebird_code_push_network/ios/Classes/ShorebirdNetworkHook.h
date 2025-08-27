//
//  ShorebirdNetworkHook.h
//  shorebird_code_push_network
//

#ifndef ShorebirdNetworkHook_h
#define ShorebirdNetworkHook_h

#include <stdio.h>

// 设置自定义的 API 和 CDN 地址
void shorebird_set_custom_api_host(const char *api_host);
void shorebird_set_custom_cdn_host(const char *cdn_host);

// 获取当前的自定义地址
const char* shorebird_get_custom_api_host(void);
const char* shorebird_get_custom_cdn_host(void);

#endif /* ShorebirdNetworkHook_h */