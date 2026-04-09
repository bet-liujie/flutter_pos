import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 引入刚才创建的 AuthProvider
import 'auth_provider.dart';
import 'package:go_router/go_router.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  // 用于获取输入框里的激活码
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false; // 控制加载状态（可选，用于优化体验）

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
                  // 激活码输入框
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: '设备激活码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
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
