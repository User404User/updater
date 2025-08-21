import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';

void main() async {
  print('Testing Shorebird Network Library...\n');
  
  try {
    // Create instance which triggers library loading
    final updater = UpdaterNetwork();
    print('✅ Library loaded successfully\n');
    
    // Test currentPatchNumber
    print('Testing currentPatchNumber...');
    final currentPatch = updater.currentPatchNumber();
    print('✅ Current patch number: $currentPatch\n');
    
    // Test nextPatchNumber  
    print('Testing nextPatchNumber...');
    final nextPatch = updater.nextPatchNumber();
    print('✅ Next patch number: $nextPatch\n');
    
    // Test updateBaseUrl
    print('Testing updateBaseUrl...');
    final urlUpdated = updater.updateBaseUrl('https://api.example.com');
    print('✅ Base URL updated: $urlUpdated\n');
    
    print('All tests passed! Network library is working correctly.');
    
  } catch (e) {
    print('❌ Error: $e');
    print('\nStack trace:');
    print(StackTrace.current);
  }
}