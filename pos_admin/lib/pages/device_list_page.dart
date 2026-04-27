import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../widgets/status_badge.dart';

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceProvider>();
      provider.loadDevices();
      provider.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    // Note: provider.dispose() stops the timer, but since it's provided higher up,
    // we handle stopping in the widget's dispose
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<DeviceProvider>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          Consumer<DeviceProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    '共 ${provider.total} 台',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DeviceProvider>().loadDevices(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusFilter(),
          const Divider(height: 1),
          Expanded(child: _buildDeviceTable()),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '搜索设备 ID...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    context.read<DeviceProvider>().search('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    const filters = [
      {'value': null, 'label': '全部'},
      {'value': 'active', 'label': '正常'},
      {'value': 'suspended', 'label': '已暂停'},
      {'value': 'lost', 'label': '丢失'},
      {'value': 'retired', 'label': '已退役'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final selected = provider.statusFilter == f['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f['label'] as String),
                    selected: selected,
                    onSelected: (_) => provider.filterStatus(f['value']),
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceTable() {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.devices.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[200]),
                const SizedBox(height: 16),
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadDevices(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (provider.devices.isEmpty) {
          return const Center(
            child: Text('暂无设备', style: TextStyle(color: Colors.grey)),
          );
        }

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: 0,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('设备 ID')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('在线')),
                DataColumn(label: Text('位置')),
                DataColumn(label: Text('存储')),
                DataColumn(label: Text('内存')),
                DataColumn(label: Text('最后心跳')),
                DataColumn(label: Text('操作')),
              ],
              rows: provider.devices.map((device) {
                return DataRow(
                  onSelectChanged: (_) =>
                      context.go('/devices/${device.deviceId}'),
                  cells: [
                    DataCell(Text(device.deviceId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13))),
                    DataCell(StatusBadge(status: device.status)),
                    DataCell(StatusBadge(
                        status: device.status, online: device.online)),
                    DataCell(
                      Text(
                        device.latitude != null && device.longitude != null
                            ? '${device.latitude!.toStringAsFixed(4)}, ${device.longitude!.toStringAsFixed(4)}'
                            : '-',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(Text(
                        device.storageUsage != null
                            ? '${device.storageUsage!.toStringAsFixed(1)}%'
                            : '-',
                        style: const TextStyle(fontSize: 13))),
                    DataCell(Text(
                        device.memoryUsage != null
                            ? '${device.memoryUsage!.toStringAsFixed(1)}%'
                            : '-',
                        style: const TextStyle(fontSize: 13))),
                    DataCell(
                      Text(
                        device.lastHeartbeatAt != null
                            ? DateFormat('MM-dd HH:mm')
                                .format(device.lastHeartbeatAt!)
                            : '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.online
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      TextButton(
                        onPressed: () =>
                            context.go('/devices/${device.deviceId}'),
                        child: const Text('详情'),
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
    return Consumer<DeviceProvider>(
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
}
