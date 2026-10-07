import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'pages/action_page.dart';
import 'pages/container_page.dart';
import 'pages/display_page.dart';
import 'pages/input_page.dart';
import 'pages/layout_page.dart';
import 'pages/navigation_page.dart';
import 'pages/selection_page.dart';

void main() {
  runApp(const OhosUiGalleryApp());
}

class OhosUiGalleryApp extends StatelessWidget {
  const OhosUiGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'harmony_ui gallery',
      home: OhosTheme(
        data: OhosThemeData.light(fontFamily: 'HarmonyOS Sans'),
        child: const HomePage(),
      ),
    );
  }
}

/// Category model of the gallery home.
class GalleryCategory {
  const GalleryCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<GalleryCategory> categories = <GalleryCategory>[
    GalleryCategory(
      title: '导航类',
      subtitle: '标题栏 · 子页签 · 底部页签 · 导航点',
      icon: OhosIcons.arrow_right,
      builder: (BuildContext context) => NavigationPage(),
    ),
    GalleryCategory(
      title: '展示类',
      subtitle: '文本 · 进度 · 徽标 · 反馈 · 二维码等',
      icon: OhosIcons.doc_text_fill,
      builder: (BuildContext context) => DisplayPage(),
    ),
    GalleryCategory(
      title: '操作类',
      subtitle: '按钮 · 下拉 · 状态按钮 · 工具栏 · 菜单',
      icon: OhosIcons.checkmark_circle_fill,
      builder: (BuildContext context) => ActionPage(),
    ),
    GalleryCategory(
      title: '输入类',
      subtitle: '文本框 · 搜索框 · 数字加减 · 图案锁',
      icon: OhosIcons.square_and_pencil,
      builder: (BuildContext context) => InputPage(),
    ),
    GalleryCategory(
      title: '选择类',
      subtitle: '勾选 · 开关 · 评分 · 滑动条 · 选择器',
      icon: OhosIcons.star_fill,
      builder: (BuildContext context) => SelectionPage(),
    ),
    GalleryCategory(
      title: '布局与动效',
      subtitle: '栅格 · 响应式断点 · 沉浸光感 · 转场动效',
      icon: OhosIcons.slider_horizontal_2,
      builder: (BuildContext context) => LayoutPage(),
    ),
    GalleryCategory(
      title: '容器类',
      subtitle: '列表 · 弹出框 · 半模态面板',
      icon: OhosIcons.folder_fill,
      builder: (BuildContext context) => ContainerPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return OhosScaffold(
      appBar: OhosAppBar(
        leading: Icon(OhosIcons.house_fill, color: theme.highlightColor),
        title: const Text('harmony_ui 组件画廊'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          OhosCard(
            child: Row(
              children: <Widget>[
                Icon(OhosIcons.share, size: 28, color: theme.highlightColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'HarmonyOS 设计控件全覆盖',
                        style: theme.typography.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '参考华为设计文档「控件概览」6 大类 42 个控件，点击分类查看演示。',
                        style: theme.typography.bodySmall?.copyWith(
                          color: theme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final GalleryCategory category in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OhosCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: category.builder),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.highlightColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        category.icon,
                        size: 22,
                        color: theme.highlightColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            category.title,
                            style: theme.typography.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.subtitle,
                            style: theme.typography.bodySmall?.copyWith(
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      OhosIcons.chevron_right,
                      size: 20,
                      color: theme.textTertiaryColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
