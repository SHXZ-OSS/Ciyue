import "package:material_ui/material_ui.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({super.key, required this.changelogContent});

  final String changelogContent;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.changelog),
      content: SingleChildScrollView(
        child: SelectionArea(child: GptMarkdown(changelogContent)),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    );
  }
}
