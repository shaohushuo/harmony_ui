import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui/ohos_ui.dart';

/// Progress, badges, dividers and dialogs.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => setState(() => _progress = (_progress + 0.03) % 1.0),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showDialog() async {
    final bool? ok = await showOhosDialog<bool>(
      context: context,
      title: '删除文件？',
      content: '删除后无法恢复，请确认是否继续。',
      actions: <OhosDialogAction>[
        OhosDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(context, false),
        ),
        OhosDialogAction(
          label: '删除',
          danger: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件已删除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: <Widget>[
        const _SectionTitle('进度 / OhosProgressIndicator'),
        OhosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  OhosProgressIndicator.circular(),
                  OhosProgressIndicator.circular(
                    value: 0.6,
                    size: 56,
                    strokeWidth: 6,
                  ),
                  OhosProgressIndicator.circular(
                    value: 1.0,
                    size: 40,
                    color: Color(0xFF64BB5C),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '下载进度 ${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: theme.textSecondaryColor),
              ),
              const SizedBox(height: 8),
              OhosProgressIndicator.linear(value: _progress),
              const SizedBox(height: 16),
              const OhosProgressIndicator.linear(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('角标 / OhosBadge'),
        const Wrap(
          spacing: 24,
          runSpacing: 16,
          children: <Widget>[
            OhosBadge(
              count: 120,
              child: Icon(OhosIcons.message_fill, size: 28),
            ),
            OhosBadge(count: 5, child: Icon(OhosIcons.bell_fill, size: 28)),
            OhosBadge(
              count: 99,
              maxCount: 99,
              child: Icon(OhosIcons.heart_fill, size: 28),
            ),
            OhosBadge(
              isDot: true,
              color: Color(0xFF0A59F7),
              child: Icon(OhosIcons.person, size: 28),
            ),
            OhosBadge(count: 3),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('分割线 / OhosDivider'),
        OhosCard(
          child: Column(
            children: <Widget>[
              const OhosListTile(title: Text('默认分割线'), divider: true),
              const OhosListTile(title: Text('自定义缩进'), divider: true),
              OhosDivider(indent: 8, endIndent: 8, height: 16),
              const Padding(
                padding: EdgeInsets.all(16),
                child: OhosDivider(indent: 0, endIndent: 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('对话框 / OhosAlertDialog'),
        OhosCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              children: <Widget>[
                OhosButton(
                  onPressed: _showDialog,
                  icon: const Icon(OhosIcons.trash),
                  child: const Text('打开对话框'),
                ),
                OhosButton(
                  onPressed: () => showOhosDialog<void>(
                    context: context,
                    title: '操作失败',
                    content: '网络连接超时，请稍后重试。',
                  ),
                  style: OhosButtonStyle.outlined,
                  child: const Text('单按钮弹窗'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(OhosIcons.star_fill, size: 18, color: theme.highlightColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.typography.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
