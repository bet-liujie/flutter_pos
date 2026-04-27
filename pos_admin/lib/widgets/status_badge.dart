import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool? online;

  const StatusBadge({super.key, required this.status, this.online});

  @override
  Widget build(BuildContext context) {
    if (online != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: online! ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: online! ? Colors.green.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online! ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              online! ? '在线' : '离线',
              style: TextStyle(
                fontSize: 12,
                color: online! ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return _buildStatusChip();
  }

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = '正常';
      case 'suspended':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        label = '已暂停';
      case 'lost':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = '丢失';
      case 'retired':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = '已退役';
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: textColor),
      ),
    );
  }
}
