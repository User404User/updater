cmake_minimum_required(VERSION 3.4.1)

# 设置项目名称
project(shorebird_code_push_network)

# 添加预构建的共享库
add_library(shorebird_updater_network SHARED IMPORTED)

# 根据不同的 ABI 设置库路径
if(${ANDROID_ABI} STREQUAL "arm64-v8a")
    set_target_properties(shorebird_updater_network PROPERTIES
        IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/arm64-v8a/libshorebird_updater_network.so)
elseif(${ANDROID_ABI} STREQUAL "armeabi-v7a")
    set_target_properties(shorebird_updater_network PROPERTIES
        IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/armeabi-v7a/libshorebird_updater_network.so)
elseif(${ANDROID_ABI} STREQUAL "x86_64")
    set_target_properties(shorebird_updater_network PROPERTIES
        IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/x86_64/libshorebird_updater_network.so)
elseif(${ANDROID_ABI} STREQUAL "x86")
    set_target_properties(shorebird_updater_network PROPERTIES
        IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/x86/libshorebird_updater_network.so)
endif()

# 创建一个简单的 JNI 包装器库
add_library(shorebird_network_jni SHARED
    shorebird_network_jni.cpp
)

# 链接预构建的库
target_link_libraries(shorebird_network_jni
    shorebird_updater_network
    android
    log
)