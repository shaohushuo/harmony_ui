import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui_kit/ohos_ui_kit.dart';

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
