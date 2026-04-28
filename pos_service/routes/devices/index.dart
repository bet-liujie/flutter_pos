import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _getDevices(context);
  }
  return Response(statusCode: 405, body: 'Method Not Allowed');
}

Future<Response> _getDevices(RequestContext context) async {
  final pool = context.read<Pool>();
  final merchantId = context.read<int>();

  try {
    final uri = context.request.url;
    final status = uri.queryParameters['status'];
    final keyword = uri.queryParameters['keyword'];
    final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
    final pageSize = int.tryParse(uri.queryParameters['page_size'] ?? '20') ?? 20;
    final offset = (page - 1) * pageSize;

    // 动态构建 SQL（位置参数）
    final conditions = <String>['d.merchant_id = \$1'];
    final params = <dynamic>[merchantId];
    int paramIndex = 2;

    if (status != null && status.isNotEmpty) {
      conditions.add('d.status = \$$paramIndex');
      params.add(status);
      paramIndex++;
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(d.device_id ILIKE \$$paramIndex)');
      params.add('%$keyword%');
      paramIndex++;
    }

    final whereClause = conditions.join(' AND ');

    // 查询总数
    final countResult = await pool.execute(
      'SELECT COUNT(*) FROM devices d WHERE $whereClause',
      parameters: params,
    );
    final total = countResult[0][0];

    // 查询设备列表，带上最新心跳
    params.add(pageSize);
    params.add(offset);
    final limitIdx = paramIndex;
    final offsetIdx = paramIndex + 1;

    final result = await pool.execute(
      '''
      SELECT
        d.device_id,
        d.merchant_id,
        d.status,
        d.last_active_at,
        h.storage_usage,
        h.memory_usage,
        h.network_type,
        h.app_version,
        h.latitude,
        h.longitude,
        h.reported_at AS last_heartbeat_at
      FROM devices d
      LEFT JOIN LATERAL (
        SELECT storage_usage, memory_usage, network_type, app_version, latitude, longitude, reported_at
        FROM heartbeat_log
        WHERE device_id = d.device_id
        ORDER BY reported_at DESC
        LIMIT 1
      ) h ON true
      WHERE $whereClause
      ORDER BY d.last_active_at DESC NULLS LAST
      LIMIT \$$limitIdx OFFSET \$$offsetIdx
      ''',
      parameters: params,
    );

    final devices = result.map((row) {
      final lastHeartbeat = row[10] as DateTime?;
      final isOnline = lastHeartbeat != null &&
          DateTime.now().toUtc().difference(lastHeartbeat.toUtc()).inMinutes < 5;
      return {
        'device_id': row[0],
        'merchant_id': row[1],
        'status': row[2],
        'last_active_at': row[3]?.toString(),
        'storage_usage': row[4],
        'memory_usage': row[5],
        'network_type': row[6],
        'app_version': row[7],
        'latitude': row[8],
        'longitude': row[9],
        'last_heartbeat_at': row[10]?.toString(),
        'online': isOnline,
      };
    }).toList();

    return Response.json(body: {
      'success': true,
      'data': {
        'devices': devices,
        'total': total,
        'page': page,
        'page_size': pageSize,
      },
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': e.toString()},
    );
  }
}
