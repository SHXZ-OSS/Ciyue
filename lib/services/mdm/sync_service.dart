import "dart:math";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/service.dart";
import "package:ciyue/services/mdm/file_store.dart";
import "package:ciyue/services/mdm/oauth.dart";
import "package:ciyue/services/toast.dart";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";

const _deviceIdKey = "mdm.sync.deviceId";
const _spaceIdKey = "mdm.sync.spaceId";
const _lastSuccessAtKey = "mdm.sync.lastSuccessAt";
const _remoteRoot = "records";

final mdmSyncService = MdmSyncService();

/// Syncs the student's local records (wordbook, tags, flashcards and their
/// review logs) to the school backend's per-user appdata storage.
///
/// The versioned snapshot/merge engine is the one shared with the previous
/// generic cloud sync; only the transport (MDM OAuth + appdata REST) is
/// school-specific.
class MdmSyncService {
  final AppDatabase database;
  final MdmOAuth oauth;
  final CloudSyncSpaceManager spaceManager;

  MdmSyncService({
    AppDatabase? database,
    MdmOAuth? oauth,
    CloudSyncSpaceManager? spaceManager,
  }) : database = database ?? mainDatabase,
       oauth = oauth ?? mdmOAuth,
       spaceManager = spaceManager ?? const CloudSyncSpaceManager();

  Future<MdmIdentity?> identity() => oauth.identity();

  Future<bool> isAuthorized() async {
    final identity = await oauth.identity();
    return identity != null && await oauth.hasTokens();
  }

  /// Ensures authorization exists, then performs one sync round.
  Future<CloudSyncOutcome> sync() async {
    final identity = await oauth.identity();
    if (identity == null) {
      throw MdmAuthorizationException("login_required");
    }
    // Authorizes on first use and whenever the tokens belong to someone else.
    await oauth.tokensFor(identity);

    final fileStore = MdmFileStore(
      serverUrlProvider: () async => (await oauth.identity())!.serverUrl,
      accessTokenProvider: () async =>
          (await oauth.validAccessToken()).accessToken,
    );

    final deviceId = await _deviceId();
    final spaceId = await spaceManager.resolve(
      fileStore: fileStore,
      remoteRoot: _remoteRoot,
      preferredSpaceId: prefs.getString(_spaceIdKey),
      generatedSpaceId: _generateSyncId("space"),
    );
    await prefs.setString(_spaceIdKey, spaceId);

    final appSupport = await getApplicationSupportDirectory();
    final service = CloudSyncService(
      database: database,
      deviceId: deviceId,
      spaceId: spaceId,
      remoteRoot: _remoteRoot,
      fileStore: fileStore,
      stateStore: fileSyncSnapshotStateStore(appSupport, spaceId),
    );
    final outcome = await service.sync();
    await prefs.setInt(
      _lastSuccessAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return outcome;
  }

  /// Startup path: sync silently, and only when the student has already
  /// authorized the app in settings. Never triggers a new authorization.
  Future<void> syncIfAuthorized(BuildContext? context) async {
    try {
      if (!await isAuthorized()) return;
      await sync();
    } catch (error, stackTrace) {
      talker.error("School sync failed", error, stackTrace);
      if (context != null && context.mounted) {
        ToastService.show(error.toString(), context, type: ToastType.error);
      }
    }
  }

  /// Forgets this device's sync state (tokens and local snapshot identity).
  Future<void> disconnect() async {
    await oauth.clearTokens();
    await prefs.remove(_spaceIdKey);
    await prefs.remove(_lastSuccessAtKey);
  }

  Future<String> _deviceId() async {
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateSyncId("device");
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }
}

String _generateSyncId(String prefix) {
  final random = Random.secure();
  final hex = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, "0"),
  ).join();
  return "$prefix-$hex";
}
