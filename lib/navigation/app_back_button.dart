import 'package:flutter/material.dart';
import '../platform/browser_actions.dart';

/// Both the toolbar and a browser gesture traverse the same history entry.
/// A direct link without an earlier app entry falls back to Navigator.maybePop.
void popAppPage(BuildContext context, [Object? result]) {
  if (!goBackInBrowser()) Navigator.of(context).maybePop(result);
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) => Navigator.canPop(context)
      ? BackButton(onPressed: () => popAppPage(context))
      : const SizedBox.shrink();
}
