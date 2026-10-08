import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// UI Design Kit 增强：点光源 / 按压阴影 / 侧边栏 / 横滑列表项 / 常驻通知 /
/// 分割线跟手 / 颜色选择器三模式 / 动态模糊标题栏 / 可展开操作栏 /
/// 分层图标 / 多窗入口
class KitPage extends StatelessWidget {
  const KitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'UI Design Kit',
      children: const <Widget>[
        DemoSection(
          title: '点光源效果 OhosLightSource / OhosIlluminated',
          description: '点击中心按钮，切换受光类型：NONE / BORDER / CONTENT / BORDER_CONTENT / 羽化描边。',
          child: _PointLightDemo(),
        ),
        DemoSection(
          title: '按压阴影 OhosPressShadow',
          description: '按压时呈现 BLEND_WHITE（白色混合）或 BLEND_GRADIENT（指尖径向渐变）。',
          child: _PressShadowDemo(),
        ),
        DemoSection(
          title: '侧边栏 OhosSideBar + OhosSideMenu',
          description: 'overlay 模式侧边栏 + 一二级菜单与红点提醒。',
          child: _SideBarDemo(),
        ),
        DemoSection(
          title: '横滑列表项 OhosListItem',
          description: '左滑显示操作按钮，支持整划删除（fullDelete）。',
          child: _SwipeListDemo(),
        ),
        DemoSection(
          title: '常驻通知 OhosSnackBar（resident）',
          description: 'duration -1 语义：常驻弹窗带关闭按钮；也支持图标 + 标题 + 描述。',
          child: _SnackBarKitDemo(),
        ),
        DemoSection(
          title: '子页签分割线 OhosTabBar（常显/常隐/跟手）',
          description: '跟手模式下，分割线随列表滚动淡入。',
          child: _TabDividerDemo(),
        ),
        DemoSection(
          title: '颜色选择器 OhosColorPicker（网格/光谱/滑块 + 收藏）',
          description: '三种模式与收藏切换。',
          child: _ColorPickerKitDemo(),
        ),
        DemoSection(
          title: '动态模糊标题栏 OhosAppBar（scrollEffect）',
          description: '内容穿透标题栏，滚动时通用模糊背板淡入。',
          child: _BlurAppBarDemo(),
        ),
        DemoSection(
          title: '可展开操作栏 OhosActionBar（expandable）',
          description: '点击主按钮收起/展开次级操作。',
          child: _ExpandableActionBarDemo(),
        ),
        DemoSection(
          title: '分层图标 OhosLayeredIcon',
          description: '背景板 + 前景合成，支持缩放与描边。',
          child: _LayeredIconDemo(),
        ),
        DemoSection(
          title: '应用内多窗入口 OhosMultiWindowEntry',
          description: '图标 + 文字样式的多窗入口。',
          child: _MultiWindowDemo(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 点光源
// ---------------------------------------------------------------------------

class _PointLightDemo extends StatefulWidget {
  const _PointLightDemo();

  @override
  State<_PointLightDemo> createState() => _PointLightDemoState();
}

class _PointLightDemoState extends State<_PointLightDemo> {
  static const List<OhosPointLightIlluminatedType> _types =
      <OhosPointLightIlluminatedType>[
        OhosPointLightIlluminatedType.none,
        OhosPointLightIlluminatedType.border,
        OhosPointLightIlluminatedType.content,
        OhosPointLightIlluminatedType.borderContent,
        OhosPointLightIlluminatedType.defaultFeatheringBorder,
      ];
  static const List<String> _labels = <String>[
    'NONE',
    'BORDER',
    'CONTENT',
    'BORDER_CONTENT',
    'DEFAULT_FEATHERING_BORDER',
  ];
  int _index = 1;
  double _intensity = 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OhosCard(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101418),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    for (int row = 0; row < 4; row++) _gridRow(row),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _toneChip(
                label: '受光: ${_labels[_index]}',
                onTap: () => setState(() {
                  _index = (_index + 1) % _types.length;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toneChip(
                label: '强度: ${_intensity.round()}',
                onTap: () => setState(() {
                  _intensity = _intensity >= 20 ? 10 : _intensity + 5;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridRow(int row) {
    return Row(
      children: <Widget>[
        for (int col = 0; col < 4; col++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: _lightCell(row, col),
            ),
          ),
      ],
    );
  }

  Widget _lightCell(int row, int col) {
    final bool isCenter = row == 1 && col == 1;
    if (isCenter) {
      // 发光源：点击切换受光类型（ArkUI 示例语义）。
      return GestureDetector(
        onTap: () => setState(() {
          _index = (_index + 1) % _types.length;
        }),
        child: const SizedBox(
          height: 44,
          child: Center(
            child: OhosLightSource(
              size: 34,
              options: OhosPointLightOptions(intensity: 10, height: 150),
            ),
          ),
        ),
      );
    }
    final double dx = ((col - 1.5) / 1.5).clamp(-1.0, 1.0);
    final double dy = ((row - 1.5) / 1.5).clamp(-1.0, 1.0);
    return SizedBox(
      height: 44,
      child: OhosIlluminated(
        illuminatedType: _types[_index],
        lightAlignment: Alignment(dx, dy),
        options: OhosPointLightOptions(
          color: Colors.white,
          intensity: _intensity,
          height: 150,
        ),
        borderRadius: BorderRadius.circular(22),
        clipContent: false,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF808080),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _toneChip({required String label, required VoidCallback onTap}) {
    final OhosThemeData theme = OhosTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.emphasizeSecondaryColor ??
              theme.highlightColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.typography.labelSmall?.copyWith(
            color: theme.highlightColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 按压阴影
// ---------------------------------------------------------------------------

class _PressShadowDemo extends StatelessWidget {
  const _PressShadowDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        OhosPressShadow(
          type: OhosPressShadowType.blendWhite,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 132,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.highlightColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'BLEND_WHITE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        OhosPressShadow(
          type: OhosPressShadowType.blendGradient,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 132,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF8A8A8E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'BLEND_GRADIENT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 侧边栏 + 侧边菜单
// ---------------------------------------------------------------------------

class _SideBarDemo extends StatefulWidget {
  const _SideBarDemo();

  @override
  State<_SideBarDemo> createState() => _SideBarDemoState();
}

class _SideBarDemoState extends State<_SideBarDemo> {
  bool _showSideBar = true;
  String? _selected = '收件箱';

  static const List<OhosSideMenuItem> _items = <OhosSideMenuItem>[
    OhosSideMenuItem(label: '收件箱', icon: Icon(Icons.mail_outline_rounded)),
    OhosSideMenuItem(
      label: '消息',
      icon: Icon(Icons.chat_bubble_outline_rounded),
      badgeCount: 8,
      subItems: <OhosSideMenuSubItem>[
        OhosSideMenuSubItem(label: '短信', badgeCount: 50),
        OhosSideMenuSubItem(label: '通知'),
        OhosSideMenuSubItem(label: '评论', badgeCount: 3),
      ],
    ),
    OhosSideMenuItem(label: '日程', icon: Icon(Icons.calendar_today_rounded)),
    OhosSideMenuItem(label: '设置', icon: Icon(Icons.settings_outlined)),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '当前选中: $_selected',
                style: theme.typography.bodyMedium,
              ),
            ),
            OhosButton(
              onPressed: () => setState(() => _showSideBar = !_showSideBar),
              style: OhosButtonStyle.tonal,
              child: Text(_showSideBar ? '收起侧边栏' : '展开侧边栏'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: OhosSideBar(
            isShowSideBar: _showSideBar,
            onIsShowSideBarChanged: (bool v) => setState(() => _showSideBar = v),
            overlay: true,
            contentAreaMask: false,
            width: 230,
            sideBar: OhosSideMenu(
              items: _items,
              selectedValue: _selected,
              onSelected: (String v) => setState(() => _selected = v),
            ),
            content: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('内容区：模拟主界面', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 横滑列表项
// ---------------------------------------------------------------------------

class _SwipeListDemo extends StatefulWidget {
  const _SwipeListDemo();

  @override
  State<_SwipeListDemo> createState() => _SwipeListDemoState();
}

class _SwipeListDemoState extends State<_SwipeListDemo> {
  final List<String> _rows = <String>['Primary Text 1', 'Primary Text 2', 'Primary Text 3'];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      children: <Widget>[
        for (int i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OhosListItem(
              borderRadius: BorderRadius.circular(16),
              fullDelete: i == _rows.length - 1,
              onFullDelete: () => setState(() => _rows.removeAt(i)),
              actions: <OhosSwipeAction>[
                OhosSwipeAction(
                  icon: const Icon(Icons.share_rounded),
                  backgroundColor: const Color(0xFF64BB5C),
                  foregroundColor: Colors.white,
                  onTap: () => showOhosToast(context, '点击分享'),
                ),
                OhosSwipeAction(
                  icon: const Icon(Icons.copy_rounded),
                  backgroundColor: const Color(0xFFED6F21),
                  foregroundColor: Colors.white,
                  onTap: () => showOhosToast(context, '点击复制'),
                ),
                OhosSwipeAction(
                  icon: const Icon(Icons.delete_outline_rounded),
                  backgroundColor: theme.dangerColor,
                  foregroundColor: Colors.white,
                  onTap: () => setState(() => _rows.removeAt(i)),
                ),
              ],
              child: Container(
                height: 64,
                color: theme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.drive_file_move_rounded, color: theme.textSecondaryColor),
                    const SizedBox(width: 12),
                    Text(_rows[i], style: theme.typography.bodyMedium),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: theme.textTertiaryColor),
                  ],
                ),
              ),
            ),
          ),
        if (_rows.isEmpty)
          Text(
            '列表已清空（第 3 行整划删除）',
            style: theme.typography.bodySmall?.copyWith(color: theme.textSecondaryColor),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SnackBar 常驻
// ---------------------------------------------------------------------------

class _SnackBarKitDemo extends StatelessWidget {
  const _SnackBarKitDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        OhosButton(
          onPressed: () => showOhosSnackBar(
            context,
            resident: true,
            icon: const Icon(Icons.wifi_off_rounded),
            title: 'Wi-Fi 已断开',
            content: '请检查网络后重试',
          ),
          style: OhosButtonStyle.tonal,
          child: const Text('常驻通知（带关闭）'),
        ),
        OhosButton(
          onPressed: () => showOhosSnackBar(
            context,
            icon: const Icon(Icons.cloud_done_rounded),
            title: '已同步',
            content: '3 个文件已同步到云端',
          ),
          style: OhosButtonStyle.tonal,
          child: const Text('图标 + 标题 + 描述'),
        ),
        OhosButton(
          onPressed: () => showOhosSnackBar(
            context,
            message: '已删除 1 个文件',
            actionLabel: '撤销',
            onAction: () => showOhosToast(context, '已撤销'),
          ),
          style: OhosButtonStyle.tonal,
          child: const Text('传统 + 撤销'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TabBar 分割线
// ---------------------------------------------------------------------------

class _TabDividerDemo extends StatefulWidget {
  const _TabDividerDemo();

  @override
  State<_TabDividerDemo> createState() => _TabDividerDemoState();
}

class _TabDividerDemoState extends State<_TabDividerDemo> {
  final ScrollController _scroller = ScrollController();
  OhosTabBarDividerMode _mode = OhosTabBarDividerMode.followScroll;

  @override
  void dispose() {
    _scroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      children: <Widget>[
        OhosCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              for (final OhosTabBarDividerMode mode in OhosTabBarDividerMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      switch (mode) {
                        OhosTabBarDividerMode.visible => '常显',
                        OhosTabBarDividerMode.none => '常隐',
                        OhosTabBarDividerMode.followScroll => '跟手',
                      },
                    ),
                    selected: _mode == mode,
                    onSelected: (_) => setState(() => _mode = mode),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DefaultTabController(
          length: 3,
          child: Column(
            children: <Widget>[
              OhosTabBar(
                tabs: const <Widget>[Tab(text: '推荐'), Tab(text: '关注'), Tab(text: '热榜')],
                divider: OhosTabBarDividerOptions(mode: _mode),
                scrollController: _mode == OhosTabBarDividerMode.followScroll
                    ? _scroller
                    : null,
              ),
              Container(
                height: 180,
                color: theme.compBackgroundGrayColor ??
                    theme.textPrimaryColor.withValues(alpha: 0.06),
                child: TabBarView(
                  children: <Widget>[
                    _scrollList(0),
                    _scrollList(1),
                    _scrollList(2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scrollList(int page) {
    return ListView(
      controller: _scroller,
      padding: const EdgeInsets.all(6),
      children: <Widget>[
        for (int i = 0; i < 20; i++)
          Container(
            height: 56,
            margin: const EdgeInsets.only(bottom: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('第 $page 页 · item $i · 向下滚动观察分割线'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 颜色选择器
// ---------------------------------------------------------------------------

class _ColorPickerKitDemo extends StatefulWidget {
  const _ColorPickerKitDemo();

  @override
  State<_ColorPickerKitDemo> createState() => _ColorPickerKitDemoState();
}

class _ColorPickerKitDemoState extends State<_ColorPickerKitDemo> {
  Color _color = const Color(0xFF0A59F7);
  final List<Color> _favorites = <Color>[
    const Color(0xFF0A59F7),
    const Color(0xFF27B440),
    const Color(0xFFE84026),
  ];

  static const List<Color> _palette = <Color>[
    Color(0xFF0A59F7),
    Color(0xFF27B440),
    Color(0xFFFF8F1F),
    Color(0xFFE84026),
    Color(0xFFAA2ED1),
    Color(0xFF2CC2C9),
    Color(0xFF8A8A8E),
    Color(0xFF17181A),
    Color(0xFFF7CE00),
    Color(0xFFE55392),
    Color(0xFF7C8DF7),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return OhosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '当前: ${_color.toARGB32().toRadixString(16).padLeft(8, '0')}',
                style: theme.typography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          OhosColorPicker(
            colors: _palette,
            selectedColor: _color,
            onChanged: (Color c) => setState(() => _color = c),
            tabs: const <OhosColorPickerTab>[
              OhosColorPickerTab.grid,
              OhosColorPickerTab.spectrum,
              OhosColorPickerTab.sliders,
            ],
            favoriteColors: _favorites,
            onFavoritesChanged: (List<Color> c) =>
                setState(() => _favorites
                  ..clear()
                  ..addAll(c)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 动态模糊标题栏
// ---------------------------------------------------------------------------

class _BlurAppBarDemo extends StatefulWidget {
  const _BlurAppBarDemo();

  @override
  State<_BlurAppBarDemo> createState() => _BlurAppBarDemoState();
}

class _BlurAppBarDemoState extends State<_BlurAppBarDemo> {
  final ScrollController _scroller = ScrollController();

  @override
  void dispose() {
    _scroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ListView(
                controller: _scroller,
                padding: const EdgeInsets.only(top: 56),
                children: <Widget>[
                  for (int i = 0; i < 24; i++)
                    Container(
                      height: 72,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A59F7)
                            .withValues(alpha: 0.10 + (i % 3) * 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'content item $i',
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OhosAppBar(
                backgroundColor: Colors.transparent,
                title: const Text('通用模糊标题栏'),
                scrollEffect: const OhosAppBarScrollEffectOptions(
                  effect: OhosAppBarScrollEffectType.commonBlur,
                  blurEffectiveStartOffset: 0,
                  blurEffectiveEndOffset: 60,
                  blurSigma: 10,
                ),
                scrollController: _scroller,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 可展开操作栏
// ---------------------------------------------------------------------------

class _ExpandableActionBarDemo extends StatefulWidget {
  const _ExpandableActionBarDemo();

  @override
  State<_ExpandableActionBarDemo> createState() => _ExpandableActionBarDemoState();
}

class _ExpandableActionBarDemoState extends State<_ExpandableActionBarDemo> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F3F5),
      height: 88,
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          OhosActionBar(
            expandable: true,
            isExpanded: _expanded,
            onIsExpandedChanged: (bool v) => setState(() => _expanded = v),
            secondaryActions: const <Widget>[
              OhosIconButton(
                icon: Icon(Icons.timer_outlined),
                tooltip: '计时',
              ),
              OhosIconButton(
                icon: Icon(Icons.mic_none_rounded),
                tooltip: '录音',
              ),
              OhosIconButton(
                icon: Icon(Icons.more_horiz_rounded),
                tooltip: '更多',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 分层图标
// ---------------------------------------------------------------------------

class _LayeredIconDemo extends StatelessWidget {
  const _LayeredIconDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: <Widget>[
        OhosLayeredIcon(
          size: 56,
          background: theme.highlightColor.withValues(alpha: 0.12),
          foreground: Icon(Icons.photo_camera_outlined, color: theme.highlightColor),
        ),
        OhosLayeredIcon(
          size: 56,
          background: const Color(0xFF27B440).withValues(alpha: 0.12),
          foreground: const Icon(Icons.videocam_outlined, color: Color(0xFF27B440)),
        ),
        OhosLayeredIcon(
          size: 56,
          background: const Color(0xFFED6F21).withValues(alpha: 0.12),
          foreground: const Icon(Icons.music_note_rounded, color: Color(0xFFED6F21)),
          borderColor: theme.dividerColor,
        ),
        OhosLayeredIcon(
          size: 56,
          background: const Color(0xFFAA2ED1).withValues(alpha: 0.12),
          foreground: const Icon(Icons.star_rounded, color: Color(0xFFAA2ED1)),
          padding: 8,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 多窗入口
// ---------------------------------------------------------------------------

class _MultiWindowDemo extends StatelessWidget {
  const _MultiWindowDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      children: const <Widget>[
        OhosMultiWindowEntry(
          icon: Icon(Icons.article_outlined),
          subtitle: '文档',
          onTap: _nullVoid,
        ),
        OhosMultiWindowEntry(
          icon: Icon(Icons.calculate_outlined),
          subtitle: '计算器',
        ),
        OhosMultiWindowEntry(
          icon: Icon(Icons.shopping_bag_outlined),
          subtitle: '购物',
          enabled: false,
        ),
      ],
    );
  }
}

void _nullVoid() {}
