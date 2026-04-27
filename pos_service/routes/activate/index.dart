// 文件路径: pos_service/routes/activate/index.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  // 激活接口仅允许 POST 请求
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  return _activateDevice(context);
}

Future<Response> _activateDevice(RequestContext context) async {
  final pool = context.read<Pool>();

  try {
    // 解析前端传来的 JSON 数据
    final body = await context.request.json() as Map<String, dynamic>;
    final deviceId = body['device_id']?.toString();
    final licenseKey = body['license_key']?.toString();

    // 严苛的基础校验
    if (deviceId == null ||
        deviceId.isEmpty ||
        licenseKey == null ||
        licenseKey.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '设备指纹或授权码不能为空'},
      );
    }

    // 开启数据库事务，确保两表操作的原子性
    return await pool.runTx((session) async {
      // 1. 查验授权码：必须是 unused 状态
      final licenseResult = await session.execute(
        r"SELECT merchant_id FROM licenses WHERE license_key = $1 AND status = 'unused'",
        parameters: [licenseKey],
      );

      if (licenseResult.isEmpty) {
        return Response.json(
          statusCode: 400,
          body: {'success': false, 'error': '无效的授权码或已被使用'},
        );
      }

      final merchantId = licenseResult[0][0].toString();

      // 2. 核销授权码：标记为已使用，并打上当前设备的物理烙印
      await session.execute(
        r"UPDATE licenses SET status = 'used', bound_device_id = $1 WHERE license_key = $2",
        parameters: [deviceId, licenseKey],
      );

      // 3. 将设备写入/更新到受信任白名单库
      // 使用 ON CONFLICT，确保测试阶段即使重复录入也能平滑覆盖
      await session.execute(
        r'''
        INSERT INTO devices (device_id, merchant_id, status)
        VALUES ($1, $2, 'active')
        ON CONFLICT (device_id) 
        DO UPDATE SET merchant_id = EXCLUDED.merchant_id, status = 'active', last_active_at = CURRENT_TIMESTAMP
        ''',
        parameters: [deviceId, merchantId],
      );

      return Response.json(
        body: {'success': true, 'message': '设备激活成功', 'merchant_id': merchantId},
      );
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '激活处理异常: ${e.toString()}'},
    );
  }
}
