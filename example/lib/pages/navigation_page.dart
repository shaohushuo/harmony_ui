import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import '../demo_frame.dart';
import 'demo_scaffold.dart';
import 'safe_area_page.dart';

/// 导航类：标题栏 / 子页签（下划线 + 胶囊）/ 底部页签 / 导航点（轮播）
class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '导航类',
      children: <Widget>[
        const DemoSection(
          title: '标题栏 OhosAppBar（状态栏内边距 primary）',
          description:
              '沉浸式（edge-to-edge）下系统状态栏会直接压在顶栏上。primary 为 true（默认）时'
              '组件自己吃掉 MediaQuery.padding.top：背景仍铺到屏幕最顶端，标题与动作下移到'
              '状态栏下面 —— 栏高变成 height + inset。示例里注入 24vp 模拟状态栏'
              '（真机上这个值由系统给出），下面对照 80vp / 56vp 两种高度。',
          child: _StatusBarInsetDemo(),
        ),
        const DemoSection(
          title: '安全区：body 里再套 SafeArea 不叠第二份',
          description:
              'OhosScaffold 已把四条边的安全区让成几何，并从 body 子树的 MediaQuery 里摘掉，'
              '所以 body 里再包一层 SafeArea 是空操作。点开对照页：两栏的「顶」「底」条应齐平，'
              '栏内读到的 padding 四边都是 0。',
          child: _SafeAreaDemoEntry(),
        ),
        const DemoSection(
          title: '标题栏 OhosAppBar（沉浸光感）',
          description: 'lightMaterial 开启后使用 ULTRA_THIN 材质 + 顶部渐变模糊。',
          child: _LightAppBarDemo(),
        ),
        const DemoSection(
          title: '标题栏 OhosAppBar（对齐 / bottom / 标题位放控件）',
          description:
              'titleAlignment.start 换成左对齐标题（鸿蒙列表页 / 详情页常见），'
              'titlePadding 可把两侧留白收紧，bottom 直接挂一条 OhosTabBar（高度并入 '
              'preferredSize），标题位也可以整块换成搜索框（titlePadding: zero）。',
          child: _AppBarSlotsDemo(),
        ),
        const DemoSection(
          title: '标题栏 OhosAppBar（状态栏分段着色 / heightOf）',
          description:
              'statusBarBackgroundColor 把背景拆成「状态栏段 + 工具栏段」：沉浸式页面'
              '常见的「状态栏 = 页面底色、工具栏 = 卡片色」。内边距仍由组件吸收，'
              'preferredSize 与总高都不变；heightOf 给出含状态栏内边距的总高，'
              '自己包顶栏时不必再手算。',
          child: _StatusBarColorDemo(),
        ),
        const DemoSection(
          title: '子页签 OhosTabBar（下划线样式）',
          description: '指示条 24x3vp，激活项品牌色，底部背景色填充与页面一致。',
          child: _TabBarDemo(type: OhosTabBarType.underline),
        ),
        const DemoSection(
          title: '子页签 OhosTabBar（胶囊样式）',
          description: '激活项品牌色填充，未激活项灰色背景 comp_background_gray，间距 8vp。',
          child: _TabBarDemo(type: OhosTabBarType.capsule),
        ),
        const DemoSection(
          title: '胶囊子页签 OhosChipGroup（多选）',
          description: 'ChipGroup 支持多选规格，普通/小尺寸两种规格。',
          child: _ChipGroupDemo(),
        ),
        const DemoSection(
          title: '底部页签 OhosNavigationBar（平铺式 48vp）',
          description: '激活项 20% 品牌色高亮胶囊，图标 24vp，未激活文字置于图标下方。',
          child: _NavigationBarDemo(type: OhosNavigationBarType.tile),
        ),
        const DemoSection(
          title: '底部页签 OhosNavigationBar（悬浮式 56vp）',
          description: '悬浮胶囊 + 沉浸光感：光池跟随选中项，按压出现指尖光晕与彩色焦散。',
          child: _NavigationBarDemo(type: OhosNavigationBarType.float),
        ),
        const DemoSection(
          title: '导航点 OhosPageIndicator',
          description: '配合轮播 OhosSwiper 使用，支持自动播放。',
          child: _SwiperDemo(),
        ),
      ],
    );
  }
}

/// 打开整屏对照页：两栏只有「body 里是否多包一层 SafeArea」这一个差别。
class _SafeAreaDemoEntry extends StatelessWidget {
  const _SafeAreaDemoEntry();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OhosButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SafeAreaPage()),
        ),
        child: const Text('打开对照页'),
      ),
    );
  }
}

/// 对照 [OhosAppBar.primary]：上面那条自己让开状态栏，下面那条不管。
///
/// 示例运行在桌面 / 平板窗口里，真实状态栏内边距是 0，所以这里用
/// `MediaQuery.copyWith(padding: …)` 注入 24vp —— 只是为了让两条的高度差
/// （80 vs 56）在 gallery 里也看得见。
class _StatusBarInsetDemo extends StatelessWidget {
  const _StatusBarInsetDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 24),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: demoFrameBorder(context, theme),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _bar(context, primary: true, caption: 'primary: true（默认）· 高 80vp'),
              Divider(height: 1, color: demoFrameColor(theme)),
              _bar(context, primary: false, caption: 'primary: false · 高 56vp'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context, {
    required bool primary,
    required String caption,
  }) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Text(
            caption,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
          ),
        ),
        OhosAppBar(
          primary: primary,
          title: const Text('标题'),
          actions: <Widget>[
            OhosIconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              size: 40,
              iconSize: 20,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// [OhosAppBar.statusBarBackgroundColor] 与 [OhosAppBar.heightOf]。
///
/// 和 [_StatusBarInsetDemo] 一样注入 24vp 模拟状态栏：真机上这个内边距由系统
/// 给出，gallery 的示例卡片不在屏幕顶部，不注入就看不见那条色带。
class _StatusBarColorDemo extends StatelessWidget {
  const _StatusBarColorDemo();

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 24),
      ),
      child: const _StatusBarColorDemoBody(),
    );
  }
}

/// 顶栏本体。放在 `MediaQuery` 之下是因为 [OhosAppBar.heightOf] 要读同一条
/// 内边距 —— 用外层 context 调它只会拿到注入前的 0。
class _StatusBarColorDemoBody extends StatelessWidget {
  const _StatusBarColorDemoBody();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final double total = OhosAppBar.heightOf(context, height: 56);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _framed(
          context,
          caption: '默认：一段式背景，状态栏那条与工具栏同色',
          bar: const OhosAppBar(
            // 这个示例故意用固定白底（演示 backgroundColor 覆盖），标题就也
            // 固定深色 —— 否则深色主题下是白底白字。
            title: Text('消息', style: TextStyle(color: OhosColors.textPrimaryLight)),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _framed(
          context,
          caption: 'statusBarBackgroundColor：状态栏 = 页面底色，工具栏 = 卡片色',
          bar: const OhosAppBar(
            title: Text('消息', style: TextStyle(color: OhosColors.textPrimaryLight)),
            backgroundColor: Colors.white,
            statusBarBackgroundColor: Color(0xFFE8EBF0),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'heightOf(context, height: 56) = ${total.toStringAsFixed(0)}vp'
          '（56 工具栏 + ${(total - 56).toStringAsFixed(0)} 状态栏内边距），'
          'preferredSize 仍是 56vp',
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _framed(BuildContext context, {required String caption, required OhosAppBar bar}) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          caption,
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            border: demoFrameBorder(context, theme),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: bar,
          ),
        ),
      ],
    );
  }
}

class _LightAppBarDemo extends StatelessWidget {
  const _LightAppBarDemo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: 160,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0A59F7), Color(0xFF61CFBE)],
            ),
          ),
          child: Center(
            child: Text(
              '沉浸光感\nULTRA_THIN + 渐变模糊',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: OhosLightMaterial(
            level: OhosLightMaterialLevel.ultraThin,
            gradientFade: OhosLightFade.top,
            child: OhosAppBar(
              lightMaterial: true,
              title: Text('悬浮标题栏'),
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶栏四个缺口（对齐 / 内边距 / bottom / 标题位放控件）落地后的样子。
class _AppBarSlotsDemo extends StatefulWidget {
  const _AppBarSlotsDemo();

  @override
  State<_AppBarSlotsDemo> createState() => _AppBarSlotsDemoState();
}

class _AppBarSlotsDemoState extends State<_AppBarSlotsDemo>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: demoFrameBorder(context, theme),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OhosAppBar(
              primary: false,
              titleAlignment: OhosAppBarTitleAlignment.start,
              leading: OhosIconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {},
              ),
              title: const Text('仓库 · feature/appbar'),
              actions: <Widget>[
                OhosIconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ],
              bottom: OhosTabBar(
                controller: _tabs,
                tabs: const <Widget>[
                  Text('文件'),
                  Text('提交'),
                  Text('分支'),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            OhosAppBar(
              primary: false,
              height: 60,
              titlePadding: EdgeInsets.zero,
              leading: OhosIconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {},
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: OhosSearchBar(
                  hintText: '搜索文件',
                  onChanged: (String value) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDemo extends StatelessWidget {
  const _TabBarDemo({required this.type});

  final OhosTabBarType type;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          OhosTabBar(
            type: type,
            tabs: const <Widget>[
              Tab(text: '推荐'),
              Tab(text: '关注'),
              Tab(text: '热榜'),
            ],
          ),
          Container(
            height: 76,
            color: OhosColors.compBackgroundGray,
            child: TabBarView(
              children: <Widget>[
                _tabHint('推荐内容'),
                _tabHint('关注内容'),
                _tabHint('热榜内容'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabHint(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: OhosColors.textSecondaryLight),
      ),
    );
  }
}

class _ChipGroupDemo extends StatefulWidget {
  const _ChipGroupDemo();

  @override
  State<_ChipGroupDemo> createState() => _ChipGroupDemoState();
}

class _ChipGroupDemoState extends State<_ChipGroupDemo> {
  Set<int> _selected = <int>{0};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OhosChipGroup(
          multiple: true,
          selectedIndexes: _selected,
          onSelectionChanged: (Set<int> s) => setState(() => _selected = s),
          items: const <OhosChipItem>[
            OhosChipItem(label: Text('音乐'), icon: Icon(OhosIcons.music_fill)),
            OhosChipItem(label: Text('视频'), icon: Icon(OhosIcons.video)),
            OhosChipItem(label: Text('游戏'), icon: Icon(OhosIcons.flag)),
            OhosChipItem(
              label: Text('图书'),
              icon: Icon(OhosIcons.book_pages_fill_1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 不包 Row：塞进 Row 会拿到无界宽度，铺满型的 chip 组就没法按屏宽收起
        OhosChipGroup(
          size: OhosChipGroupSize.small,
          selectedIndex: _selected.isEmpty ? 0 : _selected.first,
          onSelected: (int i) => setState(() => _selected = <int>{i}),
          items: const <OhosChipItem>[
            OhosChipItem(label: Text('默认')),
            OhosChipItem(label: Text('小尺寸')),
          ],
        ),
      ],
    );
  }
}

class _NavigationBarDemo extends StatefulWidget {
  const _NavigationBarDemo({required this.type});

  final OhosNavigationBarType type;

  @override
  State<_NavigationBarDemo> createState() => _NavigationBarDemoState();
}

class _NavigationBarDemoState extends State<_NavigationBarDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        // 底板与栏体都跟着主题走：固定浅灰 + 固定白栏这套组合在深色主题下
        // 会让栏里的标签文字（跟着主题变近白）压在白底上。
        color: theme.compBackgroundGrayColor ?? OhosColors.compBackgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: OhosNavigationBar(
          type: widget.type,
          lightMaterial: widget.type == OhosNavigationBarType.float,
          glow: widget.type == OhosNavigationBarType.float,
          backgroundColor: theme.cardColor,
          currentIndex: _index,
          onDestinationSelected: (int i) => setState(() => _index = i),
          destinations: const <OhosNavigationDestination>[
            OhosNavigationDestination(
              icon: Icon(OhosIcons.square_grid_2x2),
              label: '首页',
            ),
            OhosNavigationDestination(
              icon: Icon(OhosIcons.message_fill),
              label: '消息',
            ),
            OhosNavigationDestination(
              icon: Icon(OhosIcons.star_fill),
              label: '收藏',
              badge: OhosBadge(count: 8),
            ),
            OhosNavigationDestination(
              icon: Icon(OhosIcons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

class _SwiperDemo extends StatelessWidget {
  const _SwiperDemo();

  static const List<Color> _colors = <Color>[
    Color(0xFF0A59F7),
    Color(0xFF64BB5C),
    Color(0xFFF7CE00),
    Color(0xFFE55392),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _swiper(
          type: OhosPageIndicatorType.dot,
          arrows: false,
          autoPlay: true,
        ),
        const SizedBox(height: 16),
        _swiper(
          type: OhosPageIndicatorType.digit,
          arrows: true,
          autoPlay: false,
        ),
        const SizedBox(height: 8),
        _hint('上：圆点（选中变宽 12×6）+ 自动播放；下：数字型 + 左右箭头'),
      ],
    );
  }

  Widget _swiper({
    required OhosPageIndicatorType type,
    required bool arrows,
    required bool autoPlay,
  }) {
    return OhosSwiper(
      height: 120,
      autoPlay: autoPlay,
      indicatorType: type,
      showArrows: arrows,
      clipRadius: BorderRadius.circular(16),
      children: <Widget>[
        for (int i = 0; i < _colors.length; i++)
          Container(
            decoration: BoxDecoration(
              color: _colors[i],
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              '页面 ${i + 1}',
              style: TextStyle(
                color: _colors[i] == const Color(0xFFF7CE00)
                    ? Colors.black87
                    : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _hint(String text) {
    return Builder(
      builder: (BuildContext context) {
        final OhosThemeData theme = OhosTheme.of(context);
        return Text(
          text,
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        );
      },
    );
  }
}
