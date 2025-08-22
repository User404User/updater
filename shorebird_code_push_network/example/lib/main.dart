import 'package:flutter/material.dart';
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';
import 'test_init_params.dart';

// 全局变量存储测试结果
String testResult = 'Testing...';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize network updater with configuration
  await initializeNetworkUpdater();
  
  runApp(const MyApp());
}

Future<void> initializeNetworkUpdater() async {
  final buffer = StringBuffer();
  buffer.writeln('🔍 Initializing Shorebird Network Library...');
  
  try {
    // Create configuration for network updater
    const config = NetworkUpdaterConfig(
      appId: 'test-network-app-id',
      releaseVersion: '1.0.0+1',
      channel: 'stable',
      autoUpdate: false,
      baseUrl: 'https://api.shorebird.dev',
    );
    
    buffer.writeln('📱 Configuration:');
    buffer.writeln('   App ID: ${config.appId}');
    buffer.writeln('   Release Version: ${config.releaseVersion}');
    buffer.writeln('   Channel: ${config.channel}');
    buffer.writeln('   Base URL: ${config.baseUrl}');
    
    // Initialize and create updater instance
    final updater = await UpdaterNetwork.createAndInitialize(config);
    
    if (updater != null) {
      buffer.writeln('\n✅ Network library initialized successfully!');
      
      // Test functions
      buffer.writeln('\n🧪 Testing library functions...');
      
      // Test updateBaseUrl
      final testUrl = 'https://test.example.com';
      final result = updater.updateBaseUrl(testUrl);
      buffer.writeln('UpdateBaseUrl result: $result');
      
      // Get current patch
      final currentPatch = updater.currentPatchNumber();
      buffer.writeln('Current patch: $currentPatch');
      
      // Get app info
      buffer.writeln('App ID from library: ${updater.getAppId()}');
      buffer.writeln('Release version from library: ${updater.getReleaseVersion()}');
      
    } else {
      buffer.writeln('❌ Failed to initialize network library');
    }
    
  } catch (e) {
    buffer.writeln('❌ Error during initialization: $e');
    buffer.writeln('   Stack trace: ${StackTrace.current}');
  }
  
  testResult = buffer.toString();
  print(testResult); // 打印到控制台
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorebird Network Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  UpdaterNetwork? _updater;
  var _currentTrack = UpdateTrack.stable;
  var _isCheckingForUpdates = false;
  int? _currentPatchNumber;
  int? _nextPatchNumber;
  bool _libraryLoaded = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    
    // 尝试创建 UpdaterNetwork 实例，这会立即触发库加载
    _initializeUpdater();
  }

  Future<void> _initializeUpdater() async {
    debugPrint('Initializing UpdaterNetwork with configuration...');
    
    try {
      // 使用配置初始化
      const config = NetworkUpdaterConfig(
        appId: 'example-app-id',
        releaseVersion: '1.0.0+1',
        channel: 'stable',
        autoUpdate: false,
        // 可选：设置自定义 API 和下载 URL
        // baseUrl: 'https://api.example.com',
        // downloadUrl: 'https://download.example.com',
      );
      
      _updater = await UpdaterNetwork.createAndInitialize(config);
      
      if (_updater != null) {
        _libraryLoaded = true;
        
        // 读取当前补丁信息
        _currentPatchNumber = _updater!.currentPatchNumber();
        _nextPatchNumber = _updater!.nextPatchNumber();
        debugPrint('UpdaterNetwork initialized successfully');
        debugPrint('Current patch: $_currentPatchNumber, Next patch: $_nextPatchNumber');
      } else {
        _libraryLoaded = false;
        _loadError = 'Failed to initialize network updater';
      }
      
    } catch (error) {
      _libraryLoaded = false;
      _loadError = error.toString();
      debugPrint('Failed to initialize UpdaterNetwork: $error');
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _testUpdateBaseUrl() {
    if (_updater == null) {
      setState(() {
        testResult = '❌ Updater not initialized';
      });
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('🧪 Testing Network Library at ${DateTime.now()}...\n');
    
    try {
      // 获取 app_id 和 release_version
      buffer.writeln('📱 Library Configuration:');
      buffer.writeln('App ID: ${_updater!.getAppId()}');
      buffer.writeln('Release Version: ${_updater!.getReleaseVersion()}');
      buffer.writeln('');
      
      // 测试多个URL
      buffer.writeln('🌐 Testing updateBaseUrl:');
      final testUrls = [
        'https://test.example.com',
        'https://api.shorebird.dev',
        'https://google.com',
      ];
      
      for (final url in testUrls) {
        buffer.writeln('Testing URL: $url');
        final result = _updater!.updateBaseUrl(url);
        
        if (result) {
          buffer.writeln('✅ SUCCESS - returned TRUE');
        } else {
          buffer.writeln('❌ FAILED - returned FALSE');
        }
        buffer.writeln('');
      }
      
      buffer.writeln('Test completed!');
      
    } catch (e) {
      buffer.writeln('❌ Error during test: $e');
    }
    
    setState(() {
      testResult = buffer.toString();
    });
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingForUpdates || _updater == null || !_libraryLoaded) {
      debugPrint('Cannot check for update: library not loaded or updater not initialized');
      return;
    }

    try {
      setState(() => _isCheckingForUpdates = true);
      // Check if there's an update available.
      final isAvailable = _updater!.checkForDownloadableUpdate(track: _currentTrack);
      if (!mounted) return;
      
      if (isAvailable) {
        _showUpdateAvailableBanner();
      } else {
        _showNoUpdateAvailableBanner();
      }
    } catch (error) {
      // If an error occurs, we log it for now.
      debugPrint('Error checking for update: $error');
      _showErrorBanner(error);
    } finally {
      setState(() => _isCheckingForUpdates = false);
    }
  }

  void _showDownloadingBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        const MaterialBanner(
          content: Text('Downloading...'),
          actions: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      );
  }

  void _showUpdateAvailableBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(
            'Update available for the ${_currentTrack.name} track.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                await _downloadUpdate();
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
  }

  void _showNoUpdateAvailableBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(
            'No update available on the ${_currentTrack.name} track.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
  }

  void _showRestartBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: const Text('A new patch is ready! Please restart your app.'),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
  }

  void _showErrorBanner(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(
            'An error occurred while downloading the update: $error.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
  }

  Future<void> _downloadUpdate() async {
    _showDownloadingBanner();
    try {
      // Download the latest patch on [_currentTrack]
      _updater?.downloadUpdate();
      
      if (!mounted) return;
      // Show a banner to inform the user that the update is ready and that they
      // need to restart the app.
      _showRestartBanner();
      
      // Update patch numbers
      _currentPatchNumber = _updater?.currentPatchNumber() ?? 0;
      _nextPatchNumber = _updater?.nextPatchNumber() ?? 0;
      setState(() {});
    } catch (error) {
      // If an error occurs, we show a banner with the error message.
      _showErrorBanner(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('Shorebird Network'),
      ),
      body: Column(
        children: [
          const Spacer(),
          _CurrentPatchVersion(
            currentPatch: _currentPatchNumber,
            nextPatch: _nextPatchNumber,
          ),
          const SizedBox(height: 20),
          // 显示测试结果
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Library Test Results:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  testResult,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 添加测试按钮
          ElevatedButton(
            onPressed: _testUpdateBaseUrl,
            child: const Text('Test updateBaseUrl'),
          ),
          const SizedBox(height: 8),
          // 测试下载 URL 功能
          ElevatedButton(
            onPressed: _updater == null ? null : () {
              final updaterNetwork = _updater;
              if (updaterNetwork != null) {
                final success = updaterNetwork.updateDownloadUrl('https://custom-download.example.com');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Download URL updated to custom domain' 
                      : 'Failed to update download URL'),
                  ),
                );
              }
            },
            child: const Text('Set Custom Download URL'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _updater == null ? null : () {
              final updaterNetwork = _updater;
              if (updaterNetwork != null) {
                final success = updaterNetwork.updateDownloadUrl(null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Download URL cleared (using base URL)' 
                      : 'Failed to clear download URL'),
                  ),
                );
              }
            },
            child: const Text('Clear Download URL'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InitParamsDemo()),
              );
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('View Init Parameters'),
          ),
          const SizedBox(height: 12),
          _TrackPicker(
            currentTrack: _currentTrack,
            onChanged: (track) {
              setState(() => _currentTrack = track);
            },
          ),
          const Spacer(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCheckingForUpdates ? null : _checkForUpdate,
        tooltip: 'Check for update',
        child: _isCheckingForUpdates
            ? const _LoadingIndicator()
            : const Icon(Icons.refresh),
      ),
    );
  }
}

/// Widget that is mounted when Shorebird is not available.
class _ShorebirdUnavailable extends StatelessWidget {
  const _ShorebirdUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '''
Shorebird is not available.
Please make sure the app was generated via `shorebird release` and that it is running in release mode.''',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// Widget that displays the current patch version.
class _CurrentPatchVersion extends StatelessWidget {
  const _CurrentPatchVersion({
    required this.currentPatch,
    required this.nextPatch,
  });

  final int? currentPatch;
  final int? nextPatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('Network Library Status:'),
          Text(
            currentPatch != null ? 'Available' : 'Not Available',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: currentPatch != null ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Current patch:'),
          Text(
            currentPatch?.toString() ?? '0',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Next patch:'),
          Text(
            nextPatch?.toString() ?? '0',
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// Widget that allows selection of update track.
class _TrackPicker extends StatelessWidget {
  const _TrackPicker({
    required this.currentTrack,
    required this.onChanged,
  });

  final UpdateTrack currentTrack;

  final ValueChanged<UpdateTrack> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Update track:'),
        SegmentedButton<UpdateTrack>(
          segments: const [
            ButtonSegment(
              label: Text('Stable'),
              value: UpdateTrack.stable,
            ),
            ButtonSegment(
              label: Text('Beta'),
              icon: Icon(Icons.science),
              value: UpdateTrack.beta,
            ),
            ButtonSegment(
              label: Text('Staging'),
              icon: Icon(Icons.construction),
              value: UpdateTrack.staging,
            ),
          ],
          selected: {currentTrack},
          onSelectionChanged: (tracks) => onChanged(tracks.single),
        ),
      ],
    );
  }
}

/// A reusable loading indicator.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 14,
      width: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
