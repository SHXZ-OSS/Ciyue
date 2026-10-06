import "dart:io";

import "package:dio/dio.dart";

/// File operations required by Ciyue's versioned cloud sync format.
///
/// Paths are relative to the provider's configured root. Implementations must
/// stage downloads locally and replace the destination only after completion.
abstract interface class CloudFileStore {
  Future<List<CloudFileEntry>> listDirectory(String remotePath);

  Future<void> ensureDirectory(String remotePath);

  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  });

  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  });

  Future<void> deleteFile(String remotePath);

  Future<void> close();
}

class CloudFileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int? sizeBytes;

  const CloudFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes,
  });
}
