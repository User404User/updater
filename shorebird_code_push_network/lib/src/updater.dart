import 'dart:ffi' as ffi;
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:shorebird_code_push_network/src/generated/updater_bindings.g.dart';
import 'package:shorebird_code_push_network/src/shorebird_updater.dart';

/// {@template updater}
/// A wrapper around the generated [UpdaterBindings] that, when necessary,
/// translates ffi types into easier to use Dart types.
/// {@endtemplate}
class Updater {
  /// {@macro updater}
  const Updater();

  /// The ffi bindings to the Updater library.
  @visibleForTesting
  static UpdaterBindings bindings =
      UpdaterBindings(ffi.DynamicLibrary.process());

  /// The currently active patch number.
  Future<int?> currentPatchNumber() => bindings.shorebird_current_boot_patch_number();

  /// The next patch number that will be loaded. Will be the same as
  /// currentPatchNumber if no new patch is available.
  Future<int?> nextPatchNumber() => bindings.shorebird_next_boot_patch_number();

  /// Downloads the latest patch, if available.
  void downloadUpdate() => bindings.shorebird_update();

  // New Methods added to support v2.0.0 of the Dart APIs //

  /// Whether a new patch is available for download.
  Future<bool> checkForDownloadableUpdate({UpdateTrack? track}) =>
      bindings.shorebird_check_for_downloadable_update(
        track == null ? ffi.nullptr : track.name.toNativeUtf8().cast<Char>(),
      );

  /// Downloads the latest patch, if available and returns an [UpdateResult]
  /// to indicate whether the update was successful.
  Pointer<UpdateResult> update({UpdateTrack? track}) =>
      bindings.shorebird_update_with_result(
        track == null ? ffi.nullptr : track.name.toNativeUtf8().cast<Char>(),
      );

  /// Frees an update result allocated by the updater.
  void freeUpdateResult(Pointer<UpdateResult> ptr) =>
      bindings.shorebird_free_update_result(ptr);

  /// Update the base URL for patch checking and downloading.
  /// The base_url parameter must be a valid URL string (e.g., "https://api.example.com").
  /// Returns true if the base URL was updated successfully, false otherwise.
  bool updateBaseUrl(String baseUrl) =>
      bindings.shorebird_update_base_url(baseUrl.toNativeUtf8().cast<Char>());
}
