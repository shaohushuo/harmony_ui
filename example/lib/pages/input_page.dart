import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

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
        DemoSection(
          title: '搜索框 OhosSearchBar',
          description: '胶囊搜索框，实时回显输入。当前: "$_query"',
          child: OhosSearchBar(
            hintText: '搜索应用、设置、文件',
            onChanged: (String q) => setState(() => _query = q),
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
      ],
    );
  }
}

void _noopPattern(List<int> pattern) {}
