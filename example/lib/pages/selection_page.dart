import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
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
    // 白与浅灰压在白底上，靠色块自己的描边读出来（墨屏更明显）
    Color(0xFFFFFFFF),
    Color(0xFFE8E8E8),
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
        const DemoSection(
          title: '全选组 OhosCheckboxGroup',
          description: '三态：全选（勾）/ 半选（一横）/ 全不选。点群组头切换，点成员单项切换。',
          child: DemoCard(child: _GroupDemo()),
        ),
        DemoSection(
          title: '单选按钮 OhosRadio',
          description:
              '同组内互斥，当前选中: 选项${_radio == 1 ? '一' : '二'}。'
              '默认选中图形是 TICK（勾），API 12 起不再是 DOT。',
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
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
                const SizedBox(height: 12),
                // 三种选中图形：tick（默认）/ dot（API 12 之前的默认）/
                // 自定义 builder。都画成已选中的样子，便于并排对比。
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    const _IndicatorLabel(
                      label: 'TICK',
                      child: OhosRadio(value: true, onChanged: _noopBool),
                    ),
                    const _IndicatorLabel(
                      label: 'DOT',
                      child: OhosRadio(
                        value: true,
                        onChanged: _noopBool,
                        indicator: OhosRadioIndicator.dot,
                      ),
                    ),
                    _IndicatorLabel(
                      label: 'CUSTOM',
                      child: OhosRadio(
                        value: true,
                        onChanged: _noopBool,
                        indicator: OhosRadioIndicator.custom,
                        indicatorBuilder: (BuildContext context) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: OhosTheme.of(context).onHighlightColor,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  showSteps: true,
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
          title: '滑动条三种形态',
          description:
              'OutSet（轨道 4 / 滑块 16）/ InSet（轨道 20 / 滑块 12）/ '
              'NONE（无滑块，命中区仍 40）。都带前后缀。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                _StyleSlider(style: OhosSliderStyle.outset),
                SizedBox(height: 8),
                _StyleSlider(style: OhosSliderStyle.inset),
                SizedBox(height: 8),
                _StyleSlider(style: OhosSliderStyle.none),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '分段按钮 OhosSegmentedButton',
          description: 'tab 型（白背板）/ capsule 型（品牌色药丸）/ capsule 多选。',
          child: DemoCard(child: _SegmentDemo()),
        ),
        const DemoSection(
          title: '选择器滚轮 OhosWheelPicker',
          description: '三列、可循环（年列 ≥ 8 项）。行高 40、文本 20fp。',
          child: DemoCard(child: _WheelDemo()),
        ),
        const DemoSection(
          title: '时间 / 日期选择器',
          description: '时 : 分 : 秒 与 年 / 月 / 日。改月时日收敛到当月末。',
          child: DemoCard(child: _DateTimeDemo()),
        ),
        DemoSection(
          title: '颜色选择器 OhosColorPicker',
          description: '点击色块选择强调色。',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OhosColorPicker(
                    colors: _palette,
                    selectedColor: _color,
                    onChanged: (Color c) => setState(() => _color = c),
                  ),
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
                        // 选到白 / 浅色时，色块自身在白卡片上会消失
                        border: Border.fromBorderSide(
                          ohosSwatchOutline(context, theme, _color),
                        ),
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
  final Set<String> _multi = <String>{'wifi', 'bt'};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('capsule 单选', style: OhosTheme.of(context).typography.bodySmall),
        const SizedBox(height: 8),
        OhosSegmentedButton<String>(
          segments: const <OhosSegment<String>>[
            OhosSegment(label: '日', value: 'day'),
            OhosSegment(label: '周', value: 'week'),
            OhosSegment(label: '月', value: 'month'),
            OhosSegment(label: '年', value: 'year'),
          ],
          selected: _selected,
          onSelected: (String v) => setState(() => _selected = v),
        ),
        const SizedBox(height: 16),
        Text(
          'tab 型（白背板、无图标）',
          style: OhosTheme.of(context).typography.bodySmall,
        ),
        const SizedBox(height: 8),
        OhosSegmentedButton<String>(
          type: OhosSegmentType.tab,
          segments: const <OhosSegment<String>>[
            OhosSegment(label: '全部', value: 'all'),
            OhosSegment(label: '图片', value: 'image'),
            OhosSegment(label: '视频', value: 'video'),
          ],
          selected: _selected == 'day' ? 'all' : 'image',
          onSelected: (String v) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          'capsule 多选（multiply）',
          style: OhosTheme.of(context).typography.bodySmall,
        ),
        const SizedBox(height: 8),
        OhosSegmentedButton<String>(
          multiply: true,
          segments: const <OhosSegment<String>>[
            OhosSegment(label: 'WLAN', value: 'wifi'),
            OhosSegment(label: '蓝牙', value: 'bt'),
            OhosSegment(label: 'NFC', value: 'nfc'),
          ],
          selectedValues: _multi,
          onSelectionChanged: (Set<String> v) => setState(() {
            _multi
              ..clear()
              ..addAll(v);
          }),
        ),
      ],
    );
  }
}

/// 单条带前后缀的滑块，供三种形态并排展示。
class _StyleSlider extends StatelessWidget {
  const _StyleSlider({required this.style});

  final OhosSliderStyle style;

  @override
  Widget build(BuildContext context) {
    return OhosSlider(
      value: 40,
      onChanged: _noopSlider,
      style: style,
      divisions: 10,
      showSteps: true,
      prefix: const Icon(Icons.volume_mute_rounded, size: 20),
      suffix: const Icon(Icons.volume_up_rounded, size: 20),
    );
  }
}

/// 三态群组演示：一个群组头 + 三个成员。
class _GroupDemo extends StatefulWidget {
  const _GroupDemo();

  @override
  State<_GroupDemo> createState() => _GroupDemoState();
}

class _GroupDemoState extends State<_GroupDemo> {
  late final OhosCheckboxGroupController _controller =
      OhosCheckboxGroupController(
        allNames: <String>['推送通知', '声音', '震动'],
        selected: <String>{'推送通知'},
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OhosCheckboxGroupScope(
      controller: _controller,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const OhosCheckboxGroupHeader(title: '全部提醒'),
          for (final String name in _controller.allNames)
            OhosCheckboxGroupTile(name: name, title: name),
          const SizedBox(height: 8),
          // 反选是补充能力：官方只有全选 / 全不选两档
          Align(
            alignment: Alignment.centerRight,
            child: OhosButton(
              onPressed: _controller.invert,
              style: OhosButtonStyle.text,
              child: const Text('反选'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单列 + 双列滚轮演示。
class _WheelDemo extends StatefulWidget {
  const _WheelDemo();

  @override
  State<_WheelDemo> createState() => _WheelDemoState();
}

class _WheelDemoState extends State<_WheelDemo> {
  int _index = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 200,
          child: OhosWheelPicker(
            columns: <OhosPickerColumn>[
              OhosPickerColumn(
                labels: const <String>[
                  '北京',
                  '上海',
                  '广州',
                  '深圳',
                  '杭州',
                  '成都',
                  '武汉',
                  '西安',
                  '南京',
                  '重庆',
                ],
                initialIndex: _index,
              ),
            ],
            onScrollStop: (int column, int index) =>
                setState(() => _index = index),
          ),
        ),
        Text(
          '当前：第 $_index 项（0 基）',
          style: OhosTheme.of(context).typography.bodySmall,
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: OhosWheelPicker(
            indicator: OhosPickerIndicator.divider,
            columns: <OhosPickerColumn>[
              OhosPickerColumn(
                labels: <String>['标准', '高清', '超清', '原画'],
                flex: 2,
              ),
              OhosPickerColumn(labels: <String>['30fps', '60fps']),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'DIVIDER 指示器 + 两列 2:1',
          style: OhosTheme.of(context).typography.bodySmall,
        ),
      ],
    );
  }
}

/// 时间与日期并排。
class _DateTimeDemo extends StatefulWidget {
  const _DateTimeDemo();

  @override
  State<_DateTimeDemo> createState() => _DateTimeDemoState();
}

class _DateTimeDemoState extends State<_DateTimeDemo> {
  int _hour = 9;
  int _minute = 30;
  int _year = 2025;
  int _month = 3;
  int _day = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 160,
          child: OhosTimePicker(
            hour: _hour,
            minute: _minute,
            height: 160,
            onChanged: (int h, int m, int s) => setState(() {
              _hour = h;
              _minute = m;
            }),
          ),
        ),
        Text(
          '${_hour.toString().padLeft(2, '0')}:'
          '${_minute.toString().padLeft(2, '0')}',
          style: OhosTheme.of(context).typography.bodyMedium,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: OhosDatePicker(
            year: _year,
            month: _month,
            day: _day,
            height: 160,
            onChanged: (int y, int m, int d) => setState(() {
              _year = y;
              _month = m;
              _day = d;
            }),
          ),
        ),
        Text(
          '$_year-${_month.toString().padLeft(2, '0')}-'
          '${_day.toString().padLeft(2, '0')}',
          style: OhosTheme.of(context).typography.bodyMedium,
        ),
      ],
    );
  }
}

/// 图形 + 标签的小格子，用于并排对比三种 indicator。
class _IndicatorLabel extends StatelessWidget {
  const _IndicatorLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        const SizedBox(height: 4),
        Text(label, style: OhosTheme.of(context).typography.bodySmall),
      ],
    );
  }
}

void _noopBool(bool value) {}
void _noopSlider(double value) {}
