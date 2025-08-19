import 'package:shorebird_code_push/src/shorebird_updater.dart';

export 'src/shorebird_updater.dart'
    show
        Patch,
        ReadPatchException,
        ShorebirdUpdater,
        UpdateException,
        UpdateFailureReason,
        UpdateStatus,
        UpdateTrack;

/// The ShorebirdCodePush class provides a convenient API for checking for and
/// downloading patches.
class ShorebirdCodePush {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Whether the updater is available on the current platform.
  static bool get isAvailable => _updater.isAvailable;

  /// Checks if a new patch is available for download.
  static Future<bool> isNewPatchAvailableForDownload({
    UpdateTrack? track,
  }) async {
    final status = await _updater.checkForUpdate(track: track);
    return status == UpdateStatus.outdated;
  }

  /// Downloads an available update if one exists.
  static Future<void> downloadUpdateIfAvailable({
    UpdateTrack? track,
  }) async {
    try {
      await _updater.update(track: track);
    } on Exception {
      // Silently handle errors for compatibility
    }
  }

  /// Update the base URL for patch checking and downloading.
  /// The base_url parameter must be a valid URL string 
  /// (e.g., "https://api.example.com").
  /// Returns true if the base URL was updated successfully, false otherwise.
  static bool updateBaseUrl(String baseUrl) {
    return _updater.updateBaseUrl(baseUrl);
  }
}
