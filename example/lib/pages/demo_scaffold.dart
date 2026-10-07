import 'package:flutter/material.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

/// Shared scaffold for a demo category page: app bar with back button and a
/// scrollable body.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return OhosScaffold(
      appBar: OhosAppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          for (final Widget child in children) child,
          if (footer != null) footer!,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Section title + content used inside a demo page.
class DemoSection extends StatelessWidget {
  const DemoSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 28),
  });

  final String title;
  final String? description;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.highlightColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.typography.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 10),
              child: Text(
                description!,
                style: theme.typography.bodySmall?.copyWith(
                  color: theme.textSecondaryColor,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Card wrapper for demo content.
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return OhosCard(padding: padding, child: child);
  }
}
