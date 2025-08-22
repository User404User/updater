import 'package:shorebird_code_push_network/src/shorebird_updater.dart';

import '../shorebird_code_push_network.dart';

/// {@template shorebird_updater_web}
/// The Shorebird web updater.
/// {@endtemplate}
class ShorebirdUpdaterImpl implements ShorebirdUpdater {
  /// {@macro shorebird_updater_web}
  ShorebirdUpdaterImpl() {
    logShorebirdEngineUnavailableMessage();
  }

  @override
  bool get isAvailable => false;

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async =>
      UpdateStatus.unavailable;

  @override
  Future<void> update({UpdateTrack? track}) async {}

  @override
  bool updateBaseUrl(String baseUrl) => false;

  @override
  bool updateDownloadUrl(String? downloadUrl) => false;
}
