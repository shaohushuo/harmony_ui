import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui/ohos_ui.dart';

/// Buttons, icon buttons, list tiles, cards, chips and tabs.
class WidgetsPage extends StatelessWidget {
  const WidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: <Widget>[
        _SectionTitle('按钮 / OhosButton', icon: OhosIcons.checkmark_circle_fill),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            OhosButton(onPressed: _noop, child: Text('填充')),
            OhosButton(
              onPressed: _noop,
              style: OhosButtonStyle.tonal,
              child: Text('次级'),
            ),
            OhosButton(
              onPressed: _noop,
              style: OhosButtonStyle.outlined,
              child: Text('描边'),
            ),
            OhosButton(
              onPressed: _noop,
              style: OhosButtonStyle.text,
              child: Text('文字'),
            ),
            OhosButton(
              onPressed: _noop,
              style: OhosButtonStyle.plain,
              child: Text('普通'),
            ),
            OhosButton(onPressed: null, child: Text('禁用')),
            OhosButton(onPressed: _noop, loading: true, child: Text('加载中')),
            OhosButton(
              onPressed: _noop,
              shape: OhosButtonShape.rounded,
              child: Text('圆角'),
            ),
            OhosButton(
              onPressed: _noop,
              icon: Icon(OhosIcons.plus),
              child: Text('带图标'),
            ),
            OhosButton(
              onPressed: _noop,
              shape: OhosButtonShape.circle,
              icon: Icon(OhosIcons.phone_fill),
              child: null,
            ),
            OhosButton(
              onPressed: _noop,
              shape: OhosButtonShape.circle,
              icon: Icon(OhosIcons.ellipsis_circle),
              child: null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle('图标按钮 / OhosIconButton', icon: OhosIcons.star_fill),
        const Wrap(
          spacing: 8,
          children: <Widget>[
            OhosIconButton(
              icon: Icon(OhosIcons.heart_fill),
              color: Color(0xFFE84026),
            ),
            OhosIconButton(
              icon: Icon(OhosIcons.magnifyingglass),
              backgroundColor: Color(0x140A59F7),
              color: Color(0xFF0A59F7),
            ),
            OhosIconButton(icon: Icon(OhosIcons.trash), onPressed: null),
            OhosIconButton(icon: Icon(OhosIcons.ellipsis_message)),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          '选项卡 / OhosTabBar',
          icon: OhosIcons.list_bullet_square_fill,
        ),
        const _TabsDemo(),
        const SizedBox(height: 24),
        _SectionTitle('列表 / OhosListTile', icon: OhosIcons.list_bullet),
        OhosCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const <Widget>[
              OhosListTile(
                leading: Icon(OhosIcons.wifi),
                title: Text('无线网络'),
                subtitle: Text('已连接到 HarmonyOS 5G'),
                trailing: Icon(OhosIcons.chevron_right),
                onTap: _noop,
              ),
              OhosListTile(
                leading: Icon(OhosIcons.bluetooth),
                title: Text('蓝牙'),
                trailing: OhosSwitch(value: true, onChanged: _noopSwitch),
              ),
              OhosListTile(
                leading: Icon(OhosIcons.moon_fill),
                title: Text('深色模式'),
                subtitle: Text('跟随系统'),
                selected: true,
                trailing: Icon(OhosIcons.chevron_right),
                onTap: _noop,
              ),
              OhosListTile(
                leading: Icon(OhosIcons.bell_fill),
                title: Text('通知'),
                trailing: OhosBadge(count: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle('卡片 / OhosCard', icon: OhosIcons.doc_text_fill),
        Row(
          children: const <Widget>[
            Expanded(
              child: OhosCard(
                elevation: 2,
                child: Column(
                  children: <Widget>[
                    Icon(OhosIcons.wifi_6, size: 32, color: Color(0xFF0A59F7)),
                    SizedBox(height: 8),
                    Text('流畅互联', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('低延时 高吞吐', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OhosCard(
                elevation: 2,
                child: Column(
                  children: <Widget>[
                    Icon(
                      OhosIcons.music_fill,
                      size: 32,
                      color: Color(0xFFA12DF7),
                    ),
                    SizedBox(height: 8),
                    Text('沉浸影音', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('空间音频', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle('标签 / OhosChip', icon: OhosIcons.checkmark_square_fill),
        const _ChipsDemo(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.highlightColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.typography.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabsDemo extends StatelessWidget {
  const _TabsDemo();

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
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
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

  Widget _tabHint(OhosThemeData theme, String msg) {
    return Center(
      child: Text(msg, style: TextStyle(color: theme.textSecondaryColor)),
    );
  }
}

class _ChipsDemo extends StatefulWidget {
  const _ChipsDemo();

  @override
  State<_ChipsDemo> createState() => _ChipsDemoState();
}

class _ChipsDemoState extends State<_ChipsDemo> {
  final Set<String> _selected = <String>{'全部'};
  static const List<String> _labels = <String>[
    '全部',
    '办公',
    '娱乐',
    '教育',
    '出行',
    '健康',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String label in _labels)
          OhosChip(
            label: Text(label),
            selected: _selected.contains(label),
            icon: label == '全部' ? const Icon(OhosIcons.checkmark) : null,
            onPressed: () {
              setState(() {
                _selected.clear();
                _selected.add(label);
              });
            },
          ),
      ],
    );
  }
}

void _noop() {}
void _noopSwitch(bool value) {}
