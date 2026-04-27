import 'package:flutter/material.dart';
import '../../services/mdm_service.dart';

/// MDM管理页面 - 仅在Android平台显示
class MdmManagementPage extends StatefulWidget {
  const MdmManagementPage({super.key});

  @override
  State<MdmManagementPage> createState() => _MdmManagementPageState();
}

class _MdmManagementPageState extends State<MdmManagementPage> {
  final MdmService _mdmService = MdmService();
  Map<String, dynamic>? _deviceInfo;
  Map<String, dynamic>? _batteryInfo;
  bool _isAdmin = false;
  bool _isKiosk = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllInfo();
  }

  Future<void> _loadAllInfo() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _mdmService.getDeviceInfo(),
      _mdmService.hasDeviceAdminPermission(),
      _mdmService.isKioskModeEnabled(),
      _mdmService.getBatteryInfo(),
    ]);

    if (!mounted) return;

    setState(() {
      _deviceInfo = results[0] as Map<String, dynamic>;
      _isAdmin = results[1] as bool;
      _isKiosk = results[2] as bool;
      _batteryInfo = results[3] as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  Future<void> _toggleKiosk() async {
    bool success;
    if (_isKiosk) {
      success = await _mdmService.disableKioskMode();
    } else {
      success = await _mdmService.enableKioskMode();
    }

    if (!mounted) return;

    if (success) {
      setState(() => _isKiosk = !_isKiosk);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请检查设备管理员权限')),
      );
    }
  }

  Future<void> _requestAdmin() async {
    await _mdmService.requestDeviceAdminPermission();
    // 从设置返回后重新检查权限状态
    await Future.delayed(const Duration(seconds: 1));
    final isAdmin = await _mdmService.hasDeviceAdminPermission();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mdmService.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('设备管理')),
        body: const Center(
          child: Text(
            'MDM功能仅在Android平台可用',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理 (MDM)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceInfoCard(),
                    const SizedBox(height: 16),
                    _buildPermissionCard(),
                    const SizedBox(height: 16),
                    _buildBatteryCard(),
                    const SizedBox(height: 16),
                    _buildManagementActionsCard(),
                    const SizedBox(height: 16),
                    _buildSettingsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDeviceInfoCard() {
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
                const Text(
                  '设备信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAllInfo,
                ),
              ],
            ),
            const Divider(),
            if (_deviceInfo != null) ...[
              _buildInfoRow('制造商', _deviceInfo!['manufacturer'] ?? 'N/A'),
              _buildInfoRow('型号', _deviceInfo!['model'] ?? 'N/A'),
              _buildInfoRow('品牌', _deviceInfo!['brand'] ?? 'N/A'),
              _buildInfoRow('设备', _deviceInfo!['device'] ?? 'N/A'),
              _buildInfoRow('Android版本', _deviceInfo!['androidVersion'] ?? 'N/A'),
              _buildInfoRow('SDK版本', _deviceInfo!['sdkInt']?.toString() ?? 'N/A'),
              _buildInfoRow('设备ID', _deviceInfo!['id'] ?? 'N/A'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '设备管理员状态',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Icon(
                  _isAdmin ? Icons.check_circle : Icons.cancel,
                  color: _isAdmin ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAdmin ? '已授权设备管理员权限' : '未授权设备管理员权限',
                  style: TextStyle(
                    fontSize: 15,
                    color: _isAdmin ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (!_isAdmin) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shield),
                  label: const Text('去授权'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _requestAdmin,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  _isKiosk ? Icons.lock_outline : Icons.lock_open,
                  color: _isKiosk ? Colors.orange : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isKiosk ? 'Kiosk模式已启用' : 'Kiosk模式未启用',
                  style: TextStyle(
                    fontSize: 15,
                    color: _isKiosk ? Colors.orange : Colors.grey,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isKiosk,
                  onChanged: (_isAdmin) ? (_) => _toggleKiosk() : null,
                  activeTrackColor: Colors.orange,
                ),
              ],
            ),
            if (!_isAdmin && !_isKiosk)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '需先授权设备管理员权限才能启用Kiosk模式',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    final level = _batteryInfo?['level'];
    final temp = _batteryInfo?['temperature'];
    final isCharging = _batteryInfo?['is_charging'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.battery_full, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '电池信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: level != null ? level / 100.0 : null,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          level != null && level < 20 ? Colors.red :
                          level != null && level < 50 ? Colors.orange :
                          Colors.green,
                        ),
                      ),
                      Text(
                        '${level ?? '?'}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('电量: ${level ?? 'N/A'}%'),
                    const SizedBox(height: 4),
                    if (temp != null)
                      Text('温度: ${temp.toStringAsFixed(1)}°C'),
                    if (isCharging)
                      const Row(
                        children: [
                          Icon(Icons.bolt, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('充电中', style: TextStyle(color: Colors.amber)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '设备管理操作',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildActionButton(
              icon: Icons.lock,
              label: '锁定屏幕',
              subtitle: _isAdmin ? null : '需设备管理员权限',
              onPressed: () async {
                final success = await _mdmService.lockScreen();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '屏幕已锁定' : '锁屏失败，请检查设备管理员权限'),
                    ),
                  );
                  if (!success) _loadAllInfo();
                }
              },
            ),
            _buildActionButton(
              icon: Icons.security,
              label: '设备管理员设置',
              onPressed: _mdmService.openDeviceAdminSettings,
            ),
            _buildActionButton(
              icon: Icons.settings_applications,
              label: '应用设置',
              onPressed: _mdmService.openAppSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '系统设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildActionButton(
              icon: Icons.wifi,
              label: 'WiFi设置',
              onPressed: _mdmService.openWifiSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(icon),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
