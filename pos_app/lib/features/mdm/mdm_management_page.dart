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
  bool _isDeviceOwner = false;
  bool _uninstallBlocked = false;
  bool _keyguardDisabled = false;
  bool _statusBarDisabled = false;
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
      _mdmService.isDeviceOwner(),
    ]);

    if (!mounted) return;

    setState(() {
      _deviceInfo = results[0] as Map<String, dynamic>;
      _isAdmin = results[1] as bool;
      _isKiosk = results[2] as bool;
      _batteryInfo = results[3] as Map<String, dynamic>;
      _isDeviceOwner = results[4] as bool;
      _isLoading = false;
    });
  }

  Future<void> _toggleKiosk() async {
    bool success;
    if (_isKiosk) {
      success = await _mdmService.disableKioskMode();
    } else {
      if (_isDeviceOwner) {
        // Device Owner 模式下先设白名单再锁定
        success = await _mdmService.enableKioskModeWithLockTask();
      } else {
        success = await _mdmService.enableKioskMode();
      }
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
    await Future.delayed(const Duration(seconds: 1));
    final isAdmin = await _mdmService.hasDeviceAdminPermission();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _toggleUninstallBlocked(bool value) async {
    final success = await _mdmService.setUninstallBlocked(value);
    if (mounted) {
      setState(() => _uninstallBlocked = success ? value : !value);
      if (!success) {
        final err = _mdmService.lastError ?? '未知错误';
        debugPrint('防卸载失败: $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $err')),
        );
      }
    }
  }

  Future<void> _toggleKeyguardDisabled(bool value) async {
    final success = await _mdmService.setKeyguardDisabled(value);
    if (mounted) {
      setState(() => _keyguardDisabled = success ? value : !value);
      if (!success) {
        final err = _mdmService.lastError ?? '未知错误';
        debugPrint('锁屏禁用失败: $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $err')),
        );
      }
    }
  }

  Future<void> _toggleStatusBarDisabled(bool value) async {
    final success = await _mdmService.setStatusBarDisabled(value);
    if (mounted) {
      setState(() => _statusBarDisabled = success ? value : !value);
      if (!success) {
        final err = _mdmService.lastError ?? '未知错误';
        debugPrint('状态栏禁用失败: $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $err')),
        );
      }
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
                    _buildDeviceOwnerCard(),
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

  Widget _buildDeviceOwnerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Device Owner 能力',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Icon(
                  _isDeviceOwner ? Icons.check_circle : Icons.cancel,
                  color: _isDeviceOwner ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isDeviceOwner ? '已是 Device Owner' : '非 Device Owner',
                  style: TextStyle(
                    fontSize: 15,
                    color: _isDeviceOwner ? Colors.green : Colors.red,
                  ),
                ),
                if (!_isDeviceOwner)
                  Expanded(
                    child: Text(
                      '\n请执行: adb shell dpm set-device-owner',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),

            // 防卸载开关
            _buildSwitchRow(
              icon: Icons.block,
              iconColor: Colors.red,
              title: '禁止卸载本应用',
              subtitle: _isDeviceOwner ? null : '需 Device Owner',
              value: _uninstallBlocked,
              enabled: _isDeviceOwner,
              onChanged: _toggleUninstallBlocked,
            ),
            const Divider(height: 16),

            // 禁用锁屏开关
            _buildSwitchRow(
              icon: Icons.screen_lock_portrait,
              iconColor: Colors.orange,
              title: '禁用锁屏',
              subtitle: _isDeviceOwner ? null : '需 Device Owner',
              value: _keyguardDisabled,
              enabled: _isDeviceOwner,
              onChanged: _toggleKeyguardDisabled,
            ),
            const Divider(height: 16),

            // 禁用状态栏开关
            _buildSwitchRow(
              icon: Icons.notifications_off,
              iconColor: Colors.purple,
              title: '禁用状态栏',
              subtitle: _isDeviceOwner ? null : '需 Device Owner',
              value: _statusBarDisabled,
              enabled: _isDeviceOwner,
              onChanged: _toggleStatusBarDisabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15)),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: iconColor,
        ),
      ],
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
              icon: Icons.dangerous,
              label: '恢复出厂设置',
              subtitle: '谨慎操作！数据将全部清除',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认恢复出厂设置？'),
                    content: const Text('此操作不可逆，所有数据将被清除！'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('确认清除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await _mdmService.wipeData();
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
