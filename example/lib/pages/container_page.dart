import 'package:flutter/material.dart';
import 'package:harmony_icons/harmony_icons.dart';
import 'package:harmony_ui/harmony_ui.dart';

import 'demo_scaffold.dart';

/// 容器类：列表 / 卡片 / 弹出框 / 气泡提示 / 半模态面板
class ContainerPage extends StatelessWidget {
  const ContainerPage({super.key});

  static final GlobalKey _popupTarget = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return DemoScaffold(
      title: '容器类',
      children: <Widget>[
        const DemoSection(
          title: '列表 OhosList',
          description: '带分组标题的卡片式列表，行间细分隔线。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: OhosList(
              header: OhosSubheader(title: '设置'),
              children: <Widget>[
                OhosListTile(
                  leading: Icon(OhosIcons.wifi, color: Color(0xFF0A59F7)),
                  title: Text('无线网络'),
                  subtitle: Text('已连接 HarmonyOS 热点'),
                  trailing: Icon(OhosIcons.chevron_right, size: 20),
                ),
                OhosListTile(
                  leading: Icon(OhosIcons.bluetooth, color: Color(0xFF0A59F7)),
                  title: Text('蓝牙'),
                  trailing: Text('已关闭'),
                ),
                OhosListTile(
                  leading: Icon(
                    OhosIcons.battery_75percent,
                    color: Color(0xFF0A59F7),
                  ),
                  title: Text('电池'),
                  subtitle: Text('电量 87%'),
                  trailing: Icon(OhosIcons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '高密度列表（density: compact）',
          description:
              '对应 Material 的 ListTile(dense: true)：标题 14 / 副标题 12、上下 8vp。'
              '文件列表、提交列表这类替换场景用它，行高不会被常规档撑高。',
          child: DemoCard(
            padding: EdgeInsets.zero,
            child: OhosList(
              header: OhosSubheader(title: '提交记录'),
              children: <Widget>[
                OhosListTile(
                  density: OhosListTileDensity.compact,
                  title: Text('修复标题栏状态栏内边距'),
                  subtitle: Text('3f2a91c · 2 分钟前'),
                ),
                OhosListTile(
                  density: OhosListTileDensity.compact,
                  title: Text('补齐顶栏对齐与 bottom 槽位'),
                  subtitle: Text('b41d07e · 昨天'),
                ),
              ],
            ),
          ),
        ),
        const DemoSection(
          title: '分组 OhosListGroup（style: card）',
          description:
              '对应 ArkUI 的 ListItemGroupStyle.CARD：左右外边距 12、四周内边距 4、'
              '圆角 24。组头 / 组尾是普通 Widget，分隔线归组所有 —— 行内 tile 自己那条'
              '不会重复画。下面的 space 只加在行与行之间，组头到首行、末行到组尾都不受'
              '影响。',
          child: OhosListGroup(
            style: OhosListGroupStyle.card,
            itemStyle: OhosListGroupItemStyle.card,
            space: 8,
            divider: OhosGroupDivider(startMargin: 8, endMargin: 8),
            header: _GroupHeader('常用'),
            footer: _GroupFooter('共 3 项系统设置'),
            children: <Widget>[
              OhosListTile(
                leading: Icon(OhosIcons.wifi, color: Color(0xFF0A59F7)),
                title: Text('无线网络'),
                trailing: Icon(OhosIcons.chevron_right, size: 20),
              ),
              OhosListTile(
                leading: Icon(OhosIcons.bluetooth, color: Color(0xFF0A59F7)),
                title: Text('蓝牙'),
                trailing: Text('已关闭'),
              ),
              OhosListTile(
                leading: Icon(
                  OhosIcons.battery_75percent,
                  color: Color(0xFF0A59F7),
                ),
                title: Text('电池'),
                trailing: Icon(OhosIcons.chevron_right, size: 20),
              ),
            ],
          ),
        ),
        const DemoSection(
          title: '分组不铺底板（style: none）',
          description:
              '同一套分组只换 style：组头 / 组尾、space、divider 都还在，但不再有'
              '卡片底板与 12 外边距。itemStyle 也能单独关掉 —— 组样式与行样式是两个'
              '独立参数，可以自由组合。',
          child: OhosListGroup(
            style: OhosListGroupStyle.none,
            itemStyle: OhosListGroupItemStyle.none,
            space: 4,
            divider: OhosGroupDivider(startMargin: 16, endMargin: 16),
            header: _GroupHeader('未分组'),
            children: <Widget>[
              OhosListTile(title: Text('显示与亮度')),
              OhosListTile(title: Text('声音与振动')),
            ],
          ),
        ),
        DemoSection(
          title: '卡片 OhosCard',
          description: '可点击卡片，用于功能入口聚合。',
          child: Row(
            children: <Widget>[
              Expanded(
                child: OhosCard(
                  onTap: () => showOhosToast(context, '点击了卡片'),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        OhosIcons.icloud,
                        size: 32,
                        color: theme.highlightColor,
                      ),
                      const SizedBox(height: 8),
                      Text('云空间', style: theme.typography.titleSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OhosCard(
                  onTap: () => showOhosToast(context, '点击了卡片'),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        OhosIcons.phone,
                        size: 32,
                        color: theme.highlightColor,
                      ),
                      const SizedBox(height: 8),
                      Text('手机管家', style: theme.typography.titleSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        DemoSection(
          title: '弹出框 showOhosDialog',
          description: '居中警示弹窗，支持次要 / 危险操作。',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosButton(
                  onPressed: () => showOhosDialog<String>(
                    context: context,
                    title: '删除文件',
                    content: '删除后无法恢复，确定要继续吗？',
                    actions: <OhosDialogAction>[
                      OhosDialogAction(
                        label: '取消',
                        onPressed: () => Navigator.pop(context),
                      ),
                      OhosDialogAction(
                        label: '删除',
                        danger: true,
                        onPressed: () {
                          Navigator.pop(context);
                          showOhosToast(
                            context,
                            '已删除',
                            icon: OhosIcons.exclamationmark_triangle_fill,
                          );
                        },
                      ),
                    ],
                  ),
                  style: OhosButtonStyle.tonal,
                  child: const Text('打开弹窗'),
                ),
              ],
            ),
          ),
        ),
        DemoSection(
          title: '气泡提示 showOhosPopup',
          description: '锚定在目标控件旁的气泡。',
          child: DemoCard(
            child: OhosButton(
              key: _popupTarget,
              onPressed: () {
                showOhosPopup(
                  context: context,
                  content: '长按扫码或点击进入',
                  targetKey: _popupTarget,
                );
              },
              icon: const Icon(OhosIcons.circle_viewfinder),
              child: const Text('显示气泡'),
            ),
          ),
        ),
        DemoSection(
          title: '半模态面板 showOhosBottomSheet',
          description: '圆角半屏面板，常用于分享 / 详情等场景。',
          child: DemoCard(
            child: Row(
              children: <Widget>[
                OhosButton(
                  onPressed: () => showOhosBottomSheet(
                    context: context,
                    title: '分享到',
                    content: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        children: <Widget>[
                          _ShareIcon(icon: OhosIcons.message_fill, label: '信息'),
                          _ShareIcon(
                            icon: OhosIcons.envelope_fill,
                            label: '邮件',
                          ),
                          _ShareIcon(icon: OhosIcons.link, label: '链接'),
                          _ShareIcon(
                            icon: OhosIcons.checkmark_square_on_square,
                            label: '复制',
                          ),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(OhosIcons.share),
                  child: const Text('打开面板'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: theme.highlightColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 24, color: theme.highlightColor),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.typography.bodySmall),
      ],
    );
  }
}

/// 分组演示用的组头：官方示例里组头就是一个普通 Widget，不自带任何样式，
/// 这里只用字阶区分，颜色走主题，墨屏下也能读。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: theme.typography.titleSmall?.copyWith(
          color: theme.textSecondaryColor,
        ),
      ),
    );
  }
}

/// 分组演示用的组尾。
class _GroupFooter extends StatelessWidget {
  const _GroupFooter(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: theme.typography.bodySmall?.copyWith(
          color: theme.textTertiaryColor,
        ),
      ),
    );
  }
}
