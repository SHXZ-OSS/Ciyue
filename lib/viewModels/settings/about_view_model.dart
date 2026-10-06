import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

class AboutViewModel extends ChangeNotifier {
  // URIs and other constants
  static const githubUri = "https://github.com/mumu-lhl/Ciyue";
  static const forkUri = "https://github.com/SHXZ-OSS/Ciyue";

  void copyToClipboard(BuildContext context, String text) {
    addToClipboard(context, text);
  }

  void openTermsOfService(BuildContext context) {
    context.push("/settings/terms_of_service");
  }

  void openPrivacyPolicy(BuildContext context) {
    context.push("/settings/privacy_policy");
  }

  Future<void> showChangelog(BuildContext context) async {
    final changelogContent = await ChangelogService.getChangelogContent(
      Localizations.localeOf(context),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => ChangelogDialog(changelogContent: changelogContent),
    );
  }

  String get applicationVersion {
    final isDev = const bool.hasEnvironment("DEV");
    if (isDev) {
      final commitHash = const String.fromEnvironment("GIT_COMMIT_HASH");
      final timestampString = const String.fromEnvironment("BUILD_TIMESTAMP");

      if (timestampString.isNotEmpty) {
        final timestamp = int.tryParse(timestampString);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            timestamp * 1000,
            isUtc: true,
          ).toLocal();
          return "${packageInfo.version} Dev ($commitHash) ${DateFormat("yyyy-MM-dd-HH:mm:ss").format(date)}";
        }
      }

      return "${packageInfo.version} Dev ($commitHash)";
    }

    return "${packageInfo.version} (${packageInfo.buildNumber})";
  }

  String get applicationName => packageInfo.appName;
  String get applicationLegalese => "\u{a9} 2024-2025 Mumulhl and contributors";
}
