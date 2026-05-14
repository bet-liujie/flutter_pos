import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/policy_provider.dart';
import '../models/policy.dart';

class PolicyListPage extends StatefulWidget {
  const PolicyListPage({super.key});

  @override
  State<PolicyListPage> createState() => _PolicyListPageState();
}

class _PolicyListPageState extends State<PolicyListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyProvider>().loadPolicies();
    });
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建策略'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '策略名称',
            hintText: '例如：门店A_营业配置',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          autofocus: true,
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
              Navigator.of(ctx).pop({'name': name});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<PolicyProvider>();
      final success = await provider.createPolicy(
        policyName: result['name']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '策略已创建' : provider.error ?? '创建失败'),
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
        title: const Text('策略管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          Consumer<PolicyProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    '共 ${provider.total} 条',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PolicyProvider>().loadPolicies(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(child: _buildPolicyTable()),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('设备策略配置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('创建策略'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyTable() {
    return Consumer<PolicyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.policies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.policies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[200]),
                const SizedBox(height: 16),
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadPolicies(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (provider.policies.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.policy_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无策略', style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 8),
                Text('点击上方"创建策略"按钮添加', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('策略名称')),
                DataColumn(label: Text('版本')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('创建时间')),
                DataColumn(label: Text('更新时间')),
                DataColumn(label: Text('操作')),
              ],
              rows: provider.policies.map((p) {
                return DataRow(
                  onSelectChanged: (_) => context.go('/policies/${p.id}'),
                  cells: [
                    DataCell(Text('${p.id}',
                        style: const TextStyle(fontSize: 13))),
                    DataCell(Text(p.policyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                    DataCell(Text('v${p.version}',
                        style: const TextStyle(fontSize: 13))),
                    DataCell(_statusChip(p.isActive)),
                    DataCell(Text(
                        p.createdAt != null
                            ? DateFormat('yyyy-MM-dd HH:mm').format(p.createdAt!)
                            : '-',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(
                        p.updatedAt != null
                            ? DateFormat('yyyy-MM-dd HH:mm').format(p.updatedAt!)
                            : '-',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/policies/${p.id}'),
                            child: const Text('详情'),
                          ),
                          TextButton(
                            onPressed: () => _confirmDelete(p.id, p.policyName),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination() {
    return Consumer<PolicyProvider>(
      builder: (context, provider, _) {
        if (provider.totalPages <= 1) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: provider.page > 1
                    ? () => provider.goToPage(provider.page - 1)
                    : null,
              ),
              Text(
                '第 ${provider.page} / ${provider.totalPages} 页',
                style: const TextStyle(fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: provider.page < provider.totalPages
                    ? () => provider.goToPage(provider.page + 1)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(bool isActive) {
    final color = isActive ? Colors.green : Colors.grey;
    final label = isActive ? '启用' : '停用';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color.shade700)),
    );
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除策略"$name"吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<PolicyProvider>();
      final success = await provider.deletePolicy(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '策略已删除' : provider.error ?? '删除失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
