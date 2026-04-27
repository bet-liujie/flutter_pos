import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

// CORS 头
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Handler _addCorsHeaders(Handler handler) {
  return (context) async {
    if (context.request.method == HttpMethod.options) {
      return Response(headers: _corsHeaders);
    }
    final response = await handler(context);
    return response.copyWith(headers: {
      ...response.headers,
      ..._corsHeaders,
    });
  };
}

// 全局变量，保证在服务器生命周期内单例运行
Pool? _pool;
late DotEnv _env;

Handler middleware(Handler handler) {
  // 1. 在中间件初始化时加载环境变量
  _env = DotEnv(includePlatformEnvironment: true)..load();

  // 2. 外层包裹 CORS 支持
  return _addCorsHeaders((context) async {
    // 3. 懒加载初始化数据库连接池 (读取 .env)
    _pool ??= Pool.withEndpoints(
      [
        Endpoint(
          host: _env['DB_HOST'] ?? 'localhost',
          port: int.parse(_env['DB_PORT'] ?? '5432'),
          database: _env['DB_NAME'] ?? 'pos_db',
          username: _env['DB_USER'],
          password: _env['DB_PASSWORD'],
        ),
      ],
      settings: PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: int.parse(
          _env['DB_MAX_CONNECTIONS'] ?? '10',
        ),
      ),
    );

    // 4. SaaS 级 Token 拦截与多租户身份提取
    final requestPath = context.request.uri.path;
    final isCodeRoute = requestPath == '/activate/code';
    final isAdminLogin = requestPath == '/admin/login';

    final authHeader = context.request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      if (isCodeRoute || isAdminLogin) {
        final injectedHandler = handler
            .use(provider<Pool>((_) => _pool!))
            .use(provider<int>((_) => 1001));
        return await injectedHandler(context);
      }
      return Response.json(
        statusCode: 401,
        body: {'success': false, 'error': '未授权访问，缺失 Token'},
      );
    }

    final token = authHeader.substring(7);
    int currentMerchantId;

    try {
      if (token == 'test-token-123') {
        currentMerchantId = 1001;
      } else if (token == 'test-token-456') {
        currentMerchantId = 1002;
      } else if (token == 'admin-token-001') {
        currentMerchantId = 1001;
      } else {
        throw Exception('Invalid Token');
      }
    } catch (e) {
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': 'Token 验证失败或已过期'},
      );
    }

    // 5. 将数据库 Pool 和 merchantId 注入 Context
    final injectedHandler = handler
        .use(provider<Pool>((_) => _pool!))
        .use(provider<int>((_) => currentMerchantId));

    return await injectedHandler(context);
  });
}
