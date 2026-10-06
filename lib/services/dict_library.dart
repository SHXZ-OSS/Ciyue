import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/http_client.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

/// Index URL of the school dictionary library.
const dictLibraryIndexUrl = String.fromEnvironment(
  "DICT_LIBRARY_INDEX_URL",
  defaultValue: "https://dict-cdn.shxzhy.cn/index.json",
);

const _installedKey = "dictLibraryInstalled";

class DictLibraryFile {
  /// Final file name; every file of one dictionary must share the same stem
  /// (for example `main.mdx`, `main.mdd`, `main.1.mdd`).
  final String name;
  final Uri url;
  final int sizeBytes;
  final String? sha256;

  const DictLibraryFile({
    required this.name,
    required this.url,
    required this.sizeBytes,
    this.sha256,
  });
}

class DictLibraryEntry {
  final String id;
  final String name;
  final String? description;
  final String version;
  final List<DictLibraryFile> files;

  const DictLibraryEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.files,
    this.description,
  });

  int get totalSizeBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);
}

class DictLibraryIndex {
  final List<DictLibraryEntry> dictionaries;

  const DictLibraryIndex({required this.dictionaries});
}

class DictLibraryFormatException implements Exception {
  const DictLibraryFormatException();

  @override
  String toString() => "Invalid dictionary library index.";
}

/// The school-hosted dictionary library: reads a JSON index from the CDN and
/// installs selected dictionaries into the local dictionary manager.
///
/// Index format (see docs/dict-library.md):
///
/// ```json
/// {
///   "format": 1,
///   "dictionaries": [
///     {
///       "id": "oald-10",
///       "name": "Oxford Advanced Learner's Dictionary",
///       "description": "optional",
///       "version": "2026-09",
///       "files": [
///         {"name": "main.mdx", "url": "files/oald10.mdx",
///          "sizeBytes": 800, "sha256": "optional hex"},
///         {"name": "main.mdd", "url": "files/oald10.mdd",
///          "sizeBytes": 400, "sha256": "..."}
///       ]
///     }
///   ]
/// }
/// ```
class DictLibraryService {
  final Dio dio;

  DictLibraryService({Dio? dio}) : dio = dio ?? AppHttp.dio;

  Future<DictLibraryIndex> fetchIndex() async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await dio.get<Map<String, dynamic>>(dictLibraryIndexUrl);
    } on DioException {
      throw const DictLibraryFormatException();
    }
    final data = response.data;
    if (data == null || data["format"] != 1) {
      throw const DictLibraryFormatException();
    }
    final dictionaries = data["dictionaries"];
    if (dictionaries is! List) {
      throw const DictLibraryFormatException();
    }

    final indexBase = Uri.parse(dictLibraryIndexUrl);
    final entries = <DictLibraryEntry>[];
    for (final raw in dictionaries) {
      if (raw is! Map) continue;
      final entry = _parseEntry(raw, indexBase);
      if (entry != null) entries.add(entry);
    }
    return DictLibraryIndex(dictionaries: entries);
  }

  DictLibraryEntry? _parseEntry(Map raw, Uri indexBase) {
    final id = raw["id"];
    final name = raw["name"];
    final version = raw["version"];
    final files = raw["files"];
    if (id is! String ||
        id.isEmpty ||
        RegExp(r"[^A-Za-z0-9._-]").hasMatch(id) ||
        name is! String ||
        name.isEmpty ||
        version is! String ||
        files is! List ||
        files.isEmpty) {
      return null;
    }

    final parsedFiles = <DictLibraryFile>[];
    for (final rawFile in files) {
      if (rawFile is! Map) continue;
      final fileName = rawFile["name"];
      final url = rawFile["url"];
      final sizeBytes = rawFile["sizeBytes"];
      if (fileName is! String ||
          !fileName.contains(".") ||
          url is! String ||
          url.isEmpty ||
          sizeBytes is! num) {
        return null;
      }
      final sha256 = rawFile["sha256"];
      parsedFiles.add(
        DictLibraryFile(
          name: fileName,
          url: _resolveUrl(indexBase, url),
          sizeBytes: sizeBytes.toInt(),
          sha256: sha256 is String && sha256.isNotEmpty ? sha256 : null,
        ),
      );
    }
    if (parsedFiles.isEmpty ||
        parsedFiles.every((file) => !file.name.endsWith(".mdx"))) {
      return null;
    }

    return DictLibraryEntry(
      id: id,
      name: name,
      description: raw["description"] is String
          ? raw["description"] as String
          : null,
      version: version,
      files: parsedFiles,
    );
  }

  Uri _resolveUrl(Uri indexBase, String url) {
    final uri = Uri.parse(url);
    if (uri.hasScheme) return uri;
    return indexBase.resolve(url);
  }

  /// Locally installed library dictionaries: id -> version.
  Future<Map<String, String>> installedVersions() async {
    final raw = prefs.getString(_installedKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _saveInstalledVersions(Map<String, String> versions) async {
    await prefs.setString(_installedKey, jsonEncode(versions));
  }

  /// Downloads all files of [entry] and imports the dictionary.
  ///
  /// Files land in `<app support>/dict_library/<id>/` and are renamed to the
  /// dictionary id stem so the MDX/MDD discovery of the dictionary manager
  /// finds them. Returns the dictionary list id and its path (without the
  /// .mdx extension) so callers can load the dictionary right away.
  Future<(int, String)> install(
    DictLibraryEntry entry, {
    void Function(int downloadedBytes, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final appSupport = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(appSupport.path, "dict_library", entry.id),
    );
    await directory.create(recursive: true);

    final base = p.join(directory.path, entry.id);
    final totalBytes = entry.totalSizeBytes;
    var downloaded = 0;
    final destinations = <File>[];
    for (final file in entry.files) {
      final destination = File(
        p.join(directory.path, _targetName(entry.id, file.name)),
      );
      final partFile = File("${destination.path}.part");
      try {
        await dio.download(
          file.url.toString(),
          partFile.path,
          cancelToken: cancelToken,
          deleteOnError: true,
          onReceiveProgress: (count, _) =>
              onProgress?.call(downloaded + count, totalBytes),
        );
        await _verifyChecksum(partFile, file.sha256);
      } catch (_) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
        rethrow;
      }
      destinations.add(partFile);
      downloaded += file.sizeBytes;
      onProgress?.call(downloaded, totalBytes);
    }

    // Replace a previous installation of this entry. This may delete the old
    // MDX/MDD files on some platforms, so it must run after the new files are
    // downloaded (as .part) and before they are moved into place.
    if (await dictionaryListDao.dictionaryExist(base)) {
      final oldDict = Mdict(path: base);
      final oldId = await dictionaryListDao.getId(base);
      await oldDict.removeDictionary(dictionaryId: oldId);
    }

    for (var i = 0; i < entry.files.length; i++) {
      final destination = File(
        p.join(directory.path, _targetName(entry.id, entry.files[i].name)),
      );
      if (await destination.exists()) {
        await destination.delete();
      }
      await destinations[i].rename(destination.path);
    }

    final dict = Mdict(path: base);
    late final int id;
    try {
      await dict.add();
      id = await dictionaryListDao.getId(base);
      // Some MDX conversions carry placeholder titles in their headers
      // ("Title (No HTML code allowed)"); prefer the curated library name.
      await dictionaryListDao.updateTitle(id, entry.name);
    } finally {
      await dict.close();
    }

    final installed = await installedVersions();
    installed[entry.id] = entry.version;
    await _saveInstalledVersions(installed);
    talker.info(
      "Installed dictionary from library: ${entry.id} ${entry.version}",
    );
    return (id, base);
  }

  /// Removes the local installation record; the dictionary itself is removed
  /// through the dictionary manager.
  Future<void> forgetInstalled(String id) async {
    final installed = await installedVersions();
    installed.remove(id);
    await _saveInstalledVersions(installed);
  }

  String _targetName(String id, String fileName) {
    final dot = fileName.indexOf(".");
    return "$id.${fileName.substring(dot + 1)}";
  }

  Future<void> _verifyChecksum(File file, String? expectedSha256) async {
    if (expectedSha256 == null) return;
    final digest = sha256.convert(await file.readAsBytes()).toString();
    if (digest.toLowerCase() != expectedSha256.toLowerCase()) {
      throw Exception("Checksum mismatch for ${p.basename(file.path)}");
    }
  }
}

final dictLibraryService = DictLibraryService();
