import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/policy_provider.dart';
import '../providers/device_provider.dart';
import '../models/policy.dart';
import '../models/device.dart';
import '../widgets/status_badge.dart';

class PolicyDetailPage extends StatefulWidget {
  final int policyId;
  const PolicyDetailPage({super.key, required this.policyId});

  @override
  State<PolicyDetailPage> createState() => _PolicyDetailPageState();
}

class _PolicyDetailPageState extends State<PolicyDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyProvider>().loadPolicyDetail(widget.policyId);
    });
  }

  Future<void> _showEditDialog() async {
    final detail = context.read<PolicyProvider>().policyDetail;
    if (detail == null) return;

    final nameCtrl = TextEditingController(text: detail.policyName);
    final dataCtrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(detail.policyData),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑策略'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '策略名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dataCtrl,
                  decoration: const InputDecoration(
                    labelText: '策略数据 (JSON)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 8,
                  minLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              Map<String, dynamic>? policyData;
              try {
                final raw = dataCtrl.text.trim();
                if (raw.isNotEmpty) {
                  policyData = Map<String, dynamic>.from(
                    const JsonDecoder().convert(raw) as Map,
                  );
                }
              } catch (_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('JSON 格式错误'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(ctx).pop({
                'policy_name': name,
                'policy_data': policyData,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<PolicyProvider>();
      final success = await provider.updatePolicy(
        widget.policyId,
        policyName: result['policy_name'] as String,
        policyData: result['policy_data'] as Map<String, dynamic>?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '策略已更新' : provider.error ?? '更新失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBindDialog() async {
    // 加载可用设备列表
    if (mounted) {
      await context.read<DeviceProvider>().loadDevices();
    }

    if (!mounted) return;
    final devices = context.read<DeviceProvider>().devices;
    final selected = <String>{};

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('绑定设备'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: devices.isEmpty
                ? const Center(child: Text('暂无可用设备'))
                : ListView(
                    children: devices.map((d) {
                      return CheckboxListTile(
                        title: Text(d.deviceId,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Row(
                          children: [
                            StatusBadge(status: d.status),
                            const SizedBox(width: 8),
                            StatusBadge(status: d.status, online: d.online),
                          ],
                        ),
                        value: selected.contains(d.deviceId),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(d.deviceId);
                            } else {
                              selected.remove(d.deviceId);
                            }
                          });
                        },
                        dense: true,
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(selected.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
              ),
              child: Text('绑定 (${selected.length})'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final provider = context.read<PolicyProvider>();
      final success = await provider.bindDevices(widget.policyId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '设备已绑定' : provider.error ?? '绑定失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmUnbind(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认解绑'),
        content: Text('确定要解绑设备 "$deviceId" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('解绑', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<PolicyProvider>();
      final success = await provider.unbindDevice(widget.policyId, deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '设备已解绑' : provider.error ?? '解绑失败'),
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
        title: Text('策略 #${widget.policyId}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<PolicyProvider>().loadPolicyDetail(widget.policyId),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Consumer<PolicyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.policyDetail == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.policyDetail == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        provider.loadPolicyDetail(widget.policyId),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final detail = provider.policyDetail;
          if (detail == null) {
            return const Center(child: Text('策略不存在'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(detail),
                const SizedBox(height: 16),
                _buildPolicyDataCard(detail),
                const SizedBox(height: 16),
                _buildBoundDevicesCard(detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(PolicyDetail detail) {
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
                Text('策略信息',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _infoRow('策略名称', detail.policyName),
            _infoRow('版本', 'v${detail.version}'),
            _infoRow('状态', detail.isActive ? '启用' : '停用'),
            _infoRow('创建时间',
                detail.createdAt != null
                    ? DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format(detail.createdAt!)
                    : 'N/A'),
            _infoRow('更新时间',
                detail.updatedAt != null
                    ? DateFormat('yyyy-MM-dd HH:mm:ss')
                        .format(detail.updatedAt!)
                    : 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyDataCard(PolicyDetail detail) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(detail.policyData);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.data_object, color: Colors.blue),
                SizedBox(width: 8),
                Text('策略数据 (JSON)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SelectableText(
                jsonStr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundDevicesCard(PolicyDetail detail) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text('绑定设备',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${detail.boundDevices.length} 台',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('绑定设备'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: _showBindDialog,
                ),
              ],
            ),
            const Divider(),
            if (detail.boundDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('暂未绑定设备',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...detail.boundDevices.map((b) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.phone_android, size: 20),
                    title: Text(b.deviceId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Row(
                      children: [
                        Text('同步状态: ${b.bindStatusLabel}',
                            style: const TextStyle(fontSize: 12)),
                        if (b.syncedAt != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MM-dd HH:mm').format(b.syncedAt!),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.link_off,
                          color: Colors.red[300], size: 20),
                      tooltip: '解绑',
                      onPressed: () => _confirmUnbind(b.deviceId),
                    ),
                  )),
          ],
        ),
      ),
    );
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
