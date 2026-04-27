import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 引入刚才创建的 AuthProvider
import 'auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/hardware_service.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  // 用于获取输入框里的激活码
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false; // 控制加载状态（可选，用于优化体验）
  bool _isFetchingCode = true; // 是否正在获取激活码
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _fetchActivationCode();
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
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey[100], // 可选：给背景加一点浅灰色，让白色窗口更凸显
      appBar: AppBar(title: const Text('设备激活'), centerTitle: true),
      body: Center(
        // 整体居中
        child: SingleChildScrollView(
          // 防止软键盘弹出时越界报错
          child: Card(
            elevation: 8, // 增加一点阴影，更有“悬浮窗口”的感觉
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // 圆角
            ),
            child: Container(
              width: 400, // 💥 核心：限制最大宽度为 400，这就是你想要的“窗口”效果
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 💥 让 Column 高度自适应内容，而不是撑满屏幕
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
                  // 激活按钮
                  SizedBox(
                    width: double
                        .infinity, // 这里的 infinity 是相对于父级宽度 (400) 的，所以按钮会填满卡片
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
        ),
      ),
    );
  }
}
