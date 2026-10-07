/// ohos_ui — a Material/Cupertino-style widget library that implements the
/// HarmonyOS design language.
///
/// Wrap your app with an [OhosTheme] to provide design tokens (colors,
/// typography, geometry and motion) to every widget below, then use the
/// `Ohos*` widgets just like you would use `Material*` or `Cupertino*`
/// widgets.
///
/// ```dart
/// OhosTheme(
///   data: OhosThemeData.light(),
///   child: const OhosScaffold(
///     appBar: OhosAppBar(title: Text('Hello')),
///     body: Center(
///       child: OhosButton(
///         child: Text('Get started'),
///         onPressed: null,
///       ),
///     ),
///   ),
/// )
/// ```
library;

export 'src/theme/ohos_colors.dart';
export 'src/theme/ohos_geometry.dart';
export 'src/theme/ohos_theme.dart';
export 'src/theme/ohos_theme_data.dart';
export 'src/theme/ohos_typography.dart';

export 'src/widgets/ohos_alert_dialog.dart';
export 'src/widgets/ohos_app_bar.dart';
export 'src/widgets/ohos_badge.dart';
export 'src/widgets/ohos_button.dart';
export 'src/widgets/ohos_card.dart';
export 'src/widgets/ohos_checkbox.dart';
export 'src/widgets/ohos_chip.dart';
export 'src/widgets/ohos_divider.dart';
export 'src/widgets/ohos_icon_button.dart';
export 'src/widgets/ohos_list_tile.dart';
export 'src/widgets/ohos_navigation_bar.dart';
export 'src/widgets/ohos_progress_indicator.dart';
export 'src/widgets/ohos_radio.dart';
export 'src/widgets/ohos_scaffold.dart';
export 'src/widgets/ohos_search_bar.dart';
export 'src/widgets/ohos_switch.dart';
export 'src/widgets/ohos_tab_bar.dart';
export 'src/widgets/ohos_text_field.dart';
