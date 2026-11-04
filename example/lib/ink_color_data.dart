import 'package:flutter/widgets.dart';

/// 把子树里的颜色标记为「**颜色本身就是被展示的数据**」，墨水屏上不参与
/// 「不应有彩色」的检查。
///
/// 只该用在色板、放大镜取色带这类地方：那里的 `#0A59F7` 不是在表达品牌色或
/// 状态，它**就是内容**。把它量化成灰，等于把示例要演示的东西改掉了 ——
/// 取色器报出的 `#767676` 必须真的显示成 `#767676`。
///
/// 这个标记只被 `test/ink_no_color_test.dart` 读取，运行时不产生任何 UI
/// （纯粹透传 child）。它放在 example 而不是库里的原因：这是**示例与它自己的
/// 截图测试之间的约定**，库对「哪些颜色算数据」没有意见。
///
/// 反过来说，**不给标记就等于承诺「这块颜色应该跟着主题退化」**。想偷懒时
/// 加标记会让测试立刻变绿，但截图里的彩色残留会继续存在 —— 所以每加一个
/// 标记都该问一次：换成灰之后，这块区域还看得懂吗？
class InkColorData extends StatelessWidget {
  const InkColorData({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}