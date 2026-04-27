import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  return _generateCode(context);
}

Future<Response> _generateCode(RequestContext context) async {
  final pool = context.read<Pool>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final deviceId = body['device_id']?.toString();
    final model = body['model']?.toString() ?? '';
    final manufacturer = body['manufacturer']?.toString() ?? '';

    if (deviceId == null || deviceId.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '缺少设备ID'},
      );
    }

    // 基于硬件信息生成确定性的激活码
    // SHA256(device_id|manufacturer|model|salt) 前12位十六进制
    final rawData = '$deviceId|$manufacturer|$model|mdm_seed_2024';
    final bytes = utf8.encode(rawData);
    final digest = sha256.convert(bytes);
    final hexStr = digest.toString().toUpperCase();
    final code = '${hexStr.substring(0, 4)}-${hexStr.substring(4, 8)}-${hexStr.substring(8, 12)}';

    // 检查激活码是否已存在
    final existing = await pool.execute(
      'SELECT status, bound_device_id FROM licenses WHERE license_key = \$1',
      parameters: [code],
    );

    if (existing.isNotEmpty) {
      final row = existing[0];
      final status = row[0] as String;
      final boundDevice = row[1] as String?;

      if (status == 'used' && boundDevice == deviceId) {
        return Response.json(body: {
          'success': true,
          'data': {'license_key': code, 'is_new': false},
        });
      }

      if (status == 'used' && boundDevice != deviceId) {
        return Response.json(
          statusCode: 409,
          body: {'success': false, 'error': '激活码冲突，请重试'},
        );
      }

      return Response.json(body: {
        'success': true,
        'data': {'license_key': code, 'is_new': false},
      });
    }

    // 写入新激活码（测试阶段统一归属 merchant 1001）
    await pool.execute(
      "INSERT INTO licenses (license_key, merchant_id, status) VALUES (\$1, '1001', 'unused')",
      parameters: [code],
    );

    return Response.json(body: {
      'success': true,
      'data': {'license_key': code, 'is_new': true},
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '激活码生成异常: ${e.toString()}'},
    );
  }
}
