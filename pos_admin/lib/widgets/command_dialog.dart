import 'dart:convert';
import 'package:flutter/material.dart';

class CommandDialog extends StatefulWidget {
  final String deviceId;

  const CommandDialog({super.key, required this.deviceId});

  @override
  State<CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<CommandDialog> {
  String _selectedCommand = 'lock_screen';
  final _paramCtrl = TextEditingController();

  static const _commands = [
    {'value': 'lock_screen', 'label': '锁定屏幕', 'icon': Icons.lock},
    {'value': 'unlock_screen', 'label': '解锁屏幕', 'icon': Icons.lock_open},
    {'value': 'reboot', 'label': '重启设备', 'icon': Icons.restart_alt},
    {'value': 'enable_kiosk', 'label': '启用Kiosk', 'icon': Icons.tv},
    {'value': 'disable_kiosk', 'label': '关闭Kiosk', 'icon': Icons.tv_off},
    {'value': 'sync_policy', 'label': '同步策略', 'icon': Icons.sync},
  ];

  @override
  void dispose() {
    _paramCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下发命令'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设备: ${widget.deviceId}',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            const Text('命令类型:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commands.map((cmd) {
                final selected = _selectedCommand == cmd['value'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cmd['icon'] as IconData,
                          size: 18,
                          color:
                              selected ? Colors.white : Colors.black87),
                      const SizedBox(width: 4),
                      Text(cmd['label'] as String),
                    ],
                  ),
                  selected: selected,
                  selectedColor: Colors.orange,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedCommand = cmd['value'] as String),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _paramCtrl,
              decoration: const InputDecoration(
                labelText: '参数 (JSON, 可选)',
                hintText: '{}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => _submit(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.white,
          ),
          child: const Text('确认下发'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    Map<String, dynamic> params = {};
    final paramText = _paramCtrl.text.trim();
    if (paramText.isNotEmpty) {
      try {
        params = Map<String, dynamic>.from(
            const JsonDecoder().convert(paramText) as Map);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参数格式错误，请输入合法 JSON')),
        );
        return;
      }
    }

    Navigator.of(context).pop({
      'command': _selectedCommand,
      'params': params,
    });
  }
}
