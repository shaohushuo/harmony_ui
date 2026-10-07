import 'package:flutter/material.dart';
import 'package:ohos_icons/ohos_icons.dart';
import 'package:ohos_ui/ohos_ui.dart';

/// Text fields, search bar, switches, checkboxes and radios.
class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _agree = true;
  int _sex = 0;
  String _query = '';
  String _submitted = '';

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: <Widget>[
        _SectionTitle('搜索 / OhosSearchBar', icon: OhosIcons.magnifyingglass),
        OhosSearchBar(
          hintText: '搜索应用、设置、文件',
          onChanged: (String q) => setState(() => _query = q),
          onSubmitted: (String q) => setState(() => _submitted = q),
        ),
        if (_query.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '实时查询: $_query',
            style: TextStyle(color: theme.textSecondaryColor),
          ),
        ],
        if (_submitted.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '已搜索: $_submitted',
            style: TextStyle(color: theme.highlightColor),
          ),
        ],
        const SizedBox(height: 24),
        _SectionTitle('输入框 / OhosTextField', icon: OhosIcons.square_and_pencil),
        OhosCard(
          child: Column(
            children: <Widget>[
              OhosTextField(
                labelText: '用户名',
                hintText: '请输入用户名',
                prefixIcon: const Icon(OhosIcons.person, size: 20),
              ),
              const SizedBox(height: 16),
              OhosTextField(
                labelText: '密码',
                hintText: '请输入密码',
                obscureText: true,
                prefixIcon: const Icon(OhosIcons.lock_fill, size: 20),
              ),
              const SizedBox(height: 16),
              const OhosTextField(
                labelText: '邮箱',
                hintText: '例如 name@example.com',
                errorText: '邮箱格式不正确',
                prefixIcon: Icon(OhosIcons.message_fill, size: 20),
              ),
              const SizedBox(height: 0),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle('开关 / OhosSwitch', icon: OhosIcons.slider_horizontal_2),
        OhosCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              OhosListTile(
                leading: const Icon(OhosIcons.wifi),
                title: const Text('Wi-Fi'),
                trailing: OhosSwitch(
                  value: _wifi,
                  onChanged: (bool v) => setState(() => _wifi = v),
                ),
              ),
              OhosListTile(
                leading: const Icon(OhosIcons.bluetooth),
                title: const Text('蓝牙'),
                trailing: OhosSwitch(
                  value: _bluetooth,
                  onChanged: (bool v) => setState(() => _bluetooth = v),
                ),
              ),
              const OhosListTile(
                leading: Icon(OhosIcons.wifi_slash),
                title: Text('禁用开关'),
                trailing: OhosSwitch(value: true, onChanged: null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          '复选 & 单选 / OhosCheckbox · OhosRadio',
          icon: OhosIcons.checkmark_square_fill,
        ),
        OhosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InkWell(
                onTap: () => setState(() => _agree = !_agree),
                child: Row(
                  children: <Widget>[
                    OhosCheckbox(
                      value: _agree,
                      onChanged: (bool v) => setState(() => _agree = v),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('同意用户协议与隐私政策')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('性别', style: TextStyle(color: theme.textSecondaryColor)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 2; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _sex = i),
                        child: Row(
                          children: <Widget>[
                            OhosRadio(
                              value: _sex == i,
                              onChanged: (bool v) => setState(() => _sex = i),
                            ),
                            const SizedBox(width: 8),
                            Text(i == 0 ? '男' : '女'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.highlightColor),
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
