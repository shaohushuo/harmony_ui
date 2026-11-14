import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';
import 'package:hm_symbol/hm_symbol.dart';

import '../theme_switch.dart';

/// 图标库的两个来源：
///
/// - [official]：`harmony_icons`，534 个官方推荐图标，带中文名、分类、
///   模块、最低版本和 RTL 镜像码点等元数据。
/// - [full]：`hm_symbol`，3,844 个英文命名的全量 HarmonyOS Symbol 字形，
///   包含线性、填充和 `*_mirroring` 镜像字形。
enum _IconLibrary { official, full }

/// 图标浏览器。
///
/// 两个 tab 分别对应两个库的定位：日常用官方推荐集查元数据，需要找冷门
/// 字形时切到全量集。两个库互不修改，页面只做消费。
class IconsPage extends StatefulWidget {
  const IconsPage({super.key});

  @override
  State<IconsPage> createState() => _IconsPageState();
}

class _IconsPageState extends State<IconsPage> {
  _IconLibrary _library = _IconLibrary.official;

  @override
  Widget build(BuildContext context) {
    return OhosScaffold(
      appBar: OhosAppBar(
        title: const Text('图标库'),
        actions: const <Widget>[ThemeSwitchButton()],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LibraryHeader(library: _library),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OhosSegmentedButton<_IconLibrary>(
              type: OhosSegmentType.tab,
              segments: <OhosSegment<_IconLibrary>>[
                OhosSegment<_IconLibrary>(
                  label: '官方 ${OhosIcons.count}',
                  value: _IconLibrary.official,
                ),
                OhosSegment<_IconLibrary>(
                  label: '全量 ${harmonySymbolCatalog.length}',
                  value: _IconLibrary.full,
                ),
              ],
              selected: _library,
              onSelected: (_IconLibrary library) {
                setState(() => _library = library);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: IndexedStack(
              index: _library.index,
              children: const <Widget>[
                _OfficialIconsBrowser(),
                _FullSymbolsBrowser(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部说明卡：随当前 tab 切换文案与图标。
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.library});

  final _IconLibrary library;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool official = library == _IconLibrary.official;

    return OhosCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.policy.tint(theme.highlightColor, 0.10),
              borderRadius: BorderRadius.circular(14),
              border: theme.usesOutlines
                  ? Border.all(color: theme.dividerColor)
                  : null,
            ),
            child: Icon(
              official ? OhosIcons.square_grid_2x2 : OhosIcons.grid,
              size: 24,
              color: theme.highlightColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  official
                      ? 'harmony_icons · Symbol ${OhosIcons.version}'
                      : 'hm_symbol · 全量字形',
                  style: theme.typography.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  official
                      ? '官方推荐集：${OhosIcons.count} 个具名图标，带中文名、分类、'
                            '版本与 RTL 镜像元数据。'
                      : '全量集：${harmonySymbolCatalog.length} 个英文命名字形，'
                            '含线性、填充与 mirroring 镜像。',
                  style: theme.typography.bodySmall?.copyWith(
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 官方推荐集：harmony_icons
// ---------------------------------------------------------------------------

class _OfficialIconsBrowser extends StatefulWidget {
  const _OfficialIconsBrowser();

  @override
  State<_OfficialIconsBrowser> createState() => _OfficialIconsBrowserState();
}

class _OfficialIconsBrowserState extends State<_OfficialIconsBrowser> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  int _categoryIndex = 0;

  static final List<OhosIconMeta> _metas = OhosIcons.values.toList()
    ..sort((OhosIconMeta a, OhosIconMeta b) => a.name.compareTo(b.name));

  List<String> get _categories => OhosIcons.categories;

  List<OhosIconMeta> get _visibleMetas {
    final String query = _query.trim().toLowerCase();
    final String? category = _categoryIndex == 0
        ? null
        : _categories[_categoryIndex - 1];

    return _metas
        .where((OhosIconMeta meta) {
          if (category != null && !meta.categories.contains(category)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          final String codepoint =
              '0x${meta.codepoint.toRadixString(16).toUpperCase()}';
          final String searchText =
              'OhosIcons.${meta.name} ${meta.name} ${meta.label} ${meta.module} '
                      '${meta.categories.join(' ')} $codepoint'
                  .toLowerCase();
          return searchText.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _categoryIndex = 0;
    });
    _scrollToTop();
  }

  Future<void> _copyName(BuildContext context, String name) async {
    // 先关弹窗再写剪贴板：写入是异步的，避免等待期间用户点遮罩后再 pop
    // 把下面的页面一起关掉。
    Navigator.of(context).pop();
    await Clipboard.setData(ClipboardData(text: name));
    if (!context.mounted) {
      return;
    }
    showOhosToast(context, '已复制 $name', icon: OhosIcons.checkmark_circle);
  }

  void _showDetails(BuildContext context, OhosIconMeta meta) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TextStyle bodyStyle =
        (theme.typography.bodyMedium ?? const TextStyle(fontSize: 15)).copyWith(
          color: theme.textPrimaryColor,
        );

    showOhosDialog<void>(
      context: context,
      title: meta.label,
      // showDialog 挂在 Navigator Overlay 上，没有 Material 祖先；
      // 不显式给 DefaultTextStyle 会退回黄色双下划线的 fallback 样式。
      contentWidget: DefaultTextStyle(
        style: bodyStyle,
        child: _OfficialIconDetail(meta: meta, theme: theme),
      ),
      actions: <OhosDialogAction>[
        OhosDialogAction(
          label: '复制图标名',
          onPressed: () => _copyName(context, meta.name),
        ),
        OhosDialogAction(
          label: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<OhosIconMeta> visible = _visibleMetas;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OhosSearchBar(
            key: const ValueKey<String>('official-icons-search'),
            controller: _searchController,
            hintText: '搜索英文名 / 中文名 / 分类 / 码点',
            onChanged: (String value) {
              setState(() => _query = value);
              _scrollToTop();
            },
            onClear: () {
              setState(() => _query = '');
              _scrollToTop();
            },
          ),
        ),
        OhosChipGroup(
          items: <OhosChipItem>[
            const OhosChipItem(label: Text('全部')),
            for (final String category in _categories)
              OhosChipItem(label: Text(category)),
          ],
          selectedIndex: _categoryIndex,
          onSelected: (int index) {
            setState(() => _categoryIndex = index);
            _scrollToTop();
          },
          size: OhosChipSize.small,
          scrollable: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '显示 ${visible.length} / ${_metas.length} 个',
              key: const ValueKey<String>('official-icons-count'),
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textSecondaryColor,
              ),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? SingleChildScrollView(
                  child: _IconsEmptyState(
                    title: '没有匹配的图标',
                    description: '换个关键词，或清空分类与搜索条件。',
                    onReset: _resetFilters,
                    theme: theme,
                  ),
                )
              : GridView.builder(
                  key: const ValueKey<String>('official-icons-grid'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 92,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    final OhosIconMeta meta = visible[index];
                    return _IconCell(
                      key: ValueKey<String>('official-${meta.name}'),
                      name: meta.name,
                      subtitle: meta.label,
                      icon: meta.icon,
                      onTap: () => _showDetails(context, meta),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 全量集：hm_symbol
// ---------------------------------------------------------------------------

enum _SymbolStyle {
  all('全部'),
  outline('线性'),
  fill('填充'),
  mirroring('镜像');

  const _SymbolStyle(this.label);

  final String label;

  bool matches(_FullSymbol symbol) {
    return switch (this) {
      _SymbolStyle.all => true,
      _SymbolStyle.outline => !symbol.isFilled,
      _SymbolStyle.fill => symbol.isFilled,
      _SymbolStyle.mirroring => symbol.isMirroring,
    };
  }
}

/// `hm_symbol` 只提供英文名与 IconData，没有中文名和分类；这里把搜索与
/// 样式判断需要的派生字段算一次，避免每次按键都重新 split。
@immutable
class _FullSymbol {
  _FullSymbol(this.name, this.icon)
    : lowerName = name.toLowerCase(),
      unicode =
          'U+${icon.codePoint.toRadixString(16).toUpperCase().padLeft(5, '0')}',
      isFilled = _fillToken.hasMatch(name),
      isMirroring = name.endsWith('_mirroring');

  final String name;
  final IconData icon;
  final String lowerName;
  final String unicode;
  final bool isFilled;
  final bool isMirroring;

  String get searchText => '$lowerName ${unicode.toLowerCase()}';
}

final RegExp _fillToken = RegExp(r'(^|_)(fill|filled)(_|$)');

class _FullSymbolsBrowser extends StatefulWidget {
  const _FullSymbolsBrowser();

  @override
  State<_FullSymbolsBrowser> createState() => _FullSymbolsBrowserState();
}

class _FullSymbolsBrowserState extends State<_FullSymbolsBrowser> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  _SymbolStyle _style = _SymbolStyle.all;

  static final List<_FullSymbol> _symbols =
      harmonySymbolCatalog.entries
          .map(
            (MapEntry<String, IconData> entry) =>
                _FullSymbol(entry.key, entry.value),
          )
          .toList()
        ..sort((_FullSymbol a, _FullSymbol b) => a.name.compareTo(b.name));

  List<_FullSymbol> get _visibleSymbols {
    final List<String> terms = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String term) => term.isNotEmpty)
        .toList(growable: false);

    return _symbols
        .where((_FullSymbol symbol) {
          if (!_style.matches(symbol)) {
            return false;
          }
          if (terms.isEmpty) {
            return true;
          }
          return terms.every((String term) => symbol.searchText.contains(term));
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _style = _SymbolStyle.all;
    });
    _scrollToTop();
  }

  Future<void> _copyCode(BuildContext context, _FullSymbol symbol) async {
    final String code = 'Icon(HarmonySymbols.${symbol.name})';
    Navigator.of(context).pop();
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) {
      return;
    }
    showOhosToast(context, '已复制 $code', icon: OhosIcons.checkmark_circle);
  }

  void _showDetails(BuildContext context, _FullSymbol symbol) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TextStyle bodyStyle =
        (theme.typography.bodyMedium ?? const TextStyle(fontSize: 15)).copyWith(
          color: theme.textPrimaryColor,
        );

    showOhosDialog<void>(
      context: context,
      title: '全量字形',
      contentWidget: DefaultTextStyle(
        style: bodyStyle,
        child: _FullSymbolDetail(symbol: symbol, theme: theme),
      ),
      actions: <OhosDialogAction>[
        OhosDialogAction(
          label: '复制代码',
          onPressed: () => _copyCode(context, symbol),
        ),
        OhosDialogAction(
          label: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<_FullSymbol> visible = _visibleSymbols;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OhosSearchBar(
            key: const ValueKey<String>('full-symbols-search'),
            controller: _searchController,
            hintText: '搜索英文名 / 码点',
            onChanged: (String value) {
              setState(() => _query = value);
              _scrollToTop();
            },
            onClear: () {
              setState(() => _query = '');
              _scrollToTop();
            },
          ),
        ),
        OhosChipGroup(
          items: <OhosChipItem>[
            for (final _SymbolStyle style in _SymbolStyle.values)
              OhosChipItem(label: Text(style.label)),
          ],
          selectedIndex: _style.index,
          onSelected: (int index) {
            setState(() => _style = _SymbolStyle.values[index]);
            _scrollToTop();
          },
          size: OhosChipSize.small,
          scrollable: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '显示 ${visible.length} / ${_symbols.length} 个',
              key: const ValueKey<String>('full-symbols-count'),
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textSecondaryColor,
              ),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? SingleChildScrollView(
                  child: _IconsEmptyState(
                    title: '没有匹配的字形',
                    description: '换个关键词，或切换线性 / 填充 / 镜像筛选。',
                    onReset: _resetFilters,
                    theme: theme,
                  ),
                )
              : GridView.builder(
                  key: const ValueKey<String>('full-symbols-grid'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 96,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _FullSymbol symbol = visible[index];
                    return _IconCell(
                      key: ValueKey<String>('full-${symbol.name}'),
                      name: symbol.name,
                      subtitle: symbol.unicode,
                      icon: symbol.icon,
                      subtitleColor: theme.textTertiaryColor,
                      onTap: () => _showDetails(context, symbol),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 共用展示件
// ---------------------------------------------------------------------------

class _IconCell extends StatelessWidget {
  const _IconCell({
    super.key,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.subtitleColor,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final BorderRadius radius = BorderRadius.circular(12);

    return OhosPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '$subtitle $name',
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: radius,
          border: theme.usesOutlines
              ? Border.all(
                  color: theme.dividerColor,
                  width: theme.policy.outlineWidth ?? 1,
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 26, color: theme.textPrimaryColor),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.labelSmall?.copyWith(
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.labelSmall?.copyWith(
                color: subtitleColor ?? theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconsEmptyState extends StatelessWidget {
  const _IconsEmptyState({
    required this.title,
    required this.description,
    required this.onReset,
    required this.theme,
  });

  final String title;
  final String description;
  final VoidCallback onReset;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        children: <Widget>[
          Icon(
            OhosIcons.minus_magnifyingglass,
            size: 40,
            color: theme.textTertiaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.typography.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.typography.bodySmall?.copyWith(
              color: theme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OhosButton(
            onPressed: onReset,
            style: OhosButtonStyle.tonal,
            child: const Text('清空筛选'),
          ),
        ],
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.icon, required this.theme});

  final IconData icon;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: theme.policy.tint(theme.highlightColor, 0.10),
        borderRadius: BorderRadius.circular(24),
        border: theme.usesOutlines
            ? Border.all(color: theme.dividerColor)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 56, color: theme.textPrimaryColor),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.typography.bodySmall?.copyWith(
                color: theme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialIconDetail extends StatelessWidget {
  const _OfficialIconDetail({required this.meta, required this.theme});

  final OhosIconMeta meta;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IconPreview(icon: meta.icon, theme: theme),
        const SizedBox(height: 14),
        Text(
          meta.name,
          style: theme.typography.titleSmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _DetailRow(label: '中文名', value: meta.label, theme: theme),
        _DetailRow(
          label: '分类',
          value: meta.categories.join(' / '),
          theme: theme,
        ),
        _DetailRow(label: '模块', value: meta.module, theme: theme),
        _DetailRow(label: '版本', value: meta.supportVersion, theme: theme),
        _DetailRow(
          label: '码点',
          value: '0x${meta.codepoint.toRadixString(16).toUpperCase()}',
          theme: theme,
        ),
        _DetailRow(
          label: '来源',
          value: 'harmony_icons · ${OhosIcons.count} 个官方推荐图标',
          theme: theme,
        ),
      ],
    );
  }
}

class _FullSymbolDetail extends StatelessWidget {
  const _FullSymbolDetail({required this.symbol, required this.theme});

  final _FullSymbol symbol;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    final String type = symbol.isMirroring
        ? '镜像字形（mirroring）'
        : symbol.isFilled
        ? '填充（fill）'
        : '线性（outline）';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IconPreview(icon: symbol.icon, theme: theme),
        const SizedBox(height: 14),
        Text(
          symbol.name,
          style: theme.typography.titleSmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _DetailRow(label: '码点', value: symbol.unicode, theme: theme),
        _DetailRow(label: '类型', value: type, theme: theme),
        _DetailRow(
          label: '代码',
          value: 'Icon(HarmonySymbols.${symbol.name})',
          theme: theme,
        ),
        _DetailRow(
          label: '来源',
          value: 'hm_symbol · ${harmonySymbolCatalog.length} 个全量字形',
          theme: theme,
        ),
      ],
    );
  }
}
