import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 对照页：`OhosScaffold.body` 里再套 `SafeArea` 不该叠出第二份安全区。
///
/// 两栏内容完全一样，右栏只是多包了一层 `SafeArea`：
/// * 修复后：两栏的「顶」「底」条紧贴栏体上下边，栏内读到的
///   `MediaQuery.padding` 四边都是 0（几何已经由页面容器让过）；
/// * 修复前：右栏的「顶」被状态栏高度再推开一段、「底」被手势条推开一段，
///   而左栏读到的仍是真实内边距。
///
/// 桌面 / 窗口里真实内边距是 0（两栏都会齐平，看不出差别），所以默认打开
/// 「模拟安全区」注入 24 / 16vp；真机上关掉开关看的就是系统给的真实值。
class SafeAreaPage extends StatefulWidget {
  const SafeAreaPage({super.key});

  @override
  State<SafeAreaPage> createState() => _SafeAreaPageState();
}

class _SafeAreaPageState extends State<SafeAreaPage> {
  bool? _simulate;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 首帧按真实内边距决定：真机（有内边距）默认关，桌面 / 窗口默认开。
    final bool simulate = _simulate ?? MediaQuery.paddingOf(context).top == 0;

    Widget page = OhosScaffold(
      appBar: const OhosAppBar(title: Text('body 内层 SafeArea')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    simulate
                        ? '模拟安全区：top 24 / bottom 16（窗口里真实内边距为 0）'
                        : '使用系统真实安全区',
                    style: theme.typography.bodySmall?.copyWith(
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ),
                OhosSwitch(
                  value: simulate,
                  onChanged: (bool value) => setState(() => _simulate = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '两栏内容相同，右栏只多包一层 SafeArea。两条「顶」应齐平、两条「底」'
              '也应齐平；栏内数字是本栏看到的 MediaQuery.padding。',
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _Pane(label: '直接放内容', wrapInSafeArea: false),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _Pane(label: '再套 SafeArea', wrapInSafeArea: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (simulate) {
      // 注在 `OhosScaffold` **外面**：容器才会把它当成系统安全区，四条边各让
      // 一次；注在 body 里就测不到「容器让过、子树该看到 0」这件事了。
      page = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: page,
      );
    }
    return page;
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.label, required this.wrapInSafeArea});

  final String label;
  final bool wrapInSafeArea;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _EdgeBand(text: '顶'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.typography.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const _PaddingReadout(),
              ],
            ),
          ),
        ),
        const _EdgeBand(text: '底'),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border.all(
            color: theme.textTertiaryColor.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        // 关键：只有右栏多这一层，它不该再让出任何内边距。
        child: wrapInSafeArea ? SafeArea(child: content) : content,
      ),
    );
  }
}

class _EdgeBand extends StatelessWidget {
  const _EdgeBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      height: 30,
      alignment: Alignment.center,
      color: theme.highlightColor,
      child: Text(
        text,
        style: theme.typography.bodySmall?.copyWith(
          color: theme.backgroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 本栏（若套了 `SafeArea`，则是它**内部**）读到的安全区内边距。
class _PaddingReadout extends StatelessWidget {
  const _PaddingReadout();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    String value(double v) => v == 0 ? '0' : v.toStringAsFixed(0);
    return Text(
      'MediaQuery.padding\n'
      'top ${value(padding.top)}  bottom ${value(padding.bottom)}\n'
      'left ${value(padding.left)}  right ${value(padding.right)}',
      textAlign: TextAlign.center,
      style: theme.typography.bodySmall?.copyWith(
        color: theme.textSecondaryColor,
      ),
    );
  }
}
