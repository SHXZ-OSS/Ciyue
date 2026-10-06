import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/mdm/oauth.dart";
import "package:ciyue/services/mdm/sync_service.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:intl/intl.dart";
import "package:material_ui/material_ui.dart";

class SchoolSyncSettingsPage extends StatefulWidget {
  const SchoolSyncSettingsPage({super.key});

  @override
  State<SchoolSyncSettingsPage> createState() => _SchoolSyncSettingsPageState();
}

class _SchoolSyncSettingsPageState extends State<SchoolSyncSettingsPage> {
  Future<MdmIdentity?>? _identityFuture;
  bool _syncing = false;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _identityFuture = mdmSyncService.identity();
    mdmOAuth.hasTokens().then((value) {
      if (mounted) {
        setState(() => _authorized = value);
      }
    });
  }

  void _reload() {
    setState(() {
      _identityFuture = mdmSyncService.identity();
    });
  }

  Future<void> _loginAndSync() async {
    final locale = AppLocalizations.of(context)!;
    setState(() => _syncing = true);
    try {
      await mdmSyncService.sync();
      if (mounted) {
        ToastService.show(locale.syncCompleted, context);
      }
    } catch (error) {
      if (mounted) {
        ToastService.show("$error", context, type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _authorized = true;
        });
        _reload();
      }
    }
  }

  Future<void> _logout() async {
    await mdmSyncService.disconnect();
    if (mounted) {
      setState(() => _authorized = false);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(locale.schoolSync)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<MdmIdentity?>(
            future: _identityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final identity = snapshot.data;
              if (identity == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          Platform.isAndroid
                              ? locale.schoolSyncNotManaged
                              : locale.schoolSyncAndroidOnly,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final lastSuccessAt = prefs.getInt("mdm.sync.lastSuccessAt");
              final lastSyncText = lastSuccessAt == null
                  ? locale.neverSynced
                  : DateFormat("yyyy-MM-dd HH:mm").format(
                      DateTime.fromMillisecondsSinceEpoch(lastSuccessAt),
                    );

              return ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: Text(identity.name),
                    subtitle: Text(locale.loggedInAs(identity.username)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.sync),
                    title: Text(locale.syncOnStartup),
                    value: settings.mdmAutoSync,
                    onChanged: (value) async {
                      await settings.setMdmAutoSync(value);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(locale.lastSync),
                    subtitle: Text(lastSyncText),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: _syncing ? null : _loginAndSync,
                      icon: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _authorized ? locale.syncNow : locale.authorizeAndSync,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton(
                      onPressed: _logout,
                      child: Text(locale.logout),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
