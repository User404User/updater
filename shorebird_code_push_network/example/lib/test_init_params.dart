import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';
import 'package:yaml/yaml.dart';

/// This file demonstrates how the official Shorebird updater gets its initialization parameters.
/// 
/// In the official Shorebird implementation, these parameters are obtained as follows:
/// 
/// 1. app_id: Comes from shorebird.yaml which is embedded in the app bundle
/// 2. release_version: Passed from the Flutter engine based on the version from pubspec.yaml
/// 3. app_storage_dir: Platform-specific app documents directory
/// 4. code_cache_dir: Platform-specific app cache directory
/// 5. original_libapp_paths: Paths to the original AOT libraries (libapp.so on Android)
class InitParamsDemo extends StatefulWidget {
  const InitParamsDemo({super.key});

  @override
  State<InitParamsDemo> createState() => _InitParamsDemoState();
}

class _InitParamsDemoState extends State<InitParamsDemo> {
  final StringBuffer _output = StringBuffer();
  
  @override
  void initState() {
    super.initState();
    _gatherInitializationParameters();
  }

  Future<void> _gatherInitializationParameters() async {
    _output.writeln('=== Shorebird Updater Initialization Parameters ===\n');
    
    try {
      // 1. Get app_id from shorebird.yaml
      await _getAppIdFromYaml();
      
      // 2. Get release_version (this would come from the Flutter engine)
      await _getReleaseVersion();
      
      // 3. Get app_storage_dir
      await _getAppStorageDir();
      
      // 4. Get code_cache_dir
      await _getCodeCacheDir();
      
      // 5. Get original_libapp_paths
      await _getOriginalLibappPaths();
      
      // 6. Show how these would be passed to shorebird_init
      _showInitializationFlow();
      
    } catch (e) {
      _output.writeln('Error gathering parameters: $e');
    }
    
    setState(() {});
  }

  Future<void> _getAppIdFromYaml() async {
    _output.writeln('1. APP_ID from shorebird.yaml:');
    _output.writeln('   Location: assets/shorebird.yaml (embedded in app bundle)');
    
    try {
      // In a real app, shorebird.yaml is embedded as an asset
      final yamlString = await rootBundle.loadString('shorebird.yaml');
      final yaml = loadYaml(yamlString) as Map;
      final appId = yaml['app_id'];
      
      _output.writeln('   ✅ app_id: $appId');
      _output.writeln('   Full YAML content:');
      _output.writeln('   ${yamlString.split('\n').map((line) => '      $line').join('\n')}');
    } catch (e) {
      _output.writeln('   ❌ Could not load shorebird.yaml: $e');
      _output.writeln('   Note: In production, this file is embedded during "shorebird release"');
    }
    _output.writeln();
  }

  Future<void> _getReleaseVersion() async {
    _output.writeln('2. RELEASE_VERSION:');
    _output.writeln('   Source: Flutter engine passes this from pubspec.yaml version');
    
    // In the actual implementation, this comes from the Flutter engine
    // For demonstration, we'll show what it would look like
    const exampleVersion = '1.0.0+1';
    _output.writeln('   ✅ release_version: $exampleVersion');
    _output.writeln('   Note: In real usage, the Flutter engine provides this value');
    _output.writeln('         based on the version field in pubspec.yaml');
    _output.writeln();
  }

  Future<void> _getAppStorageDir() async {
    _output.writeln('3. APP_STORAGE_DIR:');
    _output.writeln('   Purpose: Persistent storage for updater state between app releases');
    
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      _output.writeln('   ✅ app_storage_dir: ${appDocDir.path}');
      
      if (Platform.isAndroid) {
        _output.writeln('   Android: getFilesDir() -> ${appDocDir.path}');
      } else if (Platform.isIOS) {
        _output.writeln('   iOS: NSDocumentDirectory -> ${appDocDir.path}');
      }
    } catch (e) {
      _output.writeln('   ❌ Error getting app storage dir: $e');
    }
    _output.writeln();
  }

  Future<void> _getCodeCacheDir() async {
    _output.writeln('4. CODE_CACHE_DIR:');
    _output.writeln('   Purpose: Temporary storage for downloaded patches');
    
    try {
      final Directory tempDir = await getTemporaryDirectory();
      _output.writeln('   ✅ code_cache_dir: ${tempDir.path}');
      
      if (Platform.isAndroid) {
        _output.writeln('   Android: getCacheDir() -> ${tempDir.path}');
      } else if (Platform.isIOS) {
        _output.writeln('   iOS: NSCachesDirectory -> ${tempDir.path}');
      }
      
      // Show the downloads subdirectory that will be created
      final downloadsPath = '${tempDir.path}/downloads';
      _output.writeln('   Downloads will be stored in: $downloadsPath');
    } catch (e) {
      _output.writeln('   ❌ Error getting code cache dir: $e');
    }
    _output.writeln();
  }

  Future<void> _getOriginalLibappPaths() async {
    _output.writeln('5. ORIGINAL_LIBAPP_PATHS:');
    _output.writeln('   Purpose: Paths to the original AOT compiled Dart code');
    
    if (Platform.isAndroid) {
      _output.writeln('   Android paths (provided by Flutter engine):');
      _output.writeln('   - /data/app/<package>/base.apk!/lib/<arch>/libapp.so');
      _output.writeln('   - Architecture-specific: arm64-v8a, armeabi-v7a, x86, x86_64');
      _output.writeln('   Example: ["/data/app/com.example.app/base.apk!/lib/arm64-v8a/libapp.so"]');
    } else if (Platform.isIOS) {
      _output.writeln('   iOS paths (provided by Flutter engine):');
      _output.writeln('   - App.framework/App (inside the app bundle)');
      _output.writeln('   Example: ["<app_bundle>/Frameworks/App.framework/App"]');
    }
    
    _output.writeln('   Note: These paths are provided by the Flutter engine during initialization');
    _output.writeln();
  }

  void _showInitializationFlow() {
    _output.writeln('=== INITIALIZATION FLOW ===\n');
    _output.writeln('The Flutter engine calls shorebird_init with these parameters:\n');
    
    _output.writeln('```c');
    _output.writeln('// In the Flutter engine (C++)');
    _output.writeln('AppParameters params = {');
    _output.writeln('  .release_version = "1.0.0+1",  // from pubspec.yaml');
    _output.writeln('  .original_libapp_paths = libapp_paths,  // platform-specific');
    _output.writeln('  .original_libapp_paths_size = libapp_paths_count,');
    _output.writeln('  .app_storage_dir = "/path/to/documents",  // getApplicationDocumentsDirectory()');
    _output.writeln('  .code_cache_dir = "/path/to/cache",  // getTemporaryDirectory()');
    _output.writeln('};');
    _output.writeln('');
    _output.writeln('FileCallbacks callbacks = { ... };  // File access callbacks');
    _output.writeln('const char* yaml_content = "...";  // Content of shorebird.yaml');
    _output.writeln('');
    _output.writeln('bool success = shorebird_init(&params, callbacks, yaml_content);');
    _output.writeln('```\n');
    
    _output.writeln('The updater then:');
    _output.writeln('1. Parses the YAML to get app_id, channel, auto_update settings');
    _output.writeln('2. Creates storage directories if needed');
    _output.writeln('3. Loads or creates updater state');
    _output.writeln('4. Configures the network client with base_url');
    _output.writeln('5. Sets up the patch management system');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shorebird Init Parameters'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Initialization Parameters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This demonstrates how the official Shorebird updater obtains its initialization parameters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  _output.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _output.clear();
                });
                _gatherInitializationParameters();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Parameters'),
            ),
          ],
        ),
      ),
    );
  }
}

// Add this to main.dart to navigate to this screen:
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => const InitParamsDemo()),
// );