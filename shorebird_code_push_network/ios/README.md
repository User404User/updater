# iOS 网络 Hook 实现

本目录包含了 iOS 平台的网络拦截实现，用于监控和修改网络请求。

## 实现架构

### 1. 自动初始化
- 所有 Hook 通过 `__attribute__((constructor))` 在库加载时自动启动
- 无需手动调用初始化方法
- `ShorebirdNetworkHookManager` 确保所有 Hook 正确初始化

### 2. Hook 层级

#### 底层 Socket Hook (ShorebirdNetworkHook.m)
- **getaddrinfo**: DNS 解析拦截，支持域名重定向
- **connect**: TCP 连接拦截
- **socket**: Socket 创建拦截  
- **send/recv**: 数据发送接收拦截
- **sendto/recvfrom**: UDP 数据传输拦截

#### NSURLSession Hook (ShorebirdURLSessionHook.m)
- **dataTaskWithRequest**: HTTP 请求拦截
- **dataTaskWithURL**: URL 请求拦截
- **downloadTask**: 下载任务拦截
- **uploadTask**: 上传任务拦截

#### CFNetwork Hook (ShorebirdCFNetworkHook.m)
- **CFHTTPMessageCreateRequest**: HTTP 请求创建
- **CFHTTPMessageSetHeaderFieldValue**: 请求头设置
- **CFHTTPMessageSetBody**: 请求体设置
- **CFReadStreamCreateForHTTPRequest**: 请求流创建
- **CFReadStreamOpen/Read**: 流操作拦截

### 3. DNS 重定向功能

支持将 Shorebird 官方域名重定向到自定义服务器：
- `api.shorebird.dev` → 自定义 API 服务器
- `cdn.shorebird.cloud` → 自定义 CDN 服务器

通过 Flutter 方法通道更新：
```dart
// 更新 API 服务器
ShorebirdCodePushNetwork.updateBaseUrl('https://my-api.com');

// 更新 CDN 服务器  
ShorebirdCodePushNetwork.updateDownloadUrl('https://my-cdn.com');
```

### 4. 日志输出

所有网络活动都会输出详细日志：
- 请求 URL、方法、Headers、Body
- 响应状态码、Headers、数据预览
- Socket 连接信息
- DNS 解析结果

### 5. 文件说明

- `fishhook.h/c` - Facebook 的运行时 Hook 库
- `ShorebirdNetworkHook.h/m` - 底层 Socket 和 DNS Hook
- `ShorebirdURLSessionHook.h/m` - NSURLSession 拦截
- `ShorebirdCFNetworkHook.h/m` - CFNetwork 拦截
- `ShorebirdNetworkHookManager.h/m` - Hook 管理器
- `ShorebirdCodePushNetworkPlugin.h/m` - Flutter 插件接口

## 使用说明

1. 库会在加载时自动启动所有 Hook
2. 通过 Xcode Console 或设备日志查看网络请求
3. 使用 Flutter API 动态更新域名配置

## 注意事项

- 所有 Hook 实现都是线程安全的
- DNS 重定向只影响 Shorebird 相关域名
- 其他网络请求正常通过，不受影响