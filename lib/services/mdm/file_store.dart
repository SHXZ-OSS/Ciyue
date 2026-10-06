import "dart:convert";
import "dart:io";

import "package:ciyue/core/http_client.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:dio/dio.dart";
import "package:path/path.dart" as p;

typedef MdmAccessTokenProvider = Future<String> Function();
typedef MdmServerUrlProvider = Future<String> Function();

/// [CloudFileStore] backed by the school backend's appdata file storage
/// (`/api/appdata/files/...`) with a Bearer access token from the MDM OAuth
/// flow.
///
/// The school backend creates parent directories automatically on upload, so
/// [ensureDirectory] is a no-op. Listing a missing directory returns an empty
/// list so the sync coordinator can bootstrap a fresh space.
class MdmFileStore implements CloudFileStore {
  final MdmServerUrlProvider serverUrlProvider;
  final MdmAccessTokenProvider accessTokenProvider;
  final Dio dio;

  MdmFileStore({
    required this.serverUrlProvider,
    required this.accessTokenProvider,
    Dio? dio,
  }) : dio = dio ?? AppHttp.dio;

  @override
  Future<void> ensureDirectory(String remotePath) async {}

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    final response = await _request(
      "GET",
      remotePath,
      responseType: ResponseType.json,
    );
    if (response.statusCode == 404) return const [];
    _ensureSuccess(response, "list");

    final data = response.data;
    final content = data is Map<String, dynamic> ? data["content"] : null;
    if (content is! List) {
      throw const HttpException("Invalid appdata directory listing.");
    }

    final entries = <CloudFileEntry>[];
    for (final raw in content) {
      if (raw is! Map) continue;
      final name = raw["name"];
      if (name is! String || name.isEmpty) continue;
      final isDirectory = raw["is_dir"] == true;
      final size = raw["size"];
      entries.add(
        CloudFileEntry(
          name: name,
          path: p.posix.join(_cleanPath(remotePath), name),
          isDirectory: isDirectory,
          sizeBytes: size is num ? size.toInt() : null,
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    ProgressCallback? onReceiveProgress,
  }) async {
    await destination.parent.create(recursive: true);
    final temporary = File("${destination.path}.ciyue-download");
    if (await temporary.exists()) {
      await temporary.delete();
    }
    try {
      final serverUrl = await serverUrlProvider();
      final token = await accessTokenProvider();
      final response = await dio.download(
        _fileUrl(serverUrl, remotePath),
        temporary.path,
        onReceiveProgress: onReceiveProgress,
        deleteOnError: true,
        options: Options(
          headers: {"Authorization": "Bearer $token"},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      _ensureSuccess(response, "download");
      if (await destination.exists()) {
        await destination.delete();
      }
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> uploadFile(
    String remotePath,
    File source, {
    ProgressCallback? onSendProgress,
  }) async {
    final data = await File(source.path).readAsBytes();
    final response = await _request(
      "PUT",
      remotePath,
      data: data,
      onSendProgress: onSendProgress,
      extraHeaders: {"Content-Length": data.length},
    );
    _ensureSuccess(response, "upload");
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final response = await _request("DELETE", remotePath);
    if (response.statusCode == 404) return;
    _ensureSuccess(response, "delete");
  }

  @override
  Future<void> close() async {}

  Future<Response<T>> _request<T>(
    String method,
    String remotePath, {
    Object? data,
    ResponseType? responseType,
    ProgressCallback? onSendProgress,
    Map<String, Object?>? extraHeaders,
  }) async {
    var response = await _perform<T>(
      method,
      remotePath,
      data: data,
      responseType: responseType,
      onSendProgress: onSendProgress,
      extraHeaders: extraHeaders,
    );
    // An expired access token is refreshed by the provider; a single retry
    // covers tokens revoked server-side between the check and the request.
    if (response.statusCode == 401) {
      response = await _perform<T>(
        method,
        remotePath,
        data: data,
        responseType: responseType,
        onSendProgress: onSendProgress,
        extraHeaders: extraHeaders,
      );
    }
    return response;
  }

  Future<Response<T>> _perform<T>(
    String method,
    String remotePath, {
    Object? data,
    ResponseType? responseType,
    ProgressCallback? onSendProgress,
    Map<String, Object?>? extraHeaders,
  }) async {
    final serverUrl = await serverUrlProvider();
    final token = await accessTokenProvider();
    return dio.request<T>(
      _fileUrl(serverUrl, remotePath),
      data: data,
      options: Options(
        method: method,
        headers: {"Authorization": "Bearer $token", ...?extraHeaders},
        responseType: responseType,
        validateStatus: (status) => status != null && status < 500,
      ),
      onSendProgress: onSendProgress,
    );
  }

  String _fileUrl(String serverUrl, String remotePath) {
    final encodedPath = _cleanPath(remotePath)
        .split("/")
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join("/");
    return "$serverUrl/api/appdata/files/$encodedPath";
  }

  String _cleanPath(String path) => path
      .trim()
      .replaceAll("\\", "/")
      .split("/")
      .where((s) => s.isNotEmpty)
      .join("/");

  void _ensureSuccess(Response<dynamic> response, String operation) {
    final status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      Object? description;
      if (response.data is Map) {
        final error = (response.data as Map)["error_description"];
        if (error is String) description = error;
      }
      throw HttpException(
        "Appdata $operation failed (HTTP $status"
        "${description == null ? "" : ": $description"}).",
      );
    }
  }
}

/// Decodes an appdata directory listing payload; exposed for tests.
List<CloudFileEntry> parseAppdataListing(String jsonContent, String dirPath) {
  final decoded = jsonDecode(jsonContent);
  final content = decoded is Map ? decoded["content"] : null;
  if (content is! List) {
    throw const FormatException("Invalid appdata directory listing.");
  }
  return [
    for (final raw in content)
      if (raw is Map && raw["name"] is String)
        CloudFileEntry(
          name: raw["name"] as String,
          path: p.posix.join(dirPath, raw["name"] as String),
          isDirectory: raw["is_dir"] == true,
          sizeBytes: raw["size"] is num ? (raw["size"] as num).toInt() : null,
        ),
  ];
}
