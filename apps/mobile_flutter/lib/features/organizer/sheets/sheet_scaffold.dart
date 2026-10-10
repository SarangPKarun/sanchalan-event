import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Shows [builder] in a bottom sheet that grows with the keyboard and scrolls
/// when it does not fit.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Common frame for sheet content: title and scrollable body, with the main
/// action ([footer]) pinned below so it is always visible, above the keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.m,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.headlineSmall),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: text.bodyMedium),
                  ],
                  const SizedBox(height: AppSpace.l),
                  ...children,
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.s,
                AppSpace.xl,
                AppSpace.m,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Parses a rupee amount typed by the user ("4,50,000" or "450000"); null if not a positive number.
double? parseAmount(String input) {
  final cleaned = input.replaceAll(RegExp(r'[,\s₹]'), '');
  final v = double.tryParse(cleaned);
  return v != null && v > 0 ? v : null;
}
