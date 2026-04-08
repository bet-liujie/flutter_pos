import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    // 监听网络状态变化
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // 如果结果中包含 none，说明没有任何网络连接
      final isOffline = results.contains(ConnectivityResult.none);
      setState(() {
        _hasNetwork = !isOffline;
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 你的原始 App 界面
        widget.child,
        
        // 当没有网络时，在顶部显示一个警告条
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
                    '当前网络已断开，请检查设备网络连接！',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}