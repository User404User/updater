#include <jni.h>
#include <android/log.h>
#include <dlfcn.h>

#define TAG "ShorebirdNetworkJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

extern "C" {

// 在库加载时自动执行
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    LOGI("ShorebirdNetworkJNI: JNI_OnLoad called");
    
    // 尝试加载 shorebird_updater_network 库
    void* handle = dlopen("libshorebird_updater_network.so", RTLD_NOW | RTLD_GLOBAL);
    if (handle) {
        LOGI("Successfully loaded libshorebird_updater_network.so via dlopen");
        
        // 验证一些关键符号是否存在
        void* symbol = dlsym(handle, "shorebird_current_boot_patch_number");
        if (symbol) {
            LOGI("Verified symbol: shorebird_current_boot_patch_number");
        } else {
            LOGE("Symbol not found: shorebird_current_boot_patch_number");
        }
        
        // 不关闭句柄，保持库加载状态
        // dlclose(handle);
    } else {
        const char* error = dlerror();
        LOGE("Failed to load libshorebird_updater_network.so: %s", error ? error : "Unknown error");
    }
    
    return JNI_VERSION_1_6;
}

// 库卸载时执行
JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved) {
    LOGI("ShorebirdNetworkJNI: JNI_OnUnload called");
}

// 提供一个测试函数来验证库是否正确加载
JNIEXPORT jboolean JNICALL
Java_dev_shorebird_code_1push_1network_ShorebirdCodePushNetworkPlugin_00024Companion_nativeIsLibraryLoaded(
    JNIEnv *env, jobject /* this */) {
    
    void* handle = dlopen("libshorebird_updater_network.so", RTLD_NOLOAD);
    if (handle) {
        LOGI("Native library is loaded and accessible");
        dlclose(handle);
        return JNI_TRUE;
    } else {
        LOGE("Native library is not loaded");
        return JNI_FALSE;
    }
}

}  // extern "C"