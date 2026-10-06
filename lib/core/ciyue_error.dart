import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

class CiyueError extends StatelessWidget {
  final Object error;

  const CiyueError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Error")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error.toString()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: error.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error copied to clipboard")),
                );
              },
              child: const Text("Copy Error"),
            ),
          ],
        ),
      ),
    );
  }
}
