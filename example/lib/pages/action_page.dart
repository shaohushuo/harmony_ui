import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// 操作类：按钮 / 下拉按钮 / 状态按钮 / 操作块 / 工具栏 / 核心操作栏 / 菜单
class ActionPage extends StatelessWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '操作类',
      children: <Widget>[
        const DemoSection(
          title: '按钮 OhosButton',
          description: '五种强调样式 × 三种形状，支持图标 / 加载 / 禁用。',
          child: DemoCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
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
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '下拉按钮 OhosSelect',
          description: '点击展开选项菜单，选中项带对勾。',
          child: DemoCard(child: _SelectDemo()),
        ),
        const DemoSection(
          title: '状态按钮 OhosToggleButton',
          description: '开/关两种状态，点击切换。',
          child: DemoCard(child: _ToggleDemo()),
        ),
        const DemoSection(
          title: '操作块 OhosChip',
          description: '单选筛选标签。',
          child: DemoCard(child: _ChipsDemo()),
        ),
        const DemoSection(
          title: '工具栏 OhosToolbar',
          description:
              '图标 + 文字，整条 57（56 + 1px 分割线）。'
              '激活态要 activeIndex 与 ACTIVATE 同时满足；超过 5 项自动收进「更多」。',
          child: DemoCard(padding: EdgeInsets.zero, child: _ToolbarDemo()),
        ),
        const DemoSection(
          title: '核心操作栏 OhosActionBar',
          description: '两端按钮组 + 居中主按钮，背板默认带模糊材质。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: OhosActionBar(
              startButtons: <OhosActionBarButton>[
                OhosActionBarButton(
                  icon: Icon(Icons.schedule_rounded),
                  tooltip: '稍后',
                  onPressed: _noop,
                ),
                OhosActionBarButton(
                  icon: Icon(Icons.confirmation_number_outlined),
                  tooltip: '优惠券',
                  onPressed: _noop,
                ),
              ],
              endButtons: <OhosActionBarButton>[
                OhosActionBarButton(
                  icon: Icon(Icons.mic_none_rounded),
                  tooltip: '语音',
                  onPressed: _noop,
                ),
              ],
              primaryButton: OhosActionBarButton(
                icon: Icon(Icons.check_rounded),
                tooltip: '确认支付',
                onPressed: _noop,
              ),
            ),
          ),
        ),
        const DemoSection(
          title: '操作栏：竖直排列 + 整体禁用',
          description:
              'isHorizontal: false 时 startSpace / endSpace 落到上下边框；'
              'style.enabled 是总开关，背板与所有按钮一起失效。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            // 竖直排列的操作栏高度由按钮数量决定（无界），必须给一个明确的
            // 高度容器包住 —— 直接塞进纵向 ListView 会得到
            // 「Vertical viewport was given unbounded height」。
            child: SizedBox(
              height: 240,
              child: Center(
                child: OhosActionBar(
                  isExpand: true,
                  startButtons: <OhosActionBarButton>[
                    OhosActionBarButton(
                      icon: Icon(Icons.share_rounded),
                      tooltip: '分享（禁用）',
                      enabled: false,
                      onPressed: _noop,
                    ),
                  ],
                  endButtons: <OhosActionBarButton>[
                    OhosActionBarButton(
                      icon: Icon(Icons.bookmark_border_rounded),
                      tooltip: '收藏',
                      onPressed: _noop,
                    ),
                  ],
                  primaryButton: OhosActionBarButton(
                    icon: Icon(Icons.send_rounded),
                    tooltip: '发送',
                    onPressed: _noop,
                  ),
                  style: OhosActionBarStyle(
                    enabled: false,
                    isHorizontal: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        const DemoSection(
          title: '菜单 OhosMenu / showOhosMenu',
          description: '点击按钮弹出列表菜单；也支持宫格样式。',
          child: _MenuDemo(),
        ),
      ],
    );
  }
}

class _MenuDemo extends StatefulWidget {
  const _MenuDemo();

  @override
  State<_MenuDemo> createState() => _MenuDemoState();
}

class _MenuDemoState extends State<_MenuDemo> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      child: Wrap(
        spacing: 12,
        children: <Widget>[
          OhosButton(
            key: _anchorKey,
            onPressed: () async {
              final String? result = await showOhosMenu<String>(
                context: context,
                anchor: _anchorKey,
                items: const <OhosMenuItem<String>>[
                  OhosMenuItem(
                    label: '复制',
                    icon: Icons.copy_rounded,
                    value: 'copy',
                  ),
                  OhosMenuItem(
                    label: '收藏',
                    icon: Icons.star_border_rounded,
                    value: 'star',
                  ),
                  OhosMenuItem(
                    label: '删除',
                    icon: Icons.delete_rounded,
                    value: 'delete',
                    danger: true,
                  ),
                ],
              );
              if (result == null || !context.mounted) {
                return;
              }
              showOhosToast(context, '选择了: $result');
            },
            style: OhosButtonStyle.tonal,
            child: const Text('打开菜单'),
          ),
        ],
      ),
    );
  }
}

class _SelectDemo extends StatefulWidget {
  const _SelectDemo();

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  String _value = 'cn';

  @override
  Widget build(BuildContext context) {
    return OhosSelect<String>(
      value: _value,
      onChanged: (String v) => setState(() => _value = v),
      options: const <OhosSelectOption<String>>[
        OhosSelectOption(label: '中文', value: 'cn', icon: OhosIcons.character),
        OhosSelectOption(
          label: 'English',
          value: 'en',
          icon: OhosIcons.character,
        ),
        OhosSelectOption(label: '日本語', value: 'ja', icon: OhosIcons.character),
      ],
    );
  }
}

class _ToggleDemo extends StatefulWidget {
  const _ToggleDemo();

  @override
  State<_ToggleDemo> createState() => _ToggleDemoState();
}

class _ToggleDemoState extends State<_ToggleDemo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OhosToggleButton(
          value: _on,
          onChanged: (bool v) => setState(() => _on = v),
          icon: const Icon(OhosIcons.heart_fill),
          child: const Text('收藏'),
        ),
        OhosToggleButton(
          value: false,
          onChanged: _noopSwitch,
          child: const Text('未激活'),
        ),
        OhosToggleButton(
          value: true,
          onChanged: _noopSwitch,
          child: const Text('已激活'),
        ),
      ],
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

class _ToolbarDemo extends StatefulWidget {
  const _ToolbarDemo();

  @override
  State<_ToolbarDemo> createState() => _ToolbarDemoState();
}

class _ToolbarDemoState extends State<_ToolbarDemo> {
  /// 4 项的一档：正好演示激活态。
  int _active = 1;

  /// 7 项的一档：前 4 留在线内，后 3 收进「更多」。
  int _activeLong = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        OhosToolbar(
          activeIndex: _active,
          items: <OhosToolbarItem>[
            OhosToolbarItem(
              icon: OhosIcons.share,
              label: '分享',
              onPressed: _noop,
            ),
            OhosToolbarItem(
              icon: OhosIcons.star,
              label: '收藏',
              // 只有 ACTIVATE 才允许被 activeIndex 点亮。
              state: OhosToolbarItemState.activated,
              onPressed: () => setState(() => _active = 1),
            ),
            OhosToolbarItem(
              icon: OhosIcons.heart,
              label: '点赞',
              state: OhosToolbarItemState.activated,
              onPressed: () => setState(() => _active = 2),
            ),
            // 禁用项：不可点、变灰，也永远不会被点亮。
            const OhosToolbarItem(
              icon: OhosIcons.message,
              label: '评论',
              state: OhosToolbarItemState.disabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        OhosToolbar(
          activeIndex: _activeLong,
          moreIcon: OhosIcons.dot_grid_2x2,
          items: <OhosToolbarItem>[
            for (int i = 0; i < 7; i++)
              OhosToolbarItem(
                icon: _longIcons[i],
                label: _longLabels[i],
                state: OhosToolbarItemState.activated,
                onPressed: () => setState(() => _activeLong = i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Hint('上：4 项，正好留出 24 侧边距；下：7 项，前 4 + 「更多」'),
      ],
    );
  }
}

const List<IconData> _longIcons = <IconData>[
  OhosIcons.share,
  OhosIcons.star,
  OhosIcons.heart,
  OhosIcons.message,
  OhosIcons.save,
  OhosIcons.bookmark,
  OhosIcons.phone,
];

const List<String> _longLabels = <String>[
  '分享',
  '收藏',
  '点赞',
  '评论',
  '保存',
  '书签',
  '通话',
];

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: theme.typography.bodySmall?.copyWith(
          color: theme.textSecondaryColor,
        ),
      ),
    );
  }
}

void _noop() {}
void _noopSwitch(bool value) {}
