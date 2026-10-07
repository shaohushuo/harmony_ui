import 'package:flutter/widgets.dart';

export 'ohos_theme_data.dart';

import 'ohos_theme_data.dart';

/// Inherited widget that provides an [OhosThemeData] to the subtree, the
/// `ohos_ui` counterpart of Flutter's [Theme].
class OhosTheme extends InheritedWidget {
  const OhosTheme({super.key, required this.data, required super.child});

  /// Design tokens for the subtree.
  final OhosThemeData data;

  /// Returns the [OhosThemeData] from the closest enclosing [OhosTheme], or a
  /// light fallback theme when none exists.
  static OhosThemeData of(BuildContext context) {
    final OhosTheme? theme = context
        .dependOnInheritedWidgetOfExactType<OhosTheme>();
    return theme?.data ?? OhosThemeData.light();
  }

  /// Returns the [OhosThemeData] from the closest enclosing [OhosTheme] in an
  /// ancestor, without creating a dependency.
  static OhosThemeData? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<OhosTheme>()?.data;
  }

  @override
  bool updateShouldNotify(OhosTheme oldWidget) => data != oldWidget.data;
}
