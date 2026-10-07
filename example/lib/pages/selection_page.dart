import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// 选择类：勾选框 / 单选按钮 / 开关 / 评分条 / 滑动条 / 分段按钮 / 颜色选择器 / 选择器
class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  bool _checked = true;
  bool _switchOn = true;
  int _radio = 1;
  int _rating = 3;
  double _slider = 38;
  Color _color = const Color(0xFF0A59F7);
  String _grade = '专业版';

  static const List<Color> _palette = <Color>[
    Color(0xFF0A59F7),
    Color(0xFF27B440),
    Color(0xFFFF8F1F),
    Color(0xFFE84026),
    Color(0xFFAA2ED1),
    Color(0xFF2CC2C9),
    Color(0xFF8A8A8E),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return DemoScaffold(
      title: '选择类',
      children: <Widget>[
        DemoSection(
          title: '勾选框 OhosCheckbox',
          description: '选中 / 未选中 / 禁用三种状态。',
          child: DemoCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                OhosCheckbox(
                  value: _checked,
                  onChanged: (bool v) => setState(() => _checked = v),
                  size: 22,
                ),
                OhosCheckbox(value: false, onChanged: _noopBool, size: 22),
                OhosCheckbox(value: true, onChanged: null, size: 22),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '单选按钮 OhosRadio',
          description: '同组内互斥，当前选中: 选项${_radio == 1 ? '一' : '二'}',
          child: DemoCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                OhosRadio(
                  value: _radio == 1,
                  onChanged: (bool v) => setState(() => _radio = 1),
                  size: 22,
                ),
                const Text('选项一'),
                OhosRadio(
                  value: _radio == 2,
                  onChanged: (bool v) => setState(() => _radio = 2),
                  size: 22,
                ),
                const Text('选项二'),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '开关 OhosSwitch',
          description: '点击切换开 / 关，当前: ${_switchOn ? '开' : '关'}',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosSwitch(
                  value: _switchOn,
                  onChanged: (bool v) => setState(() => _switchOn = v),
                ),
                const SizedBox(width: 16),
                OhosSwitch(value: false, onChanged: _noopBool),
                const SizedBox(width: 16),
                OhosSwitch(
                  value: true,
                  onChanged: null,
                  activeColor: theme.highlightColor.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '评分条 OhosRatingBar',
          description: '半星支持，当前评分: $_rating',
          child: DemoCard(
            child: OhosRatingBar(
              value: _rating,
              onChanged: (int v) => setState(() => _rating = v),
              count: 5,
              starSize: 32,
            ),
          ),
        ),
        DemoSection(
          title: '滑动条 OhosSlider',
          description: '带刻度与气泡数值，当前值: ${_slider.round()}',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                OhosSlider(
                  value: _slider,
                  onChanged: (double v) => setState(() => _slider = v),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  showValueBubble: true,
                ),
                const SizedBox(height: 12),
                const OhosSlider(
                  value: 62,
                  onChanged: _noopSlider,
                  min: 0,
                  max: 100,
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '分段按钮 OhosSegmentedButton',
          description: '互斥分段，用于视图切换。',
          child: DemoCard(child: _SegmentDemo()),
        ),
        DemoSection(
          title: '颜色选择器 OhosColorPicker',
          description: '点击色块选择强调色。',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosColorPicker(
                  colors: _palette,
                  selectedColor: _color,
                  onChanged: (Color c) => setState(() => _color = c),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _color.toARGB32().toRadixString(16),
                      style: theme.typography.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '选择器 showOhosPicker',
          description: '底部弹窗列表选择，当前: $_grade',
          child: DemoCard(
            child: OhosButton(
              onPressed: () async {
                final String? result = await showOhosPicker<String>(
                  context: context,
                  title: '选择版本',
                  initialValue: _grade,
                  items: const <OhosPickerItem<String>>[
                    OhosPickerItem(label: '免费版', value: '免费版'),
                    OhosPickerItem(
                      label: '专业版',
                      value: '专业版',
                      subtitle: '解锁全部能力',
                    ),
                    OhosPickerItem(label: '旗舰版', value: '旗舰版'),
                  ],
                );
                if (result != null && mounted) {
                  setState(() => _grade = result);
                }
              },
              style: OhosButtonStyle.tonal,
              icon: const Icon(OhosIcons.list_bullet),
              child: const Text('打开选择器'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentDemo extends StatefulWidget {
  const _SegmentDemo();

  @override
  State<_SegmentDemo> createState() => _SegmentDemoState();
}

class _SegmentDemoState extends State<_SegmentDemo> {
  String _selected = 'day';

  @override
  Widget build(BuildContext context) {
    return OhosSegmentedButton<String>(
      segments: const <OhosSegment<String>>[
        OhosSegment(label: '日', value: 'day'),
        OhosSegment(label: '周', value: 'week'),
        OhosSegment(label: '月', value: 'month'),
        OhosSegment(label: '年', value: 'year'),
      ],
      selected: _selected,
      onSelected: (String v) => setState(() => _selected = v),
    );
  }
}

void _noopBool(bool value) {}
void _noopSlider(double value) {}
