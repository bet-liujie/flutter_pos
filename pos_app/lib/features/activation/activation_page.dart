import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// 引入刚才创建的 AuthProvider
import 'auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/hardware_service.dart';
import '../../services/mdm_service.dart';

/// 页面状态枚举
enum _ActivationState {
  checkingNetwork,  // 检查网络
  networkSetup,     // 配网引导
  connectingServer, // WiFi 连接成功，等待服务器
  fetchingCode,     // 获取激活码
  ready,            // 已就绪等待用户点击
  activating,       // 激活中
}

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  // 用于获取输入框里的激活码
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingCode = true;
  bool _isConnectingWifi = false;
  bool _obscurePassword = true;
  String? _fetchError;
  String? _wifiError;

  _ActivationState _pageState = _ActivationState.checkingNetwork;
  Timer? _networkRetryTimer;

  List<Map<String, dynamic>> _wifiNetworks = [];
  bool _isScanning = false;
  String? _selectedSsid;
  bool _selectedNetworkIsOpen = false;

  /// 创建一个带 Auth header 的 Dio 用于连通性检查
  Dio _authDio() => Dio(BaseOptions(
        baseUrl: ApiService().baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {'Authorization': 'Bearer test-token-123'},
      ));

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _networkRetryTimer?.cancel();
    super.dispose();
  }

  /// 检查网络连通性（带 Auth）
  Future<void> _checkConnectivity() async {
    try {
      await _authDio().get('/');
      if (!mounted) return;
      setState(() => _pageState = _ActivationState.fetchingCode);
      _networkRetryTimer?.cancel();
      _fetchActivationCode();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageState = _ActivationState.networkSetup;
      });
      _startNetworkRetry();
    }
  }

  /// 配网引导页面的自动重试定时器（带 Auth）
  void _startNetworkRetry() {
    _networkRetryTimer?.cancel();
    _networkRetryTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_pageState != _ActivationState.networkSetup) return;
      try {
        await _authDio().get('/');
        if (!mounted) return;
        _networkRetryTimer?.cancel();
        setState(() => _pageState = _ActivationState.fetchingCode);
        _fetchActivationCode();
      } catch (_) {
        // 还没连上，继续等
      }
    });
  }

  /// 页面加载时自动获取激活码
  Future<void> _fetchActivationCode() async {
    setState(() {
      _isFetchingCode = true;
      _fetchError = null;
    });

    try {
      final deviceId = await HardwareService.getDeviceId();
      final deviceInfo = await HardwareService.getDeviceInfo();

      final apiService = ApiService();
      final result = await apiService.getActivationCode(
        deviceId: deviceId,
        manufacturer: deviceInfo['manufacturer'] ?? '',
        model: deviceInfo['model'] ?? '',
      );

      if (!mounted) return;
      _codeController.text = result['license_key'] ?? '';
    } catch (e) {
      if (!mounted) return;
      _fetchError = '获取激活码失败: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCode = false;
          _pageState = _ActivationState.ready;
        });
      }
    }
  }

  // 处理激活逻辑
  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入激活码')));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 更新全局的激活状态
      await context.read<AuthProvider>().activateDevice(code);
      if (mounted) {
        context.go('/pos');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('激活失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备激活'), centerTitle: true),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_pageState) {
      case _ActivationState.checkingNetwork:
        return _buildLoadingView('正在检查网络...');
      case _ActivationState.networkSetup:
        return _buildNetworkSetupView();
      case _ActivationState.connectingServer:
        return _buildLoadingView('WiFi 已连接，正在连接服务器...');
      case _ActivationState.fetchingCode:
      case _ActivationState.ready:
      case _ActivationState.activating:
        return _buildActivationView();
    }
  }

  /// 配网引导视图
  Widget _buildNetworkSetupView() {
    return SingleChildScrollView(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题区
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('未检测到网络连接',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('请选择 WiFi 并输入密码',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 扫描按钮
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find),
                  label: Text(_isScanning ? '扫描中...' : '扫描附近 WiFi'),
                  onPressed: _isScanning ? null : _scanWifi,
                ),
              ),
              const SizedBox(height: 12),

              // WiFi 列表
              if (_wifiNetworks.isEmpty && !_isScanning)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('点击"扫描附近 WiFi"查找网络',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ),

              if (_wifiNetworks.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    itemCount: _wifiNetworks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final net = _wifiNetworks[index];
                      final ssid = net['ssid'] as String? ?? '';
                      final level = net['level'] as int? ?? 0;
                      final isOpen = net['isOpen'] as bool? ?? false;
                      final selected = _selectedSsid == ssid;
                      return ListTile(
                        dense: true,
                        leading: _wifiIcon(level),
                        title: Text(ssid,
                            style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOpen)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text('开放',
                                    style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                              ),
                            if (selected)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.check_circle,
                                    color: Colors.orange, size: 20),
                              ),
                          ],
                        ),
                        selected: selected,
                        onTap: () {
                          _passwordController.clear();
                          setState(() {
                            _selectedSsid = ssid;
                            _selectedNetworkIsOpen = isOpen;
                          });
                        },
                      );
                    },
                  ),
                ),

              // 密码输入（选中加密网络后显示）
              if (_selectedSsid != null && !_selectedNetworkIsOpen) ...[
                const Divider(),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'WiFi 密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _handleWifiConnect(),
                ),
              ],

              // 错误信息
              if (_wifiError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _wifiError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],

              // 连接按钮
              if (_selectedSsid != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isConnectingWifi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.wifi),
                    label: Text(
                      _isConnectingWifi
                          ? '连接 $_selectedSsid ...'
                          : '连接 WiFi',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isConnectingWifi ? null : _handleWifiConnect,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 扫描 WiFi
  Future<void> _scanWifi() async {
    setState(() {
      _isScanning = true;
      _wifiError = null;
    });

    final hasPermission = await MdmService().requestLocationPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _wifiError = '需要位置权限才能扫描 WiFi，请在系统设置中授予位置权限';
      });
      return;
    }

    try {
      final networks = await MdmService().scanWifiNetworks();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _wifiNetworks = networks;
        if (networks.isEmpty) {
          _wifiError = '未扫描到 WiFi 网络，请确保 WiFi 已开启';
        }
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _wifiError = _wifiScanErrorMsg(e.code, e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _wifiError = 'WiFi 扫描失败: $e';
      });
    }
  }

  String _wifiScanErrorMsg(String code, String? message) {
    switch (code) {
      case 'WIFI_DISABLED':
        return 'WiFi 未开启，请在系统设置中打开 WiFi';
      case 'SCAN_NO_RESULTS':
        return '未扫描到 WiFi 网络，请确认附近有可用 WiFi';
      default:
        return message ?? 'WiFi 扫描失败';
    }
  }

  /// 连接 WiFi
  Future<void> _handleWifiConnect() async {
    final ssid = _selectedSsid;
    final password = _passwordController.text.trim();

    if (ssid == null) {
      setState(() => _wifiError = '请先选择 WiFi 网络');
      return;
    }

    setState(() {
      _isConnectingWifi = true;
      _wifiError = null;
    });

    final ok = await MdmService().connectToWifi(ssid, password);

    if (!mounted) return;
    setState(() => _isConnectingWifi = false);

    if (ok) {
      _networkRetryTimer?.cancel();
      setState(() => _pageState = _ActivationState.connectingServer);
      _waitForServer();
    } else {
      setState(() => _wifiError = 'WiFi 连接失败，请检查密码');
    }
  }

  /// WiFi 连接成功后等待服务器可达
  Future<void> _waitForServer() async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        await _authDio().get('/');
        if (!mounted) return;
        setState(() => _pageState = _ActivationState.fetchingCode);
        _fetchActivationCode();
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _pageState = _ActivationState.networkSetup;
      _wifiError = '无法连接服务器，请检查网络';
    });
    _startNetworkRetry();
  }

  Widget _wifiIcon(int level) {
    final icon = abs(level) < 60
        ? Icons.wifi
        : abs(level) < 80
            ? Icons.wifi_2_bar
            : Icons.wifi_1_bar;
    return Icon(icon, size: 20, color: Colors.grey);
  }

  int abs(int v) => v < 0 ? -v : v;

  /// 检查中的加载视图
  Widget _buildLoadingView(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  /// 激活视图（原有逻辑）
  Widget _buildActivationView() {
    return SingleChildScrollView(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                '欢迎使用餐饮智能 OS',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              // 激活码输入框（自动获取，只读）
              TextField(
                controller: _codeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '设备激活码',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: _isFetchingCode
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _fetchError != null
                          ? IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _fetchActivationCode,
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              if (_fetchError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fetchError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _fetchActivationCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新获取'),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('立即激活', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
