import "dart:async";

import "package:ciyue/services/dict_library.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class DictLibraryPage extends StatefulWidget {
  const DictLibraryPage({super.key});

  @override
  State<DictLibraryPage> createState() => _DictLibraryPageState();
}

class _DictLibraryPageState extends State<DictLibraryPage> {
  Future<(DictLibraryIndex, Map<String, String>)>? _future;
  final Map<String, (int, int)> _progress = {};
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = () async {
        final index = await dictLibraryService.fetchIndex();
        final installed = await dictLibraryService.installedVersions();
        return (index, installed);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(locale.dictLibrary)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<(DictLibraryIndex, Map<String, String>)>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(locale.dictLibraryLoadFailed),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _reload,
                        child: Text(locale.retry),
                      ),
                    ],
                  ),
                );
              }
              final (index, installed) = snapshot.data!;
              if (index.dictionaries.isEmpty) {
                return Center(child: Text(locale.empty));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                },
                child: ListView(
                  children: [
                    for (final entry in index.dictionaries)
                      _DictLibraryCard(
                        entry: entry,
                        installedVersion: installed[entry.id],
                        progress: _progress[entry.id],
                        isDownloading: _downloading.contains(entry.id),
                        onInstall: () => _install(entry),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _install(DictLibraryEntry entry) async {
    final locale = AppLocalizations.of(context)!;
    setState(() {
      _downloading.add(entry.id);
      _progress[entry.id] = (0, entry.totalSizeBytes);
    });
    try {
      final (dictId, dictPath) = await dictLibraryService.install(
        entry,
        onProgress: (downloaded, total) {
          if (!mounted) return;
          setState(() {
            _progress[entry.id] = (downloaded, total);
          });
        },
      );
      if (mounted) {
        // Load the dictionary into the current group right away.
        final model = context.read<DictManagerModel>();
        await model.add(dictId, dictPath);
        model.checkIsEmpty();
        await model.updateDictIds();

        if (!mounted) return;
        context.read<ManageDictionariesModel>().update();
        ToastService.show(locale.installedSuccessfully, context);
      }
    } catch (error) {
      if (mounted) {
        ToastService.show(
          "${locale.dictInstallFailed}: $error",
          context,
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading.remove(entry.id);
          _progress.remove(entry.id);
        });
        _reload();
      }
    }
  }
}

class _DictLibraryCard extends StatelessWidget {
  final DictLibraryEntry entry;
  final String? installedVersion;
  final (int, int)? progress;
  final bool isDownloading;
  final Future<void> Function() onInstall;

  const _DictLibraryCard({
    required this.entry,
    required this.installedVersion,
    required this.progress,
    required this.isDownloading,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final Widget trailing;
    if (isDownloading) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (installedVersion == null) {
      trailing = FilledButton.tonal(
        onPressed: onInstall,
        child: Text(locale.download),
      );
    } else if (installedVersion != entry.version) {
      trailing = FilledButton(onPressed: onInstall, child: Text(locale.update));
    } else {
      trailing = Icon(Icons.check_circle, color: theme.colorScheme.primary);
    }

    final progressValue = progress == null || progress!.$2 == 0
        ? null
        : (progress!.$1 / progress!.$2).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(entry.name, style: theme.textTheme.titleMedium),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.description != null && entry.description!.isNotEmpty)
                  Text(entry.description!),
                Text("${entry.version} · ${_formatSize(entry.totalSizeBytes)}"),
                if (installedVersion != null)
                  Text(
                    "${locale.installed}: $installedVersion",
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
              ],
            ),
            isThreeLine:
                entry.description != null && entry.description!.isNotEmpty,
            trailing: trailing,
          ),
          if (progressValue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(value: progressValue),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
    }
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    if (bytes >= 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
    return "$bytes B";
  }
}
