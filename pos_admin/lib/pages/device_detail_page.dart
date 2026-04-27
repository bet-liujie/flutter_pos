import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../models/device.dart';
import '../widgets/status_badge.dart';
import '../widgets/command_dialog.dart';

class DeviceDetailPage extends StatefulWidget {
  final String deviceId;
  const DeviceDetailPage({super.key, required this.deviceId});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceProvider>();
      provider.loadDeviceDetail(widget.deviceId);
      provider.loadCommandHistory(widget.deviceId);
    });
  }

  Future<void> _showCommandDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CommandDialog(deviceId: widget.deviceId),
    );

    if (result != null && mounted) {
      final provider = context.read<DeviceProvider>();
      final success = await provider.sendCommand(
        widget.deviceId,
        result['command'] as String,
        params: result['params'] as Map<String, dynamic>,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '命令已下发' : provider.error ?? '下发失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStatusChangeDialog() async {
    const statuses = [
      {'value': 'active', 'label': '正常'},
      {'value': 'suspended', 'label': '暂停'},
      {'value': 'lost', 'label': '丢失'},
      {'value': 'retired', 'label': '退役'},
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('修改设备状态'),
        children: statuses.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(s['value']),
            child: Row(
              children: [
                StatusBadge(status: s['value'] as String),
                const SizedBox(width: 12),
                Text(s['label'] as String),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<DeviceProvider>();
      final success = await provider.updateDeviceStatus(
        widget.deviceId,
        result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '状态已更新' : provider.error ?? '更新失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设备: ${widget.deviceId}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DeviceProvider>().loadDeviceDetail(widget.deviceId);
              context.read<DeviceProvider>().loadCommandHistory(widget.deviceId);
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.deviceDetail == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.deviceDetail == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        provider.loadDeviceDetail(widget.deviceId),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final detail = provider.deviceDetail;
          if (detail == null) {
            return const Center(child: Text('设备不存在'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadDeviceDetail(widget.deviceId);
              await provider.loadCommandHistory(widget.deviceId);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(detail),
                  const SizedBox(height: 16),
                  _buildCommandCard(),
                  const SizedBox(height: 16),
                  _buildPolicyCard(detail),
                  const SizedBox(height: 16),
                  _buildCommandHistoryCard(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(DeviceDetail detail) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('设备信息',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                StatusBadge(status: detail.status),
                const SizedBox(width: 8),
                const SizedBox(width: 8),
              ],
            ),
            const Divider(),
            _infoRow('设备 ID', detail.deviceId),
            _infoRow('商家 ID', '${detail.merchantId}'),
            _infoRow('最后活跃',
                detail.lastActiveAt != null
                    ? DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format(detail.lastActiveAt!)
                    : 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings_remote, color: Colors.orange),
                SizedBox(width: 8),
                Text('远程操作',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('下发命令'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: _showCommandDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('修改状态'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: _showStatusChangeDialog,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(DeviceDetail detail) {
    if (detail.policies.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.policy, color: Colors.teal),
                SizedBox(width: 8),
                Text('绑定策略',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...detail.policies.map((p) => ListTile(
                  dense: true,
                  title: Text(p.policyName),
                  subtitle: Text('v${p.version}'),
                  trailing: StatusBadge(status: p.bindStatus),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandHistoryCard(DeviceProvider provider) {
    final commands = provider.commandHistory;
    if (commands.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.purple),
                SizedBox(width: 8),
                Text('命令历史',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...commands.take(20).map((cmd) {
              return ListTile(
                dense: true,
                leading: _commandIcon(cmd.status),
                title: Text(cmd.commandLabel),
                subtitle: Text(
                  cmd.createdAt != null
                      ? DateFormat('MM-dd HH:mm').format(cmd.createdAt!)
                      : '',
                ),
                trailing: StatusBadge(status: cmd.status),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _commandIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
      case 'failed':
        icon = Icons.error;
        color = Colors.red;
      case 'pending':
        icon = Icons.schedule;
        color = Colors.orange;
      case 'sent':
        icon = Icons.send;
        color = Colors.blue;
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 20);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
