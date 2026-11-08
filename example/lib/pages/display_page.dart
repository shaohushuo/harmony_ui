import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import '../demo_frame.dart';
import '../ink_color_data.dart';
import 'demo_scaffold.dart';

/// 展示类：文本 / 子标题 / 分隔器 / 进度条 / 索引条 / 滚动条 / 徽标 /
/// 即时反馈 / 即时操作 / 气泡 / 数据可视化 / 二维码 / 文本时钟 / 图片 / 空白
class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '展示类',
      children: <Widget>[
        const DemoSection(
          title: '文本 OhosText',
          description: '绑定主题字体的文字组件，覆盖完整字阶。',
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                OhosText('DisplayL 36sp', level: OhosTextLevel.displayLarge),
                OhosText('HeadlineM 24sp', level: OhosTextLevel.headlineMedium),
                OhosText('TitleM 17sp', level: OhosTextLevel.titleMedium),
                OhosText('BodyL 16sp', level: OhosTextLevel.bodyLarge),
                OhosText('BodyS 14sp', level: OhosTextLevel.bodySmall),
                OhosText('LabelS 12sp', level: OhosTextLevel.labelSmall),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '墨水屏主题 OhosThemeData.ink（16 级灰）',
          description:
              '纯黑 + 纯白、去掉中间调：分隔线是 1px 纯黑（light 预设的 10% 黑在 16 级灰上'
              '等于没有），水波纹 / 悬停 / 阴影全关，三级色留 #767676 给占位文字。'
              'brightness 仍是 light，判断屏幕类型请读 theme.policy 的 isMonochrome / '
              'allowsShadow，不要用 isDark；OhosLightMaterial 在该主题下退化成纯色，'
              '不再做每帧全屏模糊。',
          child: _InkThemeDemo(),
        ),
        DemoSection(
          title: '子标题 OhosSubheader',
          description:
              '区块标题。形态由字段推导、不由开关决定：给了主副两个标题就是双行 72 高，'
              '其余 56 高。副标题单独成行时字重升到 500（双行时 400），左图标只在有'
              '副标题时出现 —— 三条都照官方恰好在这些地方不一样。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                OhosSubheader(title: '热门推荐', trailing: '更多'),
                OhosSubheader(title: '最近使用', trailing: '查看全部'),
                OhosSubheader(title: '本地服务'),
                OhosSubheader(
                  title: '本周更新',
                  secondaryTitle: '共 12 项，其中 3 项待处理',
                  trailing: '全部',
                  onTrailingTap: () {},
                ),
                OhosSubheader(
                  secondaryTitle: '已同步',
                  icon: Icon(Icons.cloud_done_outlined),
                ),
                OhosSubheader(
                  secondaryTitle: '纯文本右侧不带箭头',
                  trailing: '操作',
                  showTrailingArrow: false,
                  onTrailingTap: () {},
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '分隔器 OhosDivider',
          description:
              '发丝线，支持缩进。默认 indent 为 0（与 Material Divider 一致，'
              '替换时版式不变）；列表项自己传 16，让线与文字左对齐。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                OhosListTile(title: Text('列表项：线与文字对齐（indent 16）')),
                OhosListTile(title: Text('第二条列表项')),
                OhosDivider(indent: 8, endIndent: 8, height: 16),
                Padding(padding: EdgeInsets.all(12), child: OhosDivider()),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '进度条 OhosProgressIndicator',
          description: '圆形 / 线性，确定与不确定两种模式。',
          child: DemoCard(child: _ProgressDemo()),
        ),
        const DemoSection(
          title: '索引条 OhosAlphabetIndexer',
          description:
              '等高槽位：布局、字号与命中同一套几何，父级压高度时整条跟着缩。'
              'onSelected 是过程（跨格才报）、onSelectEnd 是结果（抬手一次）、'
              'selectedIndex 让代码定位与手指点亮同一个字母；拖动时手指旁出放大镜。',
          child: DemoCard(child: _IndexerDemo()),
        ),
        const DemoSection(
          title: '放大镜 OhosMagnifier',
          description:
              '跟随手指的浮层泡泡：text 放一个字符，child 放任意内容；落点由 '
              'OhosMagnifierPosition 求解，放不下自动换角 / 换行。泡泡进根 Overlay，'
              '画在宿主之外也不抢手势。',
          child: DemoCard(child: _MagnifierDemo()),
        ),
        const DemoSection(
          title: '滚动条 OhosScrollbar',
          description: '圆角滑块，主题化滚动条。',
          child: DemoCard(child: _ScrollbarDemo()),
        ),
        const DemoSection(
          title: '新事件标记 OhosBadge',
          description: '数字 / 红点角标。',
          child: DemoCard(
            child: Wrap(
              spacing: 20,
              runSpacing: 10,
              children: <Widget>[
                OhosBadge(
                  count: 120,
                  child: Icon(OhosIcons.message_fill, size: 26),
                ),
                OhosBadge(count: 5, child: Icon(OhosIcons.bell_fill, size: 26)),
                OhosBadge(isDot: true, child: Icon(OhosIcons.person, size: 26)),
                OhosBadge(count: 2),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '即时反馈 OhosToast / 即时操作 OhosSnackBar',
          description: '轻提示与带操作按钮的横幅。',
          child: DemoCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OhosButton(
                  onPressed: () => showOhosToast(
                    context,
                    '设置已保存',
                    icon: OhosIcons.checkmark_circle_fill,
                  ),
                  style: OhosButtonStyle.tonal,
                  child: const Text('Toast 提示'),
                ),
                OhosButton(
                  onPressed: () => showOhosSnackBar(
                    context,
                    message: '已删除 1 个文件',
                    actionLabel: '撤销',
                    onAction: () => showOhosToast(context, '已撤销'),
                  ),
                  style: OhosButtonStyle.tonal,
                  child: const Text('SnackBar'),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '气泡提示 OhosPopup',
          description: '锚定目标控件的气泡。',
          child: DemoCard(child: _PopupDemo()),
        ),
        DemoSection(
          title: '指标卡片 OhosStatGrid',
          description:
              '原来的 KPI 卡片网格。它曾叫 OhosDataPanel，但 ArkUI 的 '
              'DataPanel 是占比图而不是卡片 —— 名字已还给真组件，此处保留原视觉。',
          child: const DemoCard(
            child: OhosStatGrid(
              title: '本日健康数据',
              prefix: '',
              suffix: '',
              entries: <String, num>{
                '步数': 8642,
                '心率': 72,
                '睡眠': 7.5,
                '卡路里': 486,
              },
            ),
          ),
        ),
        const DemoSection(
          title: '占比图 OhosDataPanel',
          description:
              'DataPanel 的两种形态：环形 / 线形。values ≤ 9 段，'
              'max > 0 时是标尺（剩余部分留作底槽），max ≤ 0 时按数组之和铺满。',
          child: DemoCard(child: _DataPanelDemo()),
        ),
        const DemoSection(
          title: '量规图 OhosGauge',
          description:
              'Gauge：环是静态装饰（分段色 / 权重），指针才跟 value 走。'
              '起止角度是钟面语义 —— 0 点 0 度、顺时针为正。',
          child: DemoCard(child: _GaugeDemo()),
        ),
        const DemoSection(
          title: '二维码 OhosQrCode',
          description: '生成二维码，自动包含静区。',
          child: DemoCard(
            child: Center(
              child: OhosQrCode(
                data: 'https://github.com/shaohushuo/harmony_ui',
              ),
            ),
          ),
        ),
        const DemoSection(
          title: '文本时钟 OhosTextClock',
          description:
              '对应官方 TextClock：controller 控制启停（默认 started = true）、'
              'timeZoneOffset 按官方符号（东八区传 -8）、onDateChange 每秒给一次'
              ' Unix 秒数。组件不可见时自动停走。',
          child: DemoCard(
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: <Widget>[
                OhosTextClock(format: 'HH:mm:ss'),
                OhosTextClock(format: 'yyyy年MM月dd日'),
                // 东八区：官方符号是 -8（负数表示东时区）
                OhosTextClock(format: 'HH:mm', timeZoneOffset: -8),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '图片 OhosImage',
          description:
              '圆角图片容器。fit 用官方的 ImageFit 语义（8 档，与 BoxFit 不同名不同义），'
              '失败态有独立的 errorPlaceholder（官方 22+ 的 ImageAlt 就是这件事）。',
          child: DemoCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _PlaceholderImage(width: 96, height: 64),
                _PlaceholderImage(width: 96, height: 64, selected: true),
                _PlaceholderImage(
                  width: 96,
                  height: 64,
                  fit: OhosImageFit.contain,
                ),
                _PlaceholderImage(
                  width: 96,
                  height: 64,
                  fit: OhosImageFit.scaleDown,
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '空白 OhosBlank',
          description: '弹性占位空白，撑开布局。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                Text('头部内容'),
                OhosBlank(minSize: 40),
                Text('尾部内容'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressDemo extends StatefulWidget {
  const _ProgressDemo();

  @override
  State<_ProgressDemo> createState() => _ProgressDemoState();
}

class _ProgressDemoState extends State<_ProgressDemo> {
  double _value = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => setState(() => _value = (_value + 0.03) % 1.0),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ProgressLabel('五种形态 · 官方 ProgressType 全量'),
        const SizedBox(height: 8),
        // 五型的差异是**几何**差异，不是同一张图的五种涂装：并排才看得出
        // 「月相填面积、刻度环换色、胶囊两端走月牙」这几件事。
        // 官方示例 1 就是把这五型摆在一列里对照的。
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OhosProgressIndicator.ring(value: _value),
            OhosProgressIndicator.eclipse(value: _value),
            // 刻度环默认 120 刻度在 72 直径下会退化（刻度比间距还宽），
            // 所以示例换成 40 刻度 —— 这也是官方示例 1 的做法
            OhosProgressIndicator.scaleRing(
              value: _value,
              size: 72,
              scaleCount: 40,
              scaleWidth: 2,
            ),
            SizedBox(
              width: 120,
              height: 36,
              child: OhosProgressIndicator.capsule(
                value: _value,
                showDefaultPercentage: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _ProgressLabel('线性 · 确定 / 不确定'),
        const SizedBox(height: 8),
        OhosProgressIndicator.linear(value: _value),
        const SizedBox(height: 12),
        const OhosProgressIndicator.linear(),
        const SizedBox(height: 16),
        const _ProgressLabel('胶囊 · 内描边 + 自定义文本'),
        const SizedBox(height: 8),
        const SizedBox(
          height: 44,
          child: OhosProgressIndicator.capsule(
            value: 0.7,
            content: '正在安装…',
            borderColor: Color(0xFF007DFF),
          ),
        ),
        const SizedBox(height: 16),
        const _ProgressLabel('加载动效 OhosLoadingIndicator（彗星形）'),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const OhosLoadingIndicator(),
            const SizedBox(width: 16),
            const OhosLoadingIndicator(size: 24),
            const SizedBox(width: 16),
            // enableLoading=false 仍然占位：加载完成后切换不会让布局跳一下
            const OhosLoadingIndicator(enableLoading: false),
          ],
        ),
      ],
    );
  }
}

/// 进度条 demo 里的分组小标题。
class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
    );
  }
}

/// 索引条 + 放大镜 + 受控高亮。
///
/// 三条通道各司其职：`onSelected` 是过程（拖动每跨一格一次，用来滚列表），
/// `onSelectEnd` 是结果（抬手恰好一次，用来提示），`selectedIndex` 让代码发起
/// 的定位（那颗「跳到 M」）与手指拖动点亮同一个字母。
class _IndexerDemo extends StatefulWidget {
  const _IndexerDemo();

  @override
  State<_IndexerDemo> createState() => _IndexerDemoState();
}

class _IndexerDemoState extends State<_IndexerDemo> {
  static const double _rowExtent = 30;
  static const List<String> _letters = <String>[
    'A',
    'B',
    'C',
    'D',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'Q',
    'S',
    'T',
    'W',
    'X',
    'Y',
    'Z',
  ];
  static const Map<String, List<String>> _cities = <String, List<String>>{
    'A': <String>['鞍山', '安庆', '安顺'],
    'B': <String>['北京', '保定', '北海'],
    'C': <String>['成都', '长沙', '长春'],
    'D': <String>['大连', '东莞', '大理'],
    'F': <String>['福州', '佛山', '阜阳'],
    'G': <String>['广州', '贵阳', '桂林'],
    'H': <String>['杭州', '哈尔滨', '海口'],
    'J': <String>['济南', '嘉兴', '九江'],
    'K': <String>['昆明', '喀什', '开封'],
    'L': <String>['兰州', '洛阳', '丽江'],
    'M': <String>['绵阳', '牡丹江', '马鞍山'],
    'N': <String>['南京', '宁波', '南昌'],
    'P': <String>['莆田', '攀枝花', '平顶山'],
    'Q': <String>['青岛', '泉州', '齐齐哈尔'],
    'S': <String>['苏州', '沈阳', '石家庄'],
    'T': <String>['天津', '太原', '台州'],
    'W': <String>['武汉', '无锡', '温州'],
    'X': <String>['厦门', '西安', '徐州'],
    'Y': <String>['延安', '烟台', '宜昌'],
    'Z': <String>['郑州', '珠海', '中山'],
  };

  /// 展平后的行：分组首行是字母，其余是城市。
  static final List<String> _rows = <String>[
    for (final String letter in _letters) ...<String>[
      letter,
      ..._cities[letter]!,
    ],
  ];

  /// 字母 → 分组首行的行号，`jumpTo` 与受控高亮共用。
  static final Map<String, int> _firstRow = _buildFirstRow();

  static Map<String, int> _buildFirstRow() {
    final Map<String, int> offsets = <String, int>{};
    int row = 0;
    for (final String letter in _letters) {
      offsets[letter] = row;
      row += 1 + _cities[letter]!.length;
    }
    return offsets;
  }

  final ScrollController _scroller = ScrollController();
  int _selected = 0;
  bool _showMagnifier = true;
  bool _customBubble = false;

  @override
  void dispose() {
    _scroller.dispose();
    super.dispose();
  }

  void _jumpTo(String letter) {
    final int? row = _firstRow[letter];
    if (row == null) {
      return;
    }
    if (_scroller.hasClients) {
      final double target = row * _rowExtent;
      final double max = _scroller.position.maxScrollExtent;
      _scroller.jumpTo(target > max ? max : target);
    }
    setState(() => _selected = _letters.indexOf(letter));
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: <Widget>[
            _toggle(
              '拖动放大镜',
              _showMagnifier,
              (bool value) => setState(() => _showMagnifier = value),
            ),
            _toggle(
              '自定义泡泡',
              _customBubble,
              (bool value) => setState(() => _customBubble = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      border: demoFrameBorder(context, theme),
                    ),
                    child: ListView.builder(
                      controller: _scroller,
                      itemExtent: _rowExtent,
                      itemCount: _rows.length,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final String text = _rows[index];
                        final bool header = _firstRow.containsKey(text);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            text,
                            style: theme.typography.bodySmall?.copyWith(
                              color: header
                                  ? theme.highlightColor
                                  : theme.textSecondaryColor,
                              fontWeight: header
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            OhosAlphabetIndexer(
              indexer: _letters,
              size: const Size(24, 220),
              selectedIndex: _selected,
              showMagnifier: _showMagnifier,
              // 泡泡内容换成品牌色圆角方块；仍走同一套落点求解。
              magnifierBuilder: _showMagnifier && _customBubble
                  ? (BuildContext context, String letter) =>
                        _CustomMagnifierBubble(letter: letter)
                  : null,
              // 过程：跨一格就定位一次，列表跟着手指走。
              onSelected: _jumpTo,
              // 结果：抬手报一次最终字母。挂在 onSelected 上会每跨一格插一层
              // Overlay（每层存活 2 秒），拖过几个字母就在屏幕中央叠成一片。
              onSelectEnd: (String letter) => showOhosToast(
                context,
                '定位到 $letter',
                position: OhosToastPosition.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OhosButton(
          style: OhosButtonStyle.tonal,
          onPressed: () => _jumpTo('M'),
          child: const Text('代码定位到 M（selectedIndex）'),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Row(
      children: <Widget>[
        OhosCheckbox(value: value, size: 20, onChanged: onChanged),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

/// `magnifierBuilder` 的返回值会被放进 48vp 的泡泡里（超出等比缩小），
/// 自定义内容要守住这个尺寸。
class _CustomMagnifierBubble extends StatelessWidget {
  const _CustomMagnifierBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.highlightColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          inherit: false,
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 独立放大镜：`show` / `update` / `hide` 挂在拖动的三段上。
///
/// 泡泡进的是根 `Overlay`，所以它能画在这条色带之外；`IgnorePointer` 保证
/// 拖动的手势仍然归色带自己。
class _MagnifierDemo extends StatefulWidget {
  const _MagnifierDemo();

  @override
  State<_MagnifierDemo> createState() => _MagnifierDemoState();
}

class _MagnifierDemoState extends State<_MagnifierDemo> {
  static const List<_Swatch> _swatches = <_Swatch>[
    _Swatch(Color(0xFF0A59F7), '#0A59F7'),
    _Swatch(Color(0xFF24B7A4), '#24B7A4'),
    _Swatch(Color(0xFF64BB5C), '#64BB5C'),
    _Swatch(Color(0xFF8BD700), '#8BD700'),
    _Swatch(Color(0xFFFFD900), '#FFD900'),
    _Swatch(Color(0xFFF9A01E), '#F9A01E'),
    _Swatch(Color(0xFFED6B2A), '#ED6B2A'),
    _Swatch(Color(0xFFE84026), '#E84026'),
    _Swatch(Color(0xFFD74187), '#D74187'),
    _Swatch(Color(0xFF8B7FE8), '#8B7FE8'),
    _Swatch(Color(0xFF5E90F3), '#5E90F3'),
    _Swatch(Color(0xFF767676), '#767676'),
  ];

  final OhosMagnifierController _magnifier = OhosMagnifierController();
  final GlobalKey _stripKey = GlobalKey();
  int _index = 0;

  @override
  void dispose() {
    _magnifier.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _hit(details.localPosition);
    _magnifier.show(
      context,
      anchor: details.globalPosition,
      child: _HexBubble(swatch: _swatches[_index]),
      bubble: const Size(112, 44),
      gap: 16,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _hit(details.localPosition);
    _magnifier.update(
      details.globalPosition,
      child: _HexBubble(swatch: _swatches[_index]),
    );
  }

  void _hit(Offset local) {
    final RenderBox? box =
        _stripKey.currentContext?.findRenderObject() as RenderBox?;
    final double width = box?.size.width ?? 0;
    if (width <= 0) {
      return;
    }
    final int next = (local.dx / width * _swatches.length).floor().clamp(
      0,
      _swatches.length - 1,
    );
    if (next != _index) {
      setState(() => _index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 泡泡本身就是个 Widget，静态摆出来也能看清算法给的落点长什么样。
        const Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OhosMagnifier(text: 'M'),
            OhosMagnifier(text: 'Z', size: Size.square(60)),
            OhosMagnifier(
              size: Size(112, 44),
              child: _HexBubble(swatch: _Swatch(Color(0xFF0A59F7), '#0A59F7')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '左右拖动色带，泡泡跟着手指报出色值',
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        // 这条色带是**取色器的数据源**：观感上它就该是十二个真彩块，
        // 量化成灰之后「拖到紫色报 #8B7FE8」这件事就演示不了了。
        InkColorData(
          child: GestureDetector(
            key: _stripKey,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (DragEndDetails details) => _magnifier.hide(),
            onHorizontalDragCancel: () => _magnifier.hide(),
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < _swatches.length; i++)
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _swatches[i].color,
                            border: i == _index
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          // 无子节点的 DecoratedBox 在松散高度约束下会塌成 0 高：
                          // 给它一个撑满的壳，色块才真的画出来。
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch {
  const _Swatch(this.color, this.label);

  final Color color;
  final String label;
}

class _HexBubble extends StatelessWidget {
  const _HexBubble({required this.swatch});

  final _Swatch swatch;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Container(
      height: 44,
      alignment: Alignment.center,
      // 宽度交给外层泡泡（`bubble` 尺寸 + FittedBox）：大字号下文字变宽时
      // 整块等比缩小，而不是把固定 112vp 的胶囊撑破。
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 泡泡里的色点是**被报出的那个色值本身**，和旁边那行 `#0A59F7`
          // 同属数据：量化成灰之后，泡泡会显示「灰圆点 + #0A59F7」，自相矛盾。
          InkColorData(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: swatch.color,
                shape: BoxShape.circle,
                border: Border.all(color: demoFrameColor(theme)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            swatch.label,
            style: TextStyle(
              inherit: false,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollbarDemo extends StatefulWidget {
  const _ScrollbarDemo();

  @override
  State<_ScrollbarDemo> createState() => _ScrollbarDemoState();
}

class _ScrollbarDemoState extends State<_ScrollbarDemo> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return SizedBox(
      height: 90,
      child: OhosScrollbar(
        controller: _controller,
        child: ListView.builder(
          controller: _controller,
          itemCount: 20,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('第 $index 行', style: theme.typography.bodySmall),
          ),
        ),
      ),
    );
  }
}

class _DataPanelDemo extends StatefulWidget {
  const _DataPanelDemo();

  @override
  State<_DataPanelDemo> createState() => _DataPanelDemoState();
}

class _DataPanelDemoState extends State<_DataPanelDemo> {
  /// 官方示例的 `values: [50, 12, 8, 5]`、`max: 100`：四段共 75%，剩下四分之一
  /// 是底槽 —— 一眼能看出「标尺」与「铺满」的区别。
  static const List<double> _values = <double>[50, 12, 8, 5];

  /// `max <= 0` 时按数组之和铺满，段数一样、观感完全不同。
  bool _fill = false;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 132,
              child: OhosDataPanel(
                values: _values,
                max: _fill ? 0 : 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _fill ? '100' : '75',
                      style: theme.typography.titleLarge?.copyWith(
                        color: theme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _fill ? '按和铺满' : 'max 100',
                      style: theme.typography.labelSmall?.copyWith(
                        color: theme.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '环形',
                    style: theme.typography.bodySmall?.copyWith(
                      color: theme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OhosDataPanel(
                    values: _values,
                    max: _fill ? 0 : 100,
                    trackShadow: _fill ? null : const OhosDataPanelShadow(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '线形',
          style: theme.typography.bodySmall?.copyWith(
            color: theme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: OhosDataPanel(
            values: _values,
            max: _fill ? 0 : 100,
            type: OhosDataPanelType.line,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OhosButton(
            style: OhosButtonStyle.text,
            onPressed: () => setState(() => _fill = !_fill),
            child: Text(_fill ? '改回 max 100' : '改成 max 0（按和铺满）'),
          ),
        ),
      ],
    );
  }
}

class _GaugeDemo extends StatefulWidget {
  const _GaugeDemo();

  @override
  State<_GaugeDemo> createState() => _GaugeDemoState();
}

class _GaugeDemoState extends State<_GaugeDemo> {
  double _value = 60;

  /// 官方示例 1 的九段配色（饱和度由暖到冷），每段等权。
  static const List<OhosGaugeSegment> _nineSegments = <OhosGaugeSegment>[
    OhosGaugeSegment(color: Color(0xFFDEB6FB), endColor: Color(0xFFAC49F5)),
    OhosGaugeSegment(color: Color(0xFFBBB7FC), endColor: Color(0xFF564AF7)),
    OhosGaugeSegment(color: Color(0xFFF5B5C2), endColor: Color(0xFFE64566)),
    OhosGaugeSegment(color: Color(0xFFF8C5A6), endColor: Color(0xFFED6F21)),
    OhosGaugeSegment(color: Color(0xFFFCEB99), endColor: Color(0xFFF7CE00)),
    OhosGaugeSegment(color: Color(0xFFDBEFA5), endColor: Color(0xFFA5D61D)),
    OhosGaugeSegment(color: Color(0xFFC1E4BE), endColor: Color(0xFF64BB5C)),
    OhosGaugeSegment(color: Color(0xFFC0ECE5), endColor: Color(0xFF61CFBE)),
    OhosGaugeSegment(color: Color(0xFFB5E0F4), endColor: Color(0xFF46B1E3)),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      children: <Widget>[
        // 两个 140 见方并排需要 360 + 内边距。窄屏（320vp 档）放不下 ——
        // 静态分析看不见，只有真布局才炸（溢出 24px）。用 `LayoutBuilder`
        // 按可用宽度缩：圆的直径跟着屏宽走，标签字号不动。
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double side = math.min(140, (constraints.maxWidth - 24) / 2);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: side,
                      child: OhosGauge(
                        value: _value,
                        min: 0,
                        max: 100,
                        startAngle: 225,
                        endAngle: 135,
                        strokeWidth: 18,
                        child: Text(
                          _value.toStringAsFixed(0),
                          style: theme.typography.headlineMedium?.copyWith(
                            color: theme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '默认渐变环',
                      style: theme.typography.labelSmall?.copyWith(
                        color: theme.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: side,
                      child: OhosGauge(
                        value: _value,
                        min: 0,
                        max: 100,
                        startAngle: 210,
                        endAngle: 150,
                        strokeWidth: 14,
                        segments: _nineSegments,
                        // 九段等分后每段都不到 24°，指针比环更抢眼；官方示例 6
                        // 就是这一档用 `indicator(null)` 把指针关掉。
                        showIndicator: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '九段 · 无指针',
                      style: theme.typography.labelSmall?.copyWith(
                        color: theme.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        Slider(
          value: _value,
          max: 100,
          onChanged: (double v) => setState(() => _value = v),
        ),
      ],
    );
  }
}

class _PopupDemo extends StatelessWidget {
  const _PopupDemo();

  @override
  Widget build(BuildContext context) {
    final GlobalKey key = GlobalKey();
    return Column(
      children: <Widget>[
        OhosButton(
          key: key,
          onPressed: () => showOhosPopup(
            context: context,
            content: '示例气泡提示内容',
            targetKey: key,
          ),
          style: OhosButtonStyle.tonal,
          child: const Text('长按/点击查看气泡'),
        ),
      ],
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({
    required this.width,
    required this.height,
    this.selected = false,
    this.fit = OhosImageFit.cover,
  });

  final double width;
  final double height;
  final bool selected;
  final OhosImageFit fit;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return OhosImage(
      width: width,
      height: height,
      selected: selected,
      fit: fit,
      image: const NetworkImage('https://picsum.photos/seed/ohos1/200/120'),
      placeholder: Container(
        color: theme.textTertiaryColor.withValues(alpha: 0.1),
        alignment: Alignment.center,
        child: Icon(
          OhosIcons.picture,
          size: 20,
          color: theme.textTertiaryColor,
        ),
      ),
    );
  }
}

/// 墨主题下的几种典型组件：纯色分层、1px 黑线、无模糊无阴影。
class _InkThemeDemo extends StatelessWidget {
  const _InkThemeDemo();

  @override
  Widget build(BuildContext context) {
    return OhosTheme(
      data: OhosThemeData.ink(),
      child: Builder(
        builder: (BuildContext context) {
          final OhosThemeData ink = OhosTheme.of(context);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ink.backgroundColor,
              border: Border.all(color: ink.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '纯黑正文，纯白底',
                  style: TextStyle(color: ink.textPrimaryColor, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '提示文字 #767676：仍明显淡于正文',
                  style: TextStyle(color: ink.textTertiaryColor, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // 窄窗口放不下一行：用 Wrap 让它自动换行，而不是溢出
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    OhosButton(onPressed: () {}, child: const Text('主要按钮')),
                    OhosButton(
                      style: OhosButtonStyle.outlined,
                      onPressed: () {},
                      child: const Text('次要按钮'),
                    ),
                    const OhosSwitch(value: true, onChanged: _noop),
                  ],
                ),
                // 灰色半透明填充在 16 级灰上的存活情况：这几态最容易整块消失
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    OhosButton(onPressed: null, child: const Text('禁用填充')),
                    OhosButton(
                      style: OhosButtonStyle.tonal,
                      onPressed: null,
                      child: const Text('禁用 tonal'),
                    ),
                    OhosButton(
                      style: OhosButtonStyle.outlined,
                      onPressed: null,
                      child: const Text('禁用描边'),
                    ),
                    OhosButton(
                      onPressed: () {},
                      loading: true,
                      child: const Text('加载中'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    OhosCheckbox(value: false, onChanged: _noopBool),
                    OhosCheckbox(value: true, onChanged: _noopBool),
                    OhosCheckbox(value: true, onChanged: null),
                    OhosRadio(value: false, onChanged: _noopBool),
                    OhosRadio(value: true, onChanged: _noopBool),
                    const OhosSwitch(value: false, onChanged: _noop),
                  ],
                ),
                const SizedBox(height: 8),
                OhosSegmentedButton<String>(
                  segments: const <OhosSegment<String>>[
                    OhosSegment<String>(label: '日', value: 'day'),
                    OhosSegment<String>(label: '周', value: 'week'),
                    OhosSegment<String>(label: '月', value: 'month'),
                  ],
                  selected: 'week',
                  onSelected: _noopSegment,
                ),
                const SizedBox(height: 8),
                OhosProgressIndicator.linear(value: 0.4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    OhosChip(label: const Text('未选纸片'), onPressed: () {}),
                    OhosChip(
                      label: const Text('选中纸片'),
                      selected: true,
                      onPressed: () {},
                    ),
                    OhosBadge(
                      count: 3,
                      child: Icon(
                        Icons.mail_outline,
                        color: ink.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OhosSlider(
                  value: 30,
                  onChanged: _noopDouble,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  // 墨屏下气泡与页面同为纯白，靠描边读出来 —— 拖一下就能对照
                  showValueBubble: true,
                ),
                const SizedBox(height: 8),
                OhosTextField(hintText: '下划线输入框'),
                const SizedBox(height: 12),
                OhosDivider(color: ink.dividerColor, indent: 0, thickness: 1),
                const SizedBox(height: 8),
                OhosLightMaterial(
                  level: OhosLightMaterialLevel.ultraThick,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'ULTRA_THICK 在这里是一块纯色，不是磨砂玻璃',
                      style: TextStyle(color: ink.textPrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 默认白底的容器与页面同色：卡片、搜索框胶囊靠 1px 实线立住
                OhosCard(
                  child: Text(
                    '卡片：默认面补 1px 实线',
                    style: TextStyle(color: ink.textPrimaryColor),
                  ),
                ),
                const SizedBox(height: 8),
                const OhosSearchBar(hintText: '搜索框胶囊也补了描边'),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _noop(bool value) {}

  static void _noopBool(bool value) {}

  static void _noopDouble(double value) {}

  static void _noopSegment(String value) {}
}
