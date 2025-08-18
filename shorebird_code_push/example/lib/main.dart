import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorebird Code Push Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
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
  final _updater = ShorebirdUpdater();
  late final bool _isUpdaterAvailable;
  var _currentTrack = UpdateTrack.stable;
  var _isCheckingForUpdates = false;
  Patch? _currentPatch;

  @override
  void initState() {
    super.initState();
    // Check whether Shorebird is available.
    setState(() => _isUpdaterAvailable = _updater.isAvailable);

    // Read the current patch (if there is one.)
    // `currentPatch` will be `null` if no patch is installed.
    _updater.readCurrentPatch().then((currentPatch) {
      setState(() => _currentPatch = currentPatch);
    }).catchError((Object error) {
      // If an error occurs, we log it for now.
      debugPrint('Error reading current patch: $error');
    });
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingForUpdates) return;

    try {
      setState(() => _isCheckingForUpdates = true);
      // Check if there's an update available.
      final status = await _updater.checkForUpdate(track: _currentTrack);
      if (!mounted) return;
      // If there is an update available, show a banner.
      switch (status) {
        case UpdateStatus.upToDate:
          _showNoUpdateAvailableBanner();
        case UpdateStatus.outdated:
          _showUpdateAvailableBanner();
        case UpdateStatus.restartRequired:
          _showRestartBanner();
        case UpdateStatus.unavailable:
        // Do nothing, there is already a warning displayed at the top of the
        // screen.
      }
    } catch (error) {
      // If an error occurs, we log it for now.
      debugPrint('Error checking for update: $error');
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
      // Perform the update (e.g download the latest patch on [_currentTrack]).
      // Note that [track] is optional. Not passing it will default to the
      // stable track.
      await _updater.update(track: _currentTrack);
      if (!mounted) return;
      // Show a banner to inform the user that the update is ready and that they
      // need to restart the app.
      _showRestartBanner();
    } on UpdateException catch (error) {
      // If an error occurs, we show a banner with the error message.
      _showErrorBanner(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('Shorebird Code Push'),
      ),
      body: Column(
        children: [
          if (!_isUpdaterAvailable) const _ShorebirdUnavailable(),
          const Spacer(),
          _CurrentPatchVersion(patch: _currentPatch),
          const SizedBox(height: 12),
          _TrackPicker(
            currentTrack: _currentTrack,
            onChanged: (track) {
              setState(() => _currentTrack = track);
            },
          ),
          const SizedBox(height: 24),
          _ServerConfiguration(),
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
  const _CurrentPatchVersion({required this.patch});

  final Patch? patch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('Current patch version:'),
          Text(
            patch != null ? '${patch!.number}' : 'No patch installed',
            style: theme.textTheme.headlineMedium,
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

/// Widget that allows updating the server base URL.
class _ServerConfiguration extends StatefulWidget {
  const _ServerConfiguration();

  @override
  State<_ServerConfiguration> createState() => _ServerConfigurationState();
}

class _ServerConfigurationState extends State<_ServerConfiguration> {
  final _urlController = TextEditingController();
  String _currentServerMessage = 'Using default server';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _updateBaseUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _currentServerMessage = 'Please enter a valid URL';
      });
      return;
    }

    final success = ShorebirdCodePush.updateBaseUrl(url);
    setState(() {
      _currentServerMessage = success 
        ? 'Server updated to: $url'
        : 'Failed to update server URL';
    });

    if (success) {
      _urlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update server URL'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _useExampleServers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('US Server'),
              subtitle: Text('https://us.api.shorebird.dev'),
              onTap: () {
                _urlController.text = 'https://us.api.shorebird.dev';
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('EU Server'),
              subtitle: Text('https://eu.api.shorebird.dev'),
              onTap: () {
                _urlController.text = 'https://eu.api.shorebird.dev';
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('Custom Enterprise'),
              subtitle: Text('https://updates.company.com'),
              onTap: () {
                _urlController.text = 'https://updates.company.com';
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              _currentServerMessage,
              style: TextStyle(
                fontSize: 12,
                color: _currentServerMessage.contains('Failed') 
                  ? Colors.red 
                  : Colors.green,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Custom Server URL',
                      hintText: 'https://your-server.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: _useExampleServers,
                  icon: Icon(Icons.list),
                  tooltip: 'Choose from examples',
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _updateBaseUrl,
                  child: Text('Update Server'),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _urlController.clear();
                    setState(() {
                      _currentServerMessage = 'Using default server';
                    });
                  },
                  child: Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
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
