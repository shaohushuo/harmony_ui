import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// 输入类：文本框 / 搜索框 / 数字加减 / 图案锁
class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  String _query = '';
  int _count = 1;
  OhosDate _date = const OhosDate(year: 2024, month: 3, day: 7);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: '输入类',
      children: <Widget>[
        const DemoSection(
          title: '文本框 OhosTextField',
          description: '下划线输入框：正常 / 聚焦 / 错误三种状态。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                OhosTextField(
                  labelText: '用户名',
                  hintText: '请输入用户名',
                  prefixIcon: Icon(OhosIcons.person, size: 20),
                ),
                SizedBox(height: 14),
                OhosTextField(
                  labelText: '密码',
                  hintText: '请输入密码',
                  obscureText: true,
                  prefixIcon: Icon(OhosIcons.lock_fill, size: 20),
                ),
                SizedBox(height: 14),
                OhosTextField(
                  labelText: '邮箱',
                  hintText: '例如 name@example.com',
                  errorText: '邮箱格式不正确',
                  prefixIcon: Icon(OhosIcons.message_fill, size: 20),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '输入框另两种形态（填充 / 胶囊）',
          description:
              'variant: filled 是鸿蒙表单常见的灰底圆角块（墨水屏上填充色等于背景色，'
              '会自动退回透明底 + 1px 线）；capsule 用于筛选入口，配 suffixIcon。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                OhosTextField(
                  labelText: '昵称',
                  hintText: '已填写内容',
                  variant: OhosTextFieldVariant.filled,
                  suffixIcon: Icon(Icons.check_circle_outline, size: 20),
                ),
                SizedBox(height: 14),
                OhosTextField(
                  hintText: '搜索项目',
                  variant: OhosTextFieldVariant.capsule,
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
        // 这一节不能整体 const：onSecurityStateChange 的闭包捕获了 context，
        // 常量表达式里不允许引用运行时的 BuildContext。
        DemoSection(
          title: '密码模式（末尾眼睛图标）',
          description:
              'obscurePassword 不只是遮蔽内容，它还带一整套密码形态：末尾 24vp 的眼睛'
              '图标、40vp 的命中区、点一下切换显隐。obscureText 也能拿到同一套（两者是'
              '同一形态的两个入口）。showPasswordIcon: false 保留遮蔽但不给切换入口。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                OhosTextField(
                  labelText: '密码',
                  hintText: '点右侧眼睛切换显隐',
                  obscurePassword: true,
                  prefixIcon: const Icon(OhosIcons.lock_fill, size: 20),
                  onSecurityStateChange: (bool visible) =>
                      showOhosToast(context, visible ? '密码已显示' : '密码已隐藏'),
                ),
                const SizedBox(height: 14),
                const OhosTextField(
                  labelText: '确认密码',
                  hintText: '不给切换入口，只能遮蔽',
                  obscurePassword: true,
                  showPasswordIcon: false,
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '内联模式（整行重命名）',
          description:
              'variant: inline 对应 ArkUI 的 TextInputStyle.Inline —— 圆角 4、'
              '描边 2（官方 INLINE_BORDER_WIDTH）、上下各 2 内边距、右侧 12。'
              '左侧文字与框线的距离由 InputDecorator 的 4vp 基线承担，与官方'
              '配图的 4.5 基本一致。官方限定只支持 Normal 单行：给 '
              'obscurePassword 或 maxLines > 1 会回落成下划线形态，不画官方'
              '不存在的「内联密码框」。',
          child: DemoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('项目名称', style: TextStyle(fontSize: 14)),
                OhosTextField(
                  initialValue: '鸿蒙风格组件库',
                  variant: OhosTextFieldVariant.inline,
                ),
                SizedBox(height: 14),
                Text('另一行', style: TextStyle(fontSize: 14)),
                OhosTextField(
                  initialValue: '点进来就能改',
                  variant: OhosTextFieldVariant.inline,
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '字数计数器',
          description:
              'showCounter + maxLength。阈值 50% 才出现（6 字上限里第 4 个字开始显示）；'
              '超限时计数文字变 warning 色。注意官方的两条互斥：内联模式、密码模式下'
              '计数器都不显示 —— 本组件直接跳过，不画半成品。',
          child: DemoCard(
            child: Column(
              children: <Widget>[
                OhosTextField(
                  labelText: '昵称',
                  hintText: '最多 6 个字',
                  maxLength: 6,
                  showCounter: true,
                  counterOptions: OhosInputCounterOptions(
                    thresholdPercentage: 50,
                  ),
                ),
                SizedBox(height: 14),
                OhosTextField(
                  labelText: '签名',
                  hintText: '一有输入就显示计数',
                  maxLength: 20,
                  showCounter: true,
                ),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '搜索框 OhosSearchBar',
          description: '胶囊搜索框，实时回显输入。当前: "$_query"；聚焦后右侧出现「取消」。',
          child: OhosSearchBar(
            hintText: '搜索应用、设置、文件',
            onChanged: (String q) => setState(() => _query = q),
            onClear: () => setState(() => _query = ''),
            onCancel: () => setState(() => _query = ''),
            onSubmitted: (String q) => showOhosToast(context, '搜索: $q'),
          ),
        ),
        DemoSection(
          title: '数字加减 OhosCounter',
          description: '步进器，min=0 max=9。当前值: $_count',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosCounter(
                  value: _count,
                  min: 0,
                  max: 9,
                  onChanged: (int v) => setState(() => _count = v),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '图案锁 OhosPatternLock',
          description: '3×3 手势密码，抬手返回点位序列。',
          child: DemoCard(
            child: Center(child: OhosPatternLock(onCompleted: _noopPattern)),
          ),
        ),
        DemoSection(
          title: '日期加减 OhosDateCounter',
          description:
              'CounterType.INLINE_DATE：YYYY / MM / DD 三段可点可输。'
              '点中哪一段，右侧箭头就加减哪一段 —— 没点过时默认作用于「日」。'
              '当前: $_date',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosDateCounter(
                  value: _date,
                  upIcon: OhosIcons.arrow_up,
                  downIcon: OhosIcons.arrow_down,
                  onChanged: (OhosDate v) => setState(() => _date = v),
                ),
                const SizedBox(width: OhosGeometry.spaceMd),
                Flexible(
                  child: Text(
                    // 三段各自的回绕规则不同：年夹取、月回绕不进位、日按当月
                    // 长度回绕。放一行提示，免得把「12 月加一月还是 12 月」
                    // 当成 bug。
                    '月/日回绕：12 月 +1 → 1 月，当月最后一天 +1 → 1 号',
                    style: TextStyle(
                      fontSize: 12,
                      color: OhosTheme.of(context).textTertiaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _noopPattern(List<int> pattern) {}
