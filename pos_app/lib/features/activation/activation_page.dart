import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 引入刚才创建的 AuthProvider
import 'auth_provider.dart'; 

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入激活码')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 💥 核心改变：以前这里可能写了本地存储和 Navigator 跳转
      // 现在只需要调用 AuthProvider 里的方法即可
      await context.read<AuthProvider>().activateDevice(code);
      
      // 注意：这里不需要写任何 Navigator.push 代码！
      // 只要 activateDevice 执行成功并调用了 notifyListeners()，
      // go_router 就会瞬间自动把你切到 /pos 页面。
      
    } catch (e) {
      // 假设以后接口报错，可以在这里处理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('激活失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
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
      appBar: AppBar(
        title: const Text('设备激活'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
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
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
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