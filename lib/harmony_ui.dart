/// harmony_ui — a Material/Cupertino-style widget library that implements the
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
export 'src/widgets/ohos_action_bar.dart';
export 'src/widgets/ohos_alert_dialog.dart';
export 'src/widgets/ohos_alphabet_indexer.dart';
export 'src/widgets/ohos_app_bar.dart';
export 'src/widgets/ohos_badge.dart';
export 'src/widgets/ohos_blank.dart';
export 'src/widgets/ohos_bottom_sheet.dart';
export 'src/widgets/ohos_chip_group.dart';
export 'src/widgets/ohos_light_material.dart';
export 'src/widgets/ohos_responsive.dart';
export 'src/widgets/ohos_button.dart';
export 'src/widgets/ohos_card.dart';
export 'src/widgets/ohos_checkbox.dart';
export 'src/widgets/ohos_chip.dart';
export 'src/widgets/ohos_color_picker.dart';
export 'src/widgets/ohos_counter.dart';
export 'src/widgets/ohos_data_panel.dart';
export 'src/widgets/ohos_divider.dart';
export 'src/widgets/ohos_icon_button.dart';
export 'src/widgets/ohos_image.dart';
export 'src/widgets/ohos_list.dart';
export 'src/widgets/ohos_list_tile.dart';
export 'src/widgets/ohos_menu.dart';
export 'src/widgets/ohos_navigation_bar.dart';
export 'src/widgets/ohos_pattern_lock.dart';
export 'src/widgets/ohos_picker.dart';
export 'src/widgets/ohos_popup.dart';
export 'src/widgets/ohos_progress_indicator.dart';
export 'src/widgets/ohos_qr_code.dart';
export 'src/widgets/ohos_radio.dart';
export 'src/widgets/ohos_rating_bar.dart';
export 'src/widgets/ohos_scaffold.dart';
export 'src/widgets/ohos_scrollbar.dart';
export 'src/widgets/ohos_search_bar.dart';
export 'src/widgets/ohos_segmented_button.dart';
export 'src/widgets/ohos_select.dart';
export 'src/widgets/ohos_slider.dart';
export 'src/widgets/ohos_snack_bar.dart';
export 'src/widgets/ohos_swiper.dart';
export 'src/widgets/ohos_side_menu.dart';
export 'src/widgets/ohos_side_bar.dart';
export 'src/widgets/ohos_press_shadow.dart';
export 'src/widgets/ohos_point_light.dart';
export 'src/widgets/ohos_multi_window_entry.dart';
export 'src/widgets/ohos_list_item.dart';
export 'src/widgets/ohos_layered_icon.dart';
export 'src/widgets/ohos_switch.dart';
export 'src/widgets/ohos_tab_bar.dart';
export 'src/widgets/ohos_text.dart';
export 'src/widgets/ohos_text_clock.dart';
export 'src/widgets/ohos_text_field.dart';
export 'src/widgets/ohos_toast.dart';
export 'src/widgets/ohos_toggle_button.dart';
export 'src/widgets/ohos_toolbar.dart';
