import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import '../theme_switch.dart';

/// `harmony_icons` 图标浏览器。
///
/// 默认只列出 [OhosIcons] 具名导出的图标 —— 也就是源码里一个个
/// `IconData` 常量，日常查名字先看这一层就够了。切到「全部字形」后，会额外
/// 带出字体里保留、但没有单独常量名的 RTL 镜像字形（隐藏字形）。
/// 当前 harmony_icons 0.1.0 / Symbol 2.3 的对应数量是 534 + 107 = 641。
class IconsPage extends StatefulWidget {
  const IconsPage({super.key});

  @override
  State<IconsPage> createState() => _IconsPageState();
}

/// 浏览范围：默认只看具名图标，也可以把隐藏的镜像字形一起带出来。
enum _IconScope { named, all }

/// 一个可浏览的字形。具名图标与镜像字形共用这套结构，[isMirror] 区分来源。
@immutable
class _IconEntry {
  const _IconEntry({
    required this.key,
    required this.name,
    required this.label,
    required this.module,
    required this.categories,
    required this.supportVersion,
    required this.codepoint,
    required this.icon,
    this.isMirror = false,
  });

  /// 列表内唯一键；镜像字形用 `<name>__mirror`，避免和具名图标撞车。
  final String key;
  final String name;
  final String label;
  final String module;
  final List<String> categories;
  final String supportVersion;
  final int codepoint;
  final IconData icon;
  final bool isMirror;

  String get hexCodepoint => '0x${codepoint.toRadixString(16).toUpperCase()}';

  String get searchText =>
      'OhosIcons.$name $name $label $module ${categories.join(' ')} '
              '$hexCodepoint'
          .toLowerCase();
}

class _IconsPageState extends State<IconsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  int _categoryIndex = 0;
  bool _showAllGlyphs = false;

  late final List<_IconEntry> _namedEntries = _buildNamedEntries();
  late final List<_IconEntry> _mirrorEntries = _buildMirrorEntries();
  late final List<_IconEntry> _allEntries = _interleaveMirrors();

  List<String> get _categories => OhosIcons.categories;

  List<_IconEntry> get _source => _showAllGlyphs ? _allEntries : _namedEntries;

  List<_IconEntry> get _visibleEntries {
    final String query = _query.trim().toLowerCase();
    final String? category = _categoryIndex == 0
        ? null
        : _categories[_categoryIndex - 1];

    return _source
        .where((_IconEntry entry) {
          if (category != null && !entry.categories.contains(category)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return entry.searchText.contains(query);
        })
        .toList(growable: false);
  }

  List<_IconEntry> _buildNamedEntries() {
    final List<OhosIconMeta> metas = OhosIcons.values.toList()
      ..sort((OhosIconMeta a, OhosIconMeta b) => a.name.compareTo(b.name));
    return <_IconEntry>[
      for (final OhosIconMeta meta in metas)
        _IconEntry(
          key: meta.name,
          name: meta.name,
          label: meta.label,
          module: meta.module,
          categories: meta.categories,
          supportVersion: meta.supportVersion,
          codepoint: meta.codepoint,
          icon: meta.icon,
        ),
    ];
  }

  /// 字体里每个图标还可能带一个 RTL 镜像码点。这些字形没有独立的
  /// `OhosIcons.xxx` 常量，只能通过 [OhosIconMeta.mirrorIcon] 取到，
  /// 所以归到「隐藏字形」里单独展示。
  List<_IconEntry> _buildMirrorEntries() {
    final Set<int> usedCodepoints = <int>{
      for (final OhosIconMeta meta in OhosIcons.values) meta.codepoint,
    };
    final List<_IconEntry> mirrors = <_IconEntry>[];

    for (final OhosIconMeta meta in OhosIcons.values) {
      final int? mirrorCodepoint = meta.mirrorCodepoint;
      final IconData? mirrorIcon = meta.mirrorIcon;
      if (mirrorCodepoint == null || mirrorIcon == null) {
        continue;
      }
      // 多个条目可能指向同一个镜像字形，按码点去重，保证「字形总数」准确。
      if (!usedCodepoints.add(mirrorCodepoint)) {
        continue;
      }
      mirrors.add(
        _IconEntry(
          key: '${meta.name}__mirror',
          name: meta.name,
          label: '${meta.label}（镜像）',
          module: meta.module,
          categories: meta.categories,
          supportVersion: meta.supportVersion,
          codepoint: mirrorCodepoint,
          icon: mirrorIcon,
          isMirror: true,
        ),
      );
    }

    mirrors.sort((_IconEntry a, _IconEntry b) => a.name.compareTo(b.name));
    return mirrors;
  }

  /// 「全部字形」把镜像紧跟在同名图标后面，方便对照正向 / RTL 字形。
  List<_IconEntry> _interleaveMirrors() {
    final Map<String, _IconEntry> mirrorsByName = <String, _IconEntry>{
      for (final _IconEntry mirror in _mirrorEntries) mirror.name: mirror,
    };
    return <_IconEntry>[
      for (final _IconEntry named in _namedEntries) ...<_IconEntry>[
        named,
        if (mirrorsByName[named.name] case final _IconEntry mirror) mirror,
      ],
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    // 过滤后列表可能变短，等新一帧布局完成再回到顶部。
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

  Future<void> _copyIconName(BuildContext context, _IconEntry entry) async {
    // 先关弹窗再写剪贴板：写入是异步的，等它回来再 pop 的话，用户若在
    // 这一瞬间点了遮罩，这次 pop 就会把下面的页面一起关掉。
    Navigator.of(context).pop();
    await Clipboard.setData(ClipboardData(text: entry.name));
    if (!context.mounted) {
      return;
    }
    showOhosToast(
      context,
      entry.isMirror
          ? '已复制 ${entry.name}（镜像码点 ${entry.hexCodepoint}）'
          : '已复制 ${entry.name}',
      icon: OhosIcons.checkmark_circle,
    );
  }

  void _showDetails(BuildContext context, _IconEntry entry) {
    final OhosThemeData theme = OhosTheme.of(context);
    final TextStyle bodyStyle =
        (theme.typography.bodyMedium ?? const TextStyle(fontSize: 15)).copyWith(
          color: theme.textPrimaryColor,
        );

    showOhosDialog<void>(
      context: context,
      title: entry.label,
      // showDialog 挂在 Navigator Overlay 上，没有 Material 祖先；
      // 不显式给 DefaultTextStyle 会退回黄色双下划线的 fallback 样式。
      contentWidget: DefaultTextStyle(
        style: bodyStyle,
        child: _IconDetail(entry: entry, theme: theme),
      ),
      actions: <OhosDialogAction>[
        OhosDialogAction(
          label: '复制图标名',
          onPressed: () => _copyIconName(context, entry),
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
    final List<_IconEntry> visible = _visibleEntries;
    final int total = _source.length;

    return OhosScaffold(
      appBar: OhosAppBar(
        title: const Text('图标库'),
        actions: const <Widget>[ThemeSwitchButton()],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OhosCard(
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
                        OhosIcons.square_grid_2x2,
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
                            'HarmonyOS Symbol ${OhosIcons.version}',
                            style: theme.typography.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '默认展示 ${OhosIcons.count} 个具名图标；切到「全部字形」'
                            '还能查看 ${_mirrorEntries.length} 个隐藏的 RTL 镜像字形。',
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
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: OhosSearchBar(
                key: const ValueKey<String>('icons-search'),
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: OhosSegmentedButton<_IconScope>(
                key: const ValueKey<String>('icons-scope'),
                // capsule 选中态在浅色彩屏上是「10% 品牌蓝底 + 反白字」，
                // 对比度不足；这里要的是切换视图，tab 形态的白底黑字更合适。
                type: OhosSegmentType.tab,
                segments: <OhosSegment<_IconScope>>[
                  OhosSegment<_IconScope>(
                    label: '图标 ${OhosIcons.count}',
                    value: _IconScope.named,
                  ),
                  OhosSegment<_IconScope>(
                    label: '全部字形 ${_allEntries.length}',
                    value: _IconScope.all,
                  ),
                ],
                selected: _showAllGlyphs ? _IconScope.all : _IconScope.named,
                onSelected: (_IconScope scope) {
                  setState(() => _showAllGlyphs = scope == _IconScope.all);
                  _scrollToTop();
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: OhosChipGroup(
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '显示 ${visible.length} / $total 个'
                '${_showAllGlyphs ? '（含 ${_mirrorEntries.length} 个隐藏字形）' : ''}',
                key: const ValueKey<String>('icons-count'),
                style: theme.typography.bodySmall?.copyWith(
                  color: theme.textSecondaryColor,
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: _IconsEmptyState(onReset: _resetFilters, theme: theme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 92,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final _IconEntry entry = visible[index];
                  return _IconCell(
                    key: ValueKey<String>('icon-${entry.key}'),
                    entry: entry,
                    onTap: () => _showDetails(context, entry),
                  );
                }, childCount: visible.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({super.key, required this.entry, required this.onTap});

  final _IconEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final BorderRadius radius = BorderRadius.circular(12);

    return OhosPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '${entry.label} ${entry.name}',
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
            Icon(
              entry.icon,
              size: 26,
              color: entry.isMirror
                  ? theme.textSecondaryColor
                  : theme.textPrimaryColor,
            ),
            const SizedBox(height: 5),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.labelSmall?.copyWith(
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              entry.isMirror ? 'RTL 镜像' : entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.labelSmall?.copyWith(
                color: entry.isMirror
                    ? theme.highlightColor
                    : theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconsEmptyState extends StatelessWidget {
  const _IconsEmptyState({required this.onReset, required this.theme});

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
            '没有匹配的图标',
            style: theme.typography.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '换个关键词，或清空分类与搜索条件。',
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

class _IconDetail extends StatelessWidget {
  const _IconDetail({required this.entry, required this.theme});

  final _IconEntry entry;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
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
          child: Icon(entry.icon, size: 56, color: theme.textPrimaryColor),
        ),
        const SizedBox(height: 14),
        Text(
          entry.name,
          style: theme.typography.titleSmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.textPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _DetailRow(label: '中文名', value: entry.label, theme: theme),
        _DetailRow(
          label: '分类',
          value: entry.categories.join(' / '),
          theme: theme,
        ),
        _DetailRow(label: '模块', value: entry.module, theme: theme),
        _DetailRow(label: '版本', value: entry.supportVersion, theme: theme),
        _DetailRow(label: '码点', value: entry.hexCodepoint, theme: theme),
        _DetailRow(
          label: '类型',
          value: entry.isMirror ? 'RTL 镜像字形（隐藏）' : '具名图标',
          theme: theme,
        ),
      ],
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
