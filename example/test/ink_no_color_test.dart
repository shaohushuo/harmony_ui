import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'package:ohos_ui_example/ink_color_data.dart';
import 'package:ohos_ui_example/pages/action_page.dart';
import 'package:ohos_ui_example/pages/container_page.dart';
import 'package:ohos_ui_example/pages/display_page.dart';
import 'package:ohos_ui_example/pages/input_page.dart';
import 'package:ohos_ui_example/pages/kit_page.dart';
import 'package:ohos_ui_example/pages/layout_page.dart';
import 'package:ohos_ui_example/pages/navigation_page.dart';
import 'package:ohos_ui_example/pages/selection_page.dart';

/// 墨水屏（ink 主题）下「不要有彩色」的回归测试。
///
/// ## 为什么需要这条
///
/// README 的「墨水屏」图集是用 `tool/capture_theme.sh` 在真机上截的。那条链路
/// 有个**看不出来的失败方式**：截图里留着一块彩色，读者会以为「主题没切」，
/// 而主题其实切对了 —— 彩色来自示例自己画的占位内容（沉浸光感的壁纸、
/// 轮播的纯色页、动效曲线的填充条）。这些内容既不是组件的令牌，也不是
/// 组件的状态表达，`policy` 管不到它们，所以**库层的测试全绿**也拦不住。
///
/// 已经因此重拍过一次：`布局与动效` 页的曲线条写死 `0xFF0A59F7`，注释还写着
/// 「55% 品牌蓝压到灰阶上是中灰」—— 那句话对 16 级灰的真机成立，对截图不成立。
///
/// ## 判据：默认必须灰，数据要显式申报
///
/// 扫两类节点，缺一类都会漏：
///
/// 1. **所有 `DecoratedBox`** —— 取它实际发出的 `BoxDecoration`：
///    - `color` 透明或缺失 → 跳过；
///    - 祖先链上有 [InkColorData] → 跳过（「颜色本身就是数据」，如取色带）；
///    - 渐变非空 → 失败（渐变必然在某个插值处偏离灰阶）；
///    - 实色的 `r/g/b` 不相等 → 失败。
/// 2. **所有 `Icon`** —— 取 `Icon.color`，判据同上（透明跳过、`InkColorData`
///    跳过、通道不等失败）。
///
/// 第 2 类是第一版漏掉的：第一版只扫 `DecoratedBox`，于是 `容器类` 页里三个
/// `Icon(color: Color(0xFF0A59F7))` 从测试里溜过去，**八条用例全绿**，而截图里
/// 列表图标是蓝的。`Icon` 的颜色不走 `DecoratedBox` —— 它最终由 `RichText` 的
/// `TextSpan.style.color` 决定，是另一条完全不同的渲染路径。**「扫了装饰」不等于
/// 「扫了所有上色的地方」**，这是同一个错误模式（判据看起来在检查、实际检查不到
/// 那一类对象）的第三次发作，前两次分别是面积判据和 `light`/`dark` 共用判据。
///
/// 试过、**不行**的判据：按「单块面积占比」放行小色块。曲线对比条是四条
/// `358×10`，每块只占 1% 屏，四条加起来却是一整片彩色带 —— 逐块面积看不见
/// 这种「一组小条拼成的彩带」，变异验证时它放任了真实缺陷。面积是**渲染后**
/// 的属性，而缺陷出在**源码**里；判据必须落在能改的地方。
///
/// 也试过「近中性灰/过暗放行」：`#101418` 这类通道差 8 的颜色确实看不出来，
/// 但把它设为阈值后，`#0A59F7` 与阈值之间没有可辩护的分界线。宁可让示例
/// 显式申报数据，也不给颜色猜一个宽容度。
/// 用来抓像素的边界。
///
/// **必须是每个用例新建的一个实例**：`GlobalKey` 全局只能挂一个
/// `RepaintBoundary`，八个用例共用一个 key 会在第二次 `pumpWidget` 时因
/// 「同一个 key 挂在两棵树上」报错。用 `static` 也可以绕开（前一个用例的树
/// 已销毁），但那样就依赖了销毁顺序。
final GlobalKey _boundaryKey = GlobalKey();

void main() {
  final Map<String, Widget> pages = <String, Widget>{
    'action': const ActionPage(),
    'container': const ContainerPage(),
    'display': const DisplayPage(),
    'input': const InputPage(),
    'kit': const KitPage(),
    'layout': const LayoutPage(),
    'navigation': const NavigationPage(),
    'selection': const SelectionPage(),
  };

  for (final MapEntry<String, Widget> page in pages.entries) {
    testWidgets('${page.key} 页在墨水屏下不产生彩色', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _boundaryKey,
            child: OhosTheme(data: OhosThemeData.ink(), child: page.value),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final List<String> offenders = <String>[];

      // 滚动**不用 `tester.drag`**，直接改视口位置。
      //
      // 这条看起来只是写法偏好，实际是这条测试第一版**假绿**的原因：`drag` 从
      // `find.byType(Scrollable).first` 的中心点按下，而页面中段的中心点会落在
      // 横向滑动的内容上（`横滑列表项`），外层垂直视口从此拿不到手势 ——
      // 实测滚到 1680vp 就再也不动，`maxScrollExtent` 却是 3662。
      //
      // 当时的表现极具误导性：每屏扫到的装饰节点数恒为 29，八条用例全绿，
      // 而页面下半部分（颜色选择器色板、分层图标）**从来没被扫过**。判据没写错，
      // 是**它没被跑到**。这和「判据看起来在检查、实际检查不到那一类对象」是
      // 同一个错误模式的另一面：这次连判据本身都没被送达目标。
      //
      // 回归测试要确认的是「整页没有彩色」，不是「页面能滚动」。所以直接
      // `jumpTo` 到下一屏：确定、可控，且不依赖任何控件的手势实现。
      final ScrollableState viewport = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      // 是否滚到过页底 —— 见循环之后的断言。
      bool reachedEnd = false;
      for (int screen = 0; screen < 40; screen++) {
        for (final Element element in find.byType(DecoratedBox).evaluate()) {
          if (_insideColorData(element)) {
            continue;
          }
          final Decoration decoration =
              (element.widget as DecoratedBox).decoration;
          if (decoration is! BoxDecoration) {
            continue;
          }
          final String? problem = _describeColor(decoration);
          if (problem != null) {
            offenders.add(
              '$problem  ${tester.getRect(find.byWidget(element.widget))}',
            );
          }
        }
        for (final Element element in find.byType(Icon).evaluate()) {
          if (_insideColorData(element)) {
            continue;
          }
          final String? problem = _describeColorValue(
            (element.widget as Icon).color,
          );
          if (problem != null) {
            offenders.add(
              'ICON $problem  ${tester.getRect(find.byWidget(element.widget))}',
            );
          }
        }
        // 第三条判据：**直接量像素**。
        //
        // 前两条扫的是 widget 属性，而有些控件根本不通过属性上色 ——
        // `ChoiceChip` 的选中底色由 `RawChip` 在**自定义 RenderObject 的 paint()**
        // 里画（实测它的 `Material.color` 是 `#FEF7FF`，`DecoratedBox` 里也没有
        // 那个淡紫），扫组件树在结构上就看不见它。
        //
        // 这条判据是变异验证逼出来的：把导航页的 `OhosChip` 换回 `ChoiceChip`
        // 之后，前两条判据全绿 —— 而真机截图里那些 chip 分明是淡紫的。**判据
        // 又一次「看起来在检查、实际检查不到那一类对象」**，这是第四次。
        //
        // 像素判据用「通道差 ≥ 12」作阈值，不用比值：比值在近黑处失真 ——
        // `(1,0,0)` 的比值算出来是 1.0（看着像纯红），但它就是纯黑加一点抗锯齿。
        // 早先用比值扫真机截图时，`展示类_05` 被报了 2 个「彩色点」，实际是
        // 文字边缘的次像素渲染。
        final List<Rect> colorDataRects = <Rect>[
          for (final Element element in find.byType(InkColorData).evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ];
        final String? pixelProblem = await _describePixels(
          tester,
          _boundaryKey,
          colorDataRects,
        );
        if (pixelProblem != null) {
          offenders.add('PIXEL $pixelProblem');
        }
        // 下一屏：按视口高度走，末尾会被 `ScrollPosition` 自己夹到 `maxScrollExtent`。
        final double next = viewport.position.pixels + 420;
        if (next > viewport.position.maxScrollExtent) {
          // 已经到底，再滚也不会出现新内容。
          reachedEnd = true;
          break;
        }
        viewport.position.jumpTo(next);
        await tester.pump(const Duration(milliseconds: 200));
      }

      // 扫完**必须**真的到过页底，否则「八条用例全绿」只说明「上面那半页没
      // 彩色」。这一句是给上一条注释配的守卫：判据的送达范围本身也要断言，
      // 不然下次改回任何一种「滚动到一半就不动了」的写法，测试又悄悄变回假绿。
      //
      // 用 `pixels >= maxScrollExtent` 而不是「循环跑满 40 次」：页面长短会
      // 随示例增删变化，跑满次数什么都不能证明。
      expect(
        reachedEnd,
        isTrue,
        reason:
            '没滚到页底（停在 ${viewport.position.pixels} / '
            '${viewport.position.maxScrollExtent}）—— 下半页没被扫过，'
            '这条用例的「全绿」不算数',
      );

      if (offenders.isNotEmpty) {
        // 去重：同一块装饰在多屏里会重复出现。
        final List<String> unique = offenders.toSet().toList();
        fail(
          '墨水屏下仍有彩色装饰（${unique.length} 处）：\n'
          '${unique.take(8).join('\n')}\n\n'
          '修法二选一：\n'
          '  1. 这块颜色应该跟着主题退化 → 交给 theme.policy.quantize(...)；\n'
          '  2. 这块颜色本身就是数据（色板、取色带）→ 用 InkColorData 包起来。',
        );
      }
    });
  }
}

/// 把当前帧截成位图，按 8×8 物理像素分块取均值，数一数「偏色块」有多少。
///
/// 这是唯一能覆盖「自定义 `RenderObject.paint()` 上色」的判据 —— 扫 widget
/// 属性对那类控件在结构上就看不见（`ChoiceChip` 即如此）。
///
/// ## 为什么按块均值 + 数块数，而不是逐像素判
///
/// 两条都必须，缺一条就会被误报淹掉：
///
/// 1. **按块取均值**：本库正文色是官方的 `text_primary` `#182431`，通道差 25。
///    它的字形边缘落在白底上就是 `rgb(24,36,49)` 这种像素，密度 1/8 后块均值
///    的通道差才降到个位数。逐像素判会把它当彩色。
/// 2. **数块数而不是首命中即失败**：即使用块均值，仍有零星几块压在阈值上
///    （实测最大的一块来自 `#182431` 的粗笔画交叠处）。而**真彩色是一大片** ——
///    一整块淡紫底（`#E8DEF8`）在任何缩放比下都是几十上百块。
///    这一条与真机截图扫描的判据是同一种：那边也是数像素点数量，不是「发现一个
///    色点就判死」。
///
/// 阈值取 12（通道差）与 20（块数）：实测淡紫底块均值通道差 29、块数远超 100；
/// 文字边缘单块最多 25 但总数只有个位数。两组数字相差一个数量级，判据有余量。
///
/// [skipRects] 里是 [InkColorData] 申报过的区域，跳过它们：色板与取色带要的
/// 就是颜色本身，量成灰反而让「色点 + 色值文本」自相矛盾。
///
/// 通道差用**绝对值**而不是比值：比值在近黑处失真 —— `(1,0,0)` 算出来是 1.0
/// （看着像纯红），但它就是纯黑加一点抗锯齿。早先用比值扫真机截图时，
/// `展示类_05` 被报了 2 个「彩色点」，实际是文字边缘的次像素渲染。
Future<String?> _describePixels(
  WidgetTester tester,
  GlobalKey key,
  List<Rect> skipRects,
) async {
  final RenderObject? renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    return '取不到 RepaintBoundary，像素判据没跑起来';
  }

  ui.Image? image;
  ByteData? data;
  await tester.runAsync(() async {
    image = await renderObject.toImage();
    data = await image!.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  if (image == null || data == null) {
    return '截图失败';
  }

  final int width = image!.width;
  final int height = image!.height;
  final Uint8List bytes = data!.buffer.asUint8List();
  // `RenderRepaintBoundary.toImage()` **默认 `pixelRatio: 1.0`**，所以拿到的
  // 位图是「1 像素 = 1 逻辑像素」，`width` 就是逻辑宽（390），不是物理宽。
  //
  // 这里原来算的是 `width / tester.view.physicalSize.width`（390/1170 ≈ 0.33），
  // 于是每个块的坐标都被**放大 3 倍** —— 报出来的 `@ (886,3938)` 超出了 390
  // 的屏宽，一眼就该看出来。后果比报错位置难看更要紧：`skipRects` 里是
  // `getRect` 给的**逻辑**坐标，与放大后的块矩形永远不相交，所以
  // **`InkColorData` 的跳过分支一次都没执行过**。色板之所以没被报出来，纯粹
  // 是因为滚动没到那儿（见上），不是因为申报生效了。两个缺陷正好互相遮盖。
  const double pixelRatio = 1.0;
  image!.dispose();

  const int block = 8;
  const int spreadThreshold = 12;
  const int blockThreshold = 20;

  int coloredBlocks = 0;
  int worstSpread = 0;
  String worstColor = '';
  String worstAt = '';

  for (int by = 0; by < height; by += block) {
    for (int bx = 0; bx < width; bx += block) {
      int sumRed = 0;
      int sumGreen = 0;
      int sumBlue = 0;
      int count = 0;
      for (int y = by; y < by + block && y < height; y++) {
        for (int x = bx; x < bx + block && x < width; x++) {
          final int i = (y * width + x) * 4;
          sumRed += bytes[i];
          sumGreen += bytes[i + 1];
          sumBlue += bytes[i + 2];
          count++;
        }
      }
      if (count == 0) {
        continue;
      }
      final int red = sumRed ~/ count;
      final int green = sumGreen ~/ count;
      final int blue = sumBlue ~/ count;
      final int spread =
          <int>[red, green, blue].reduce((int a, int b) => a > b ? a : b) -
          <int>[red, green, blue].reduce((int a, int b) => a < b ? a : b);
      if (spread < spreadThreshold) {
        continue;
      }
      final Rect blockRect = Rect.fromLTWH(
        bx / pixelRatio,
        by / pixelRatio,
        block / pixelRatio,
        block / pixelRatio,
      );
      if (skipRects.any((Rect r) => r.overlaps(blockRect))) {
        continue;
      }
      coloredBlocks++;
      if (spread > worstSpread) {
        worstSpread = spread;
        worstColor = 'rgb($red,$green,$blue)';
        worstAt = '(${(bx / pixelRatio).round()},${(by / pixelRatio).round()})';
      }
    }
  }

  if (coloredBlocks < blockThreshold) {
    return null;
  }
  return '$coloredBlocks 个 8×8 偏色块（阈值 $blockThreshold），'
      '最深 $worstColor 通道差 $worstSpread @ $worstAt';
}

/// 祖先链上是否有 [InkColorData]。
///
/// 只看祖先、不看自身：标记是**包在**色块外面的，色块自己是 `DecoratedBox`。
bool _insideColorData(Element element) {
  bool found = false;
  element.visitAncestorElements((Element ancestor) {
    if (ancestor.widget is InkColorData) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// 返回问题描述；灰阶或看不见时返回 null。
String? _describeColor(BoxDecoration decoration) {
  if (decoration.gradient != null) {
    return 'GRADIENT ${decoration.gradient.runtimeType} 渐变不是灰阶';
  }
  return _describeColorValue(decoration.color);
}

/// 单个颜色值的判据 —— `DecoratedBox` 与 `Icon` 共用。
///
/// 抽出来是因为两条路径的**判据必须一样**：分开写两份，将来改一处忘另一处，
/// 就又是「判据看起来在检查」。这里唯一放行的是「拿不到颜色」（`null`，即
/// 走 `IconTheme` 继承）与「完全透明」（不落像素）。
String? _describeColorValue(Color? color) {
  if (color == null) {
    return null;
  }
  // `a` 是 0–1 的 double（Flutter 新 Color API），不是 0–255。
  if (color.a == 0) {
    return null;
  }
  final int red = (color.r * 255).round();
  final int green = (color.g * 255).round();
  final int blue = (color.b * 255).round();
  if (red == green && green == blue) {
    return null;
  }
  return 'rgb($red,$green,$blue) 不是灰阶';
}
