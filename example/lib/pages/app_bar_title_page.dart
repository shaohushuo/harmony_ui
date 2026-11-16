import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

import '../demo_frame.dart';
import 'demo_scaffold.dart';

/// 标题栏展示：`titleAlignment` 的三种取值，以及与 Material `AppBar` 的对照。
///
/// 每条栏都画一条 1vp 中轴竖线（主题 `highlightColor`，墨屏下自动退化成
/// 黑/白），用来判断标题是否压在**整条栏**的中线上：
///
/// * `center`（默认）—— 以整条栏为轴居中，居中位置会夹在两侧槽位之间，
///   所以短标题精确压线、长标题贴住 leading，都不会压到按钮上；
/// * `centerBetweenSlots` —— 以「leading 与 actions 之间剩下的空间」为轴，
///   两侧占位不等时标题就会离开中线（0.6.x 的 `center` 就是这个行为）；
/// * `start` —— 左对齐，贴住 leading。
///
/// 演示按「槽位数量」分成三节：三种对齐方式、槽位数量不同、Material 对照。
/// 所有栏都用整条可用宽度，不做定宽裁剪，方便在平板与手机上各看一遍。
class AppBarTitlePage extends StatelessWidget {
  const AppBarTitlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '标题栏展示',
      children: const <Widget>[
        DemoSection(
          title: '三种对齐方式（leading 1 个 / actions 2 个）',
          description:
              '同一组槽位下把三种 titleAlignment 竖着摆一遍：右侧比左侧多一个按钮，'
              'centerBetweenSlots 会把标题推向左（偏差 = (左侧占位 − 右侧占位) / 2），'
              'center 仍压在中轴竖线上，start 则始终贴住 leading。'
              '这一组就是 Issue 12 的来由：0.6.x 的 center 是第二种行为。',
          child: _AlignmentDemo(),
        ),
        DemoSection(
          title: '槽位数量不同：单侧 / 两侧不等 / 长标题',
          description:
              '三组几何各摆「centerBetweenSlots（上）」与「center（下）」：'
              '只有右侧动作、只有左侧返回键、左右个数相差较多。'
              '前两组里 center 会压在中轴竖线上，centerBetweenSlots 明显偏；'
              '第三组用长标题，两者都会把剩余空间填满、退化成贴住 leading —— '
              '所以位置相同，且都不压按钮（窄屏上进一步收成省略号）。',
          child: _SlotCountDemo(),
        ),
        DemoSection(
          title: '与 Material AppBar 对比',
          description:
              'Material 的 AppBar 用 centerTitle: true / leadingWidth 撑开左侧槽位。'
              '它的标题位 = 栏宽 − 两侧 − 2×16vp，居中位置越界就贴住较宽一侧，'
              '所以同样不重叠、也不会塌成 0；我们的 center 用同一套算术，'
              '只少了那 16vp 间隙 —— 于是常规几何下两者的标题都压在中轴竖线上，'
              '极端几何下都贴边收窄。',
          child: _MaterialCompareDemo(),
        ),
      ],
    );
  }
}

// ——— 公共零件 ———

const String _longTitle = '这是一个很长很长的标题文字用来观察是否与两侧按钮重叠';

Widget _icon40(IconData icon) =>
    OhosIconButton(icon: Icon(icon), size: 40, iconSize: 20, onPressed: () {});

Widget _icon48(IconData icon) =>
    OhosIconButton(icon: Icon(icon), onPressed: () {});

Widget _back48() => _icon48(Icons.arrow_back_rounded);

Widget _label(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
  child: Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  ),
);

/// 一条栏：上方说明 + 56vp 栏体 + 贯穿整条栏的中轴竖线。
Widget _barRow(OhosThemeData theme, String caption, Widget bar) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Text(
          caption,
          style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
        ),
      ),
      SizedBox(
        height: 56,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: bar),
            // 整条栏的中轴：标题文字的中心是否压在它上面，就是这条演示的判据。
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: 1,
                  height: double.infinity,
                  child: ColoredBox(color: theme.highlightColor),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _frame(BuildContext context, Widget child) {
  final OhosThemeData theme = OhosTheme.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      border: demoFrameBorder(context, theme),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: child,
      ),
    ),
  );
}

Widget _divider(OhosThemeData theme) =>
    Divider(height: 1, color: theme.dividerColor);

/// `OhosAppBar` 的薄包装：演示里所有栏都关掉自动返回键、不吃状态栏内边距，
/// 左右占位完全由参数决定。
Widget _bar({
  required OhosAppBarTitleAlignment alignment,
  Widget? leading,
  List<Widget>? actions,
  Widget? title,
}) {
  return OhosAppBar(
    primary: false,
    automaticallyImplyLeading: false,
    titleAlignment: alignment,
    leading: leading,
    title: title ?? const Text('标题'),
    actions: actions,
  );
}

// ——— 第一节：三种对齐方式 ———

class _AlignmentDemo extends StatelessWidget {
  const _AlignmentDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Widget leading = _back48();
    final List<Widget> actions = <Widget>[
      _icon48(Icons.share),
      _icon48(Icons.more_horiz),
    ];
    return _frame(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _barRow(
            theme,
            'center（默认）：标题中心压在竖线上',
            _bar(
              alignment: OhosAppBarTitleAlignment.center,
              leading: leading,
              actions: actions,
            ),
          ),
          _divider(theme),
          _barRow(
            theme,
            'centerBetweenSlots：右侧多一个按钮，标题被推向左',
            _bar(
              alignment: OhosAppBarTitleAlignment.centerBetweenSlots,
              leading: leading,
              actions: actions,
            ),
          ),
          _divider(theme),
          _barRow(
            theme,
            'start：左对齐，贴住 leading',
            _bar(
              alignment: OhosAppBarTitleAlignment.start,
              leading: leading,
              actions: actions,
            ),
          ),
        ],
      ),
    );
  }
}

// ——— 第二节：槽位数量不同 ———

class _SlotCountDemo extends StatelessWidget {
  const _SlotCountDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<Widget> threeActions = <Widget>[
      _icon40(Icons.search),
      _icon40(Icons.share),
      _icon40(Icons.more_horiz),
    ];
    return _frame(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _label('① 只有右侧一个 40vp 动作'),
          _pair(
            theme,
            slotsNote: '左偏（剩余空间居中）',
            barCenterNote: '压在中轴竖线上',
            actions: <Widget>[_icon40(Icons.search)],
          ),
          _divider(theme),
          _label('② 只有左侧一个返回键'),
          _pair(
            theme,
            slotsNote: '右偏',
            barCenterNote: '压在中轴竖线上',
            leading: _back48(),
          ),
          _divider(theme),
          _label('③ 左侧 1 个 / 右侧 3 个，长标题'),
          _pair(
            theme,
            slotsNote: '标题填满剩余空间，贴住 leading',
            barCenterNote: '同样贴住 leading —— 与上面一条位置一致',
            leading: _back48(),
            actions: threeActions,
            title: const Text(
              _longTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 一组：centerBetweenSlots 在上、center 在下，两条对比同一几何。
  Widget _pair(
    OhosThemeData theme, {
    required String slotsNote,
    required String barCenterNote,
    Widget? leading,
    List<Widget>? actions,
    Widget? title,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _barRow(
          theme,
          'centerBetweenSlots：$slotsNote',
          _bar(
            alignment: OhosAppBarTitleAlignment.centerBetweenSlots,
            leading: leading,
            actions: actions,
            title: title,
          ),
        ),
        _barRow(
          theme,
          'center：$barCenterNote',
          _bar(
            alignment: OhosAppBarTitleAlignment.center,
            leading: leading,
            actions: actions,
            title: title,
          ),
        ),
      ],
    );
  }
}

// ——— 第三节：Material 对照 ———

class _MaterialCompareDemo extends StatelessWidget {
  const _MaterialCompareDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return _frame(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _label('① leading 1 个 / actions 2 个（短标题）'),
          _barRow(
            theme,
            'Material AppBar（centerTitle: true）：标题压在中轴竖线上',
            _materialBar(
              theme,
              leadingIcons: <IconData>[Icons.arrow_back_rounded],
              actionIcons: <IconData>[Icons.share, Icons.more_horiz],
            ),
          ),
          _barRow(
            theme,
            'OhosAppBar center：同样压在中轴竖线上',
            _bar(
              alignment: OhosAppBarTitleAlignment.center,
              leading: _back48(),
              actions: <Widget>[_icon48(Icons.share), _icon48(Icons.more_horiz)],
            ),
          ),
          _divider(theme),
          _label('② leading 2 个 / actions 4 个（长标题，看是否重叠）'),
          _barRow(
            theme,
            'Material AppBar：标题收成省略号并贴住 leading + 16vp 间隙，不重叠',
            _materialBar(
              theme,
              leadingIcons: <IconData>[Icons.search, Icons.share],
              actionIcons: <IconData>[
                Icons.settings,
                Icons.help_outline,
                Icons.favorite_border,
                Icons.more_horiz,
              ],
              title: const Text(
                _longTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _barRow(
            theme,
            'OhosAppBar center：同样收窄贴边，不重叠（少掉 16vp 间隙，字略多一点）',
            _bar(
              alignment: OhosAppBarTitleAlignment.center,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[_icon48(Icons.search), _icon48(Icons.share)],
              ),
              actions: <Widget>[
                _icon48(Icons.settings),
                _icon48(Icons.help_outline),
                _icon48(Icons.favorite_border),
                _icon48(Icons.more_horiz),
              ],
              title: const Text(
                _longTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Material 的参照实现。
  ///
  /// `leadingWidth` 要显式给足（默认 56 只够一个按钮），`primary: false`
  /// 才不吃状态栏内边距，几何才能和下面的 ohos 栏对齐。
  Widget _materialBar(
    OhosThemeData theme, {
    required List<IconData> leadingIcons,
    required List<IconData> actionIcons,
    Widget? title,
  }) {
    return AppBar(
      primary: false,
      centerTitle: true,
      leadingWidth: leadingIcons.length * 48.0,
      backgroundColor: theme.backgroundColor,
      foregroundColor: theme.textPrimaryColor,
      elevation: 0,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final IconData icon in leadingIcons)
            IconButton(icon: Icon(icon), onPressed: () {}),
        ],
      ),
      title: title ?? const Text('标题'),
      actions: <Widget>[
        for (final IconData icon in actionIcons)
          IconButton(icon: Icon(icon), onPressed: () {}),
      ],
    );
  }
}
