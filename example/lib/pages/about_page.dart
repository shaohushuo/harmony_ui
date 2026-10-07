import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

/// Package overview and the HarmonyOS color palette.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const List<String> _names = <String>[
    '绿色',
    '黄绿',
    '黄色',
    '橙色',
    '深橙',
    '红色',
    '洋红',
    '紫色',
    '靛蓝',
    '蓝色',
    '青色',
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: <Widget>[
        OhosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    OhosIcons.house_fill,
                    color: theme.highlightColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ohos_ui',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Material / Cupertino 风格的 Flutter 组件库，实现 HarmonyOS 设计语言。'
                '当前示例展示所有内置组件与设计令牌。',
                style: TextStyle(color: theme.textSecondaryColor, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('主题色板 / OhosColors'),
        OhosCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (int i = 0; i < OhosColors.multiLight.length; i++)
                _ColorItem(color: OhosColors.multiLight[i], name: _names[i]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('鸿蒙 Symbol 图标 / ohos_icons'),
        OhosCard(
          child: Column(
            children: <Widget>[
              for (final IconData icon in const <IconData>[
                OhosIcons.house_fill,
                OhosIcons.message_fill,
                OhosIcons.wifi_6,
                OhosIcons.music_fill,
                OhosIcons.heart_fill,
                OhosIcons.star_fill,
                OhosIcons.cloud_and_arrow_down,
                OhosIcons.gearshape_fill,
              ])
                OhosListTile(
                  leading: Icon(icon),
                  title: Text(icon.codePoint.toString()),
                  trailing: const Icon(OhosIcons.chevron_right),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ColorItem extends StatelessWidget {
  const _ColorItem({required this.color, required this.name});

  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.typography.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
