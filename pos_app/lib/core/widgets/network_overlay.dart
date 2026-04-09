import 'dart:async';
import 'dart:io'; // 引入 Socket 所在的库
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkOverlay extends StatefulWidget {
  final Widget child;

  const NetworkOverlay({super.key, required this.child});

  @override
  State<NetworkOverlay> createState() => _NetworkOverlayState();
}

class _NetworkOverlayState extends State<NetworkOverlay> {
  bool _hasNetwork = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _pingTimer;

  //  配置你的后端真实 IP 和 端口
  final String _backendHost = '192.168.43.251';
  final int _backendPort = 8080;

  @override
  void initState() {
    super.initState();

    // 1. 依然保留插件监听，用于捕获 Android/手机 端拔掉 Wi-Fi 的“瞬间”
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _checkRealConnection();
    });

    // 2. 💥 新增：跨平台通用的“心跳检测”，每 3 秒检测一次后端是否存活
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkRealConnection();
    });
  }

  // 💥 真正的跨平台检测逻辑
  Future<void> _checkRealConnection() async {
    bool isConnected = false;
    try {
      // 尝试与后端建立 Socket 连接，超时时间设为 2 秒
      final socket = await Socket.connect(
        _backendHost,
        _backendPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy(); // 连上了就立马销毁，不占用资源
      isConnected = true;
    } catch (_) {
      // 报错了（比如 Connection refused 或 Timeout），说明真断网了或后端挂了
      isConnected = false;
    }

    if (mounted && _hasNetwork != isConnected) {
      setState(() {
        _hasNetwork = isConnected;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_hasNetwork)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.redAccent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  child: const Text(
                    '与服务器断开连接，请检查网络或后台服务！',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
