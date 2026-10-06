import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

/// Upstream project link, shown as plain text only (not clickable) in the
/// managed school build.
class GithubTile extends StatelessWidget {
  const GithubTile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
      title: const Text("GitHub"),
      subtitle: const Text(AboutViewModel.githubUri),
      leading: const Icon(Icons.public),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.githubUri),
    );
  }
}
