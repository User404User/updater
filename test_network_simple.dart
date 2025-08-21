import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

// 简单的测试脚本，直接测试库加载和baseUrl设置
void main() {
  print('Testing Shorebird Network Library...\n');
  
  try {
    // 尝试加载库
    ffi.DynamicLibrary? lib;
    
    if (Platform.isAndroid) {
      print('Platform: Android');
      try {
        lib = ffi.DynamicLibrary.open('libshorebird_updater_network.so');
        print('✅ Loaded libshorebird_updater_network.so');
      } catch (e) {
        print('❌ Failed to load libshorebird_updater_network.so: $e');
        return;
      }
    } else if (Platform.isIOS) {
      print('Platform: iOS');
      lib = ffi.DynamicLibrary.process();
      print('✅ Using process symbols');
    } else {
      print('Unsupported platform');
      return;
    }
    
    // 测试 updateBaseUrl 函数
    print('\nTesting updateBaseUrl function...');
    
    try {
      // 查找函数
      final funcName = Platform.isIOS ? 'shorebird_update_base_url_net' : 'shorebird_update_base_url';
      print('Looking for function: $funcName');
      
      final updateBaseUrlPtr = lib.lookup<ffi.NativeFunction<ffi.Bool Function(ffi.Pointer<ffi.Char>)>>(funcName);
      final updateBaseUrl = updateBaseUrlPtr.asFunction<bool Function(ffi.Pointer<ffi.Char>)>();
      
      print('✅ Found function: $funcName');
      
      // 测试设置URL
      final testUrl = 'https://example.com';
      final urlPtr = testUrl.toNativeUtf8().cast<ffi.Char>();
      
      print('\nCalling updateBaseUrl with: $testUrl');
      final result = updateBaseUrl(urlPtr);
      
      print('Result: $result');
      
      if (result) {
        print('✅ SUCCESS! updateBaseUrl returned true - Network library is working correctly!');
      } else {
        print('❌ FAILED! updateBaseUrl returned false - Something is wrong');
      }
      
      // 释放内存
      malloc.free(urlPtr);
      
    } catch (e) {
      print('❌ Error calling function: $e');
    }
    
  } catch (e) {
    print('❌ General error: $e');
  }
}