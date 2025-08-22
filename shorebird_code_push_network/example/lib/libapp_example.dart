import 'package:flutter/material.dart';
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';

/// Example showing how to properly initialize the network updater with libapp paths
class LibappExample extends StatefulWidget {
  const LibappExample({super.key});

  @override
  State<LibappExample> createState() => _LibappExampleState();
}

class _LibappExampleState extends State<LibappExample> {
  String _status = 'Not initialized';
  List<String>? _libappPaths;
  String? _architecture;

  @override
  void initState() {
    super.initState();
    _initializeUpdater();
  }

  Future<void> _initializeUpdater() async {
    setState(() => _status = 'Initializing...');

    try {
      // First, get the libapp paths
      debugPrint('Getting libapp paths...');
      _libappPaths = await LibappPathHelper.getLibappPaths();
      _architecture = await LibappPathHelper.getArchLibraryDir();
      
      debugPrint('Libapp paths: $_libappPaths');
      debugPrint('Architecture: $_architecture');

      // Initialize the network updater with proper configuration
      final config = NetworkUpdaterConfig(
        appId: 'your-app-id',
        releaseVersion: '1.0.0+1',
        channel: 'stable',
        autoUpdate: false,
        baseUrl: 'https://api.shorebird.dev',
        // Pass the libapp paths we got from the native platform
        originalLibappPaths: _libappPaths,
      );

      final success = await NetworkUpdaterInitializer.initialize(config);
      
      setState(() {
        _status = success ? 'Initialized successfully' : 'Failed to initialize';
      });

      if (success) {
        // Now you can use the updater
        final updater = UpdaterNetwork();
        
        // Get current patch number
        final patchNumber = updater.currentPatchNumber();
        debugPrint('Current patch number: $patchNumber');
        
        // Check for updates
        final hasUpdate = updater.checkForDownloadableUpdate();
        debugPrint('Update available: $hasUpdate');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
      debugPrint('Error initializing updater: $e');
    }
  }

  /// Example of manually providing libapp paths for testing
  /// This is useful when you have extracted an APK
  Future<void> _initializeWithManualPaths() async {
    setState(() => _status = 'Initializing with manual paths...');

    try {
      // For testing with extracted APK
      const extractedApkPath = '/path/to/extracted/apk';
      
      final manualPaths = LibappPathHelper.getManualLibappPaths(
        basePath: extractedApkPath,
        architecture: 'arm64-v8a', // or get from device
      );

      debugPrint('Manual libapp paths: $manualPaths');

      final config = NetworkUpdaterConfig(
        appId: 'your-app-id',
        releaseVersion: '1.0.0+1',
        channel: 'stable',
        autoUpdate: false,
        originalLibappPaths: manualPaths,
      );

      final success = await NetworkUpdaterInitializer.initialize(config);
      
      setState(() {
        _status = success ? 'Initialized with manual paths' : 'Failed with manual paths';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libapp Path Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            
            if (_libappPaths != null) ...[
              Text('Architecture: $_architecture'),
              const Text('Libapp paths:'),
              ..._libappPaths!.map((path) => Text('  • $path')),
            ],
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _initializeUpdater,
              child: const Text('Initialize with Auto Paths'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _initializeWithManualPaths,
              child: const Text('Initialize with Manual Paths'),
            ),
            
            const SizedBox(height: 24),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to use libapp paths:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. For production: Use LibappPathHelper.getLibappPaths()'),
                    Text('2. For testing with extracted APK: Use getManualLibappPaths()'),
                    Text('3. Path format for Android: /path/to/lib/arm64-v8a/libapp.so'),
                    Text('4. Path format for iOS: /path/to/App.framework/App'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Usage in your app:
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Get libapp paths from the platform
///   final libappPaths = await LibappPathHelper.getLibappPaths();
///   
///   // Initialize with the paths
///   final config = NetworkUpdaterConfig(
///     appId: 'your-app-id',
///     releaseVersion: '1.0.0+1',
///     originalLibappPaths: libappPaths,
///     // ... other config
///   );
///   
///   await NetworkUpdater.initialize(config);
///   
///   runApp(MyApp());
/// }
/// ```