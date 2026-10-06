import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

/// This school fork's repository, shown as plain text only (not clickable) in
/// the managed school build.
class ForkTile extends StatelessWidget {
  const ForkTile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
      title: const Text("Fork"),
      subtitle: const Text(AboutViewModel.forkUri),
      leading: const Icon(Icons.fork_right),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.forkUri),
    );
  }
}
