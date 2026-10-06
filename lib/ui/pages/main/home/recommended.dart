import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

class RecommendedDictionaries extends StatelessWidget {
  const RecommendedDictionaries({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(locale!.addDictionary),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: Text(locale.dictLibrary),
            onPressed: () => context.push("/settings/dict_library"),
          ),
        ],
      ),
    );
  }
}
