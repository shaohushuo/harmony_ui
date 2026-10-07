import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

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
          title: '子标题 OhosSubheader',
          description: '区块标题，可带尾部链接。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                OhosSubheader(title: '热门推荐', trailing: '更多'),
                OhosSubheader(title: '最近使用', trailing: '查看全部'),
                OhosSubheader(title: '本地服务'),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '分隔器 OhosDivider',
          description: '列表分隔线，支持缩进控制。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                OhosListTile(title: Text('默认缩进 16')),
                OhosListTile(title: Text('自定义缩进 56')),
                OhosDivider(indent: 8, endIndent: 8, height: 16),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: OhosDivider(indent: 0, endIndent: 0),
                ),
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
          description: '右侧字母索引，点击 / 拖动快速定位。',
          child: DemoCard(child: _IndexerDemo()),
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
        const DemoSection(
          title: '数据可视化 OhosDataPanel',
          description: '指标卡片面板，支持前缀 / 后缀与小数位。',
          child: DemoCard(
            child: OhosDataPanel(
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
          title: '二维码 OhosQrCode',
          description: '生成二维码，自动包含静区。',
          child: DemoCard(
            child: Center(
              child: OhosQrCode(data: 'https://github.com/shaohushuo/ohos_ui'),
            ),
          ),
        ),
        const DemoSection(
          title: '文本时钟 OhosTextClock',
          description: '每秒刷新，支持自定义格式。',
          child: DemoCard(
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: <Widget>[
                OhosTextClock(format: 'HH:mm:ss'),
                OhosTextClock(format: 'yyyy年MM月dd日'),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '图片 OhosImage',
          description: '圆角图片容器，支持选中描边。',
          child: DemoCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _PlaceholderImage(width: 96, height: 64),
                _PlaceholderImage(width: 96, height: 64, selected: true),
                _PlaceholderImage(width: 96, height: 64),
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
      children: <Widget>[
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            OhosProgressIndicator.circular(),
            OhosProgressIndicator.circular(
              value: 0.6,
              size: 56,
              strokeWidth: 6,
            ),
            OhosProgressIndicator.circular(
              value: 1.0,
              size: 40,
              color: Color(0xFF64BB5C),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OhosProgressIndicator.linear(value: _value),
        const SizedBox(height: 12),
        const OhosProgressIndicator.linear(),
      ],
    );
  }
}

class _IndexerDemo extends StatelessWidget {
  const _IndexerDemo();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '城市列表：点击右侧字母定位',
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textSecondaryColor,
              ),
            ),
          ),
        ),
        OhosAlphabetIndexer(
          indexer: const <String>[
            'A',
            'B',
            'C',
            'D',
            'E',
            'F',
            'G',
            'H',
            'I',
            'J',
            'K',
            'L',
            'M',
            'N',
            'O',
            'P',
            'Q',
            'R',
            'S',
            'T',
            'U',
            'V',
            'W',
            'X',
            'Y',
            'Z',
            '#',
          ],
          size: const Size(24, 270),
          itemHeight: 10,
          onSelected: (String c) => showOhosToast(
            context,
            '选中 $c',
            position: OhosToastPosition.center,
          ),
        ),
      ],
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
  });

  final double width;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return OhosImage(
      width: width,
      height: height,
      selected: selected,
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
