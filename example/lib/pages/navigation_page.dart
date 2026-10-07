import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

import 'demo_scaffold.dart';

/// 导航类：标题栏 / 子页签 / 底部页签 / 导航点（轮播）
class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '导航类',
      children: <Widget>[
        const DemoSection(
          title: '标题栏 OhosAppBar',
          description: '本页顶栏即 OhosAppBar：自动回退按钮 + 居中标题。',
          child: DemoCard(
            child: OhosAppBar(
              title: Text('示例标题栏'),
              actions: <Widget>[
                OhosBadge(
                  count: 99,
                  maxCount: 99,
                  child: OhosIconButton(icon: Icon(OhosIcons.bell_fill)),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '子页签 OhosTabBar',
          description: '滑动指示条跟随激活项。',
          child: _TabBarDemo(),
        ),
        const DemoSection(
          title: '底部页签 OhosNavigationBar',
          description: '激活项带蓝色胶囊指示与标签。',
          child: _NavigationBarDemo(),
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

class _TabBarDemo extends StatelessWidget {
  const _TabBarDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const OhosTabBar(
            tabs: <Widget>[
              Tab(text: '推荐'),
              Tab(text: '关注'),
              Tab(text: '热榜'),
            ],
          ),
          SizedBox(
            height: 100,
            child: TabBarView(
              children: <Widget>[
                _tabHint(theme, '推荐内容'),
                _tabHint(theme, '关注内容'),
                _tabHint(theme, '热榜内容'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabHint(OhosThemeData theme, String text) {
    return Center(
      child: Text(text, style: TextStyle(color: theme.textSecondaryColor)),
    );
  }
}

class _NavigationBarDemo extends StatefulWidget {
  const _NavigationBarDemo();

  @override
  State<_NavigationBarDemo> createState() => _NavigationBarDemoState();
}

class _NavigationBarDemoState extends State<_NavigationBarDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return OhosNavigationBar(
      currentIndex: _index,
      height: 64,
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
        OhosNavigationDestination(icon: Icon(OhosIcons.person), label: '我的'),
      ],
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
