import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

import 'demo_scaffold.dart';

/// 导航类：标题栏 / 子页签（下划线 + 胶囊）/ 底部页签 / 导航点（轮播）
class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '导航类',
      children: <Widget>[
        const DemoSection(
          title: '标题栏 OhosAppBar（沉浸光感）',
          description: 'lightMaterial 开启后使用 ULTRA_THIN 材质 + 顶部渐变模糊。',
          child: _LightAppBarDemo(),
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
          description: '悬浮胶囊 + 沉浸光感 THIN 材质，激活项图标与文字同排。',
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
        Row(
          children: <Widget>[
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
    return Container(
      decoration: BoxDecoration(
        color: OhosColors.compBackgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: OhosNavigationBar(
          type: widget.type,
          lightMaterial: widget.type == OhosNavigationBarType.float,
          backgroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    const List<Color> colors = <Color>[
      Color(0xFF0A59F7),
      Color(0xFF64BB5C),
      Color(0xFFF7CE00),
      Color(0xFFE55392),
    ];
    return OhosSwiper(
      height: 120,
      autoPlay: true,
      children: <Widget>[
        for (int i = 0; i < colors.length; i++)
          Container(
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              '页面 ${i + 1}',
              style: TextStyle(
                color: colors[i] == const Color(0xFFF7CE00)
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
}
