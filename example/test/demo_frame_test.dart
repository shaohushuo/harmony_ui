import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:ohos_ui_example/demo_frame.dart';

/// 示例容器的外框线：墨主题必须落到纯黑。
///
/// 原来直接写 `textTertiaryColor.withValues(alpha: 0.4)`，在 16 级灰上被压成
/// 两三档浅灰、化进背景，真机上表现为「示例缺了左上右的边框」。
void main() {
  test('墨主题下示例外框用分割色（纯黑）', () {
    final OhosThemeData ink = OhosThemeData.ink();
    expect(demoFrameColor(ink), ink.dividerColor);
    expect(demoFrameColor(ink).computeLuminance(), 0);
  });

  test('彩屏沿用 10% 黑细线，不跟着改深', () {
    for (final OhosThemeData theme in <OhosThemeData>[
      OhosThemeData.light(),
      OhosThemeData.dark(),
    ]) {
      expect(
        demoFrameColor(theme),
        theme.textTertiaryColor.withValues(alpha: 0.4),
      );
      expect(theme.monochrome, isFalse);
    }
  });
}
