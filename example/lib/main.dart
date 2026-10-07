import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

import 'pages/about_page.dart';
import 'pages/feedback_page.dart';
import 'pages/form_page.dart';
import 'pages/widgets_page.dart';

void main() {
  runApp(const OhosUiGalleryApp());
}

class OhosUiGalleryApp extends StatefulWidget {
  const OhosUiGalleryApp({super.key});

  @override
  State<OhosUiGalleryApp> createState() => _OhosUiGalleryAppState();
}

class _OhosUiGalleryAppState extends State<OhosUiGalleryApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ohos_ui gallery',
      theme: ThemeData(
        fontFamily: 'HarmonyOS Sans',
        colorScheme: ColorScheme.fromSeed(seedColor: OhosColors.highlight),
      ),
      home: OhosTheme(
        data: OhosThemeData.light(fontFamily: 'HarmonyOS Sans'),
        child: _Home(
          tab: _tab,
          onTabChanged: (int i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.tab, required this.onTabChanged});

  final int tab;
  final ValueChanged<int> onTabChanged;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = widget.tab;
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged(_tabController.index);
      }
    });
  }

  @override
  void didUpdateWidget(_Home oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != _tabController.index) {
      _tabController.index = widget.tab;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return OhosScaffold(
      appBar: OhosAppBar(
        leading: Icon(
          OhosIcons.house_fill,
          color: theme.highlightColor,
          size: 24,
        ),
        title: const Text('ohos_ui 组件画廊'),
        actions: <Widget>[
          OhosBadge(
            count: 3,
            child: const OhosIconButton(icon: Icon(OhosIcons.message_fill)),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          WidgetsPage(),
          FormPage(),
          FeedbackPage(),
          AboutPage(),
        ],
      ),
      bottomNavigationBar: OhosNavigationBar(
        currentIndex: widget.tab,
        onDestinationSelected: widget.onTabChanged,
        destinations: const <OhosNavigationDestination>[
          OhosNavigationDestination(
            icon: Icon(OhosIcons.square_grid_2x2),
            label: '组件',
          ),
          OhosNavigationDestination(
            icon: Icon(OhosIcons.square_and_pencil),
            label: '表单',
          ),
          OhosNavigationDestination(
            icon: Icon(OhosIcons.exclamationmark_circle_fill),
            label: '反馈',
          ),
          OhosNavigationDestination(
            icon: Icon(OhosIcons.info_circle_fill),
            label: '关于',
          ),
          OhosNavigationDestination(
            icon: Icon(OhosIcons.ellipsis_circle),
            label: '更多',
            badge: OhosBadge(isDot: true),
          ),
        ],
      ),
    );
  }
}
