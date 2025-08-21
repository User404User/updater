# Shorebird Code Push Network

[![Discord](https://img.shields.io/discord/1030243211995791380?style=for-the-badge&logo=discord&color=blue)](https://discord.gg/shorebird)

[![ci](https://github.com/shorebirdtech/updater/actions/workflows/main.yaml/badge.svg)](https://github.com/shorebirdtech/updater/actions/workflows/main.yaml)
[![codecov](https://codecov.io/gh/shorebirdtech/updater/branch/main/graph/badge.svg)](https://codecov.io/gh/shorebirdtech/updater)
[![License: MIT][license_badge]][license_link]

A network-only version of Shorebird Code Push that downloads patches without Flutter engine integration. Use this in native Android/iOS apps to:

- ✅ Check for available updates
- ✅ Download patches to cache directory  
- ✅ Dynamic server URL configuration
- ✅ Avoid symbol conflicts with engine-integrated Shorebird
- ✅ Cross-platform support (Android/iOS)

## Key Differences from Regular Shorebird

| Feature | Network Plugin | Engine Integrated |
|---------|---------------|------------------|
| Download Patches | ✅ | ✅ |
| Apply Patches | ❌ | ✅ |
| Hot Restart | ❌ | ✅ |
| Symbol Conflicts | ❌ | Possible |
| Native Integration | Simple | Complex |

**Use Case**: This plugin is designed for scenarios where you need to download patches in native code but let the original Flutter engine apply them on restart.

## Getting Started

If your Flutter app does not already use Shorebird, follow our
[Getting Started Guide](https://docs.shorebird.dev/) to add code push to your
app.

## Installation

```sh
flutter pub add shorebird_code_push_network
```

## Platform Setup

### Android
The plugin automatically includes the native libraries. No additional setup required.

### iOS  
The plugin uses static linking on iOS. The native library is automatically linked through the podspec.

## Usage

After adding the package to your `pubspec.yaml`, you can use it in your app like
this:

```dart
// Import the library
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';

// Launch your app
void main() => runApp(const MyApp());

// [Other code here]

class _MyHomePageState extends State<MyHomePage> {
  // Create an instance of the network updater class
  final updater = UpdaterNetwork();

  @override
  void initState() {
    super.initState();

    // Get the current patch number and print it to the console.
    // It will be `0` if no patches are installed.
    print('The current patch number is: ${updater.currentPatchNumber()}');
  }

  Future<void> _checkForUpdates() async {
    // Check whether a new update is available.
    final isUpdateAvailable = updater.checkForDownloadableUpdate();

    if (isUpdateAvailable) {
      try {
        // Download the update
        updater.downloadUpdate();
        print('Update downloaded! Restart app to apply.');
      } catch (error) {
        // Handle any errors that occur while downloading.
        print('Update failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [Other code here]
      ElevatedButton(
        child: Text('Check for update'),
        onPressed: _checkForUpdates,
      )
      // [Other code here]
    );
  }
}
```

See the example for a complete working app.

### Tracks

Shorebird also supports publishing patches to different tracks, which can be
used to target different segments of your user base. See
https://docs.shorebird.dev/code-push/guides/percentage-based-rollouts/ for a
guide on using this functionality to implement percentage-based rollouts.

You must first publish a patch to a specific track (patches are published to the
`stable` track by default). To publish a patch to a different track, update your
patch command to use the `--track` argument:

```sh
shorebird patch android --track beta
```

(We're just using Android for this example. Tracks are supported on all
platforms).

To check for updates on a given track, simply pass an `UpdateTrack` to
`checkForUpdate` and `update`. For example, this:

```dart
final status = await updater.checkForUpdate();
if (status == UpdateStatus.outdated) {
  await updater.update();
}
```

Becomes this:

```dart
final status = await updater.checkForUpdate(track: UpdateTrack.beta);
if (status == UpdateStatus.outdated) {
  await updater.update(track: UpdateTrack.beta);
}
```

## Dynamic Base URL Configuration

If you need to use a custom update server or change the base URL at runtime, you can use the `updateBaseUrl` method:

```dart
import 'package:shorebird_code_push_network/shorebird_code_push_network.dart';

final updater = UpdaterNetwork();

// Update the base URL for patch checking and downloading
final success = updater.updateBaseUrl('https://your-custom-server.com');

if (success) {
  print('Base URL updated successfully');
  // Now all subsequent update checks will use the new URL
  final isAvailable = updater.checkForDownloadableUpdate();
  // ...
} else {
  print('Failed to update base URL');
}
```

### Use Cases for Custom Base URLs

- **Enterprise Deployments**: Use your own update servers for security and compliance
- **Regional Servers**: Route users to geographically closer servers for better performance
- **Testing Environments**: Switch between development, staging, and production servers
- **Offline/Air-gapped Networks**: Use internal servers in restricted environments

### Important Notes

- The base URL must be a valid URL format (e.g., `https://api.example.com`)
- The URL change is persistent until the app restarts or another `updateBaseUrl` call is made
- This affects all subsequent update operations (check, download, etc.)
- The original server configuration from `shorebird.yaml` will be restored on app restart

## Custom Track Names

You can also use custom track names. When creating a patch, specify a track name
like this:

```sh
shorebird patch android --track my-custom-track
```

And:

```dart
const track = UpdateTrack('my-custom-track');
final isAvailable = updater.checkForDownloadableUpdate(track: track);
if (isAvailable) {
  updater.downloadUpdate(track: track);
}
```

## Join us on Discord!

We have an active [Discord server](https://discord.gg/shorebird) where you can
ask questions and get help.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
