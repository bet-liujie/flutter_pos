// 设备激活页：用于首次开机输入授权码激活设备
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivationPage extends StatefulWidget {
  // 激活页构造函数
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  // 激活码输入框控制器
  final TextEditingController _codeController = TextEditingController();
  // 激活按钮加载状态
  bool _isLoading = false;
  // 错误提示信息
  String? _errorMessage;

  // 激活逻辑（后续可替换为后端 API 调用）
  Future<void> _activateDevice() async {
    final code = _codeController.text.trim();
    // 校验激活码是否为空
    if (code.isEmpty) {
      setState(() => _errorMessage = '请输入设备授权码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 模拟网络请求延迟
    await Future.delayed(const Duration(seconds: 2));

    // 假设老板设定的超级激活码是 "888888"
    if (code == '888888') {
      // 激活成功：写入本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_device_activated', true);
      await prefs.setString('store_name', '测试门店01'); // 可以顺便存点门店信息

      if (!mounted) return;
      // 弹出激活成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设备激活成功！重启系统生效。'),
          backgroundColor: Colors.green,
        ),
      );

      // 注意：这里只弹提示，不跳转页面，后续可集成状态管理后切换主界面
    } else {
      setState(() {
        _errorMessage = '授权码无效，请联系服务商获取';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 构建激活页 UI
    return Scaffold(
      backgroundColor: Colors.grey[200], // 灰色背景更能衬托中间的卡片
      body: Center(
        child: Container(
          width: 400, // 限制卡片宽度，在 Windows 屏幕上显得精致
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 紧凑包裹内容
            children: [
              // 顶部 Logo 图标
              // Logo 或 图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  size: 60,
                  color: Colors.orangeAccent.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // 标题区
              // 标题
              const Text(
                '欢迎使用智能云餐饮系统',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '首次开机，请绑定门店授权码以激活设备',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // 激活码输入框
              // 激活码输入框
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '请输入授权码',
                  hintStyle: const TextStyle(
                    fontSize: 16,
                    letterSpacing: 0,
                    fontWeight: FontWeight.normal,
                  ),
                  errorText: _errorMessage,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.orangeAccent.shade700,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 激活按钮
              // 激活按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _activateDevice,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '立即激活',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // 底部技术支持提示
              // 底部技术支持提示
              const SizedBox(height: 24),
              Text(
                '需要帮助？请联系服务商或拨打 400-xxx-xxxx',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
