import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

// 全局变量，保证在服务器生命周期内单例运行
Pool? _pool;
late DotEnv _env;

Handler middleware(Handler handler) {
  // 1. 在中间件初始化时加载环境变量
  _env = DotEnv(includePlatformEnvironment: true)..load();

  return (context) async {
    // 2. 懒加载初始化数据库连接池 (读取 .env)
    _pool ??= Pool.withEndpoints(
      [
        Endpoint(
          host: _env['DB_HOST'] ?? 'localhost',
          port: int.parse(_env['DB_PORT'] ?? '5432'),
          database: _env['DB_NAME'] ?? 'pos_db',
          username: _env['DB_USER'], // ✨ 正确位置：账号写在 Endpoint 里
          password: _env['DB_PASSWORD'], // ✨ 正确位置：密码写在 Endpoint 里
        ),
      ],
      settings: PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: int.parse(
          _env['DB_MAX_CONNECTIONS'] ?? '10',
        ), // ✨ 正确参数名
      ),
    );

    // 3. ✨ SaaS 级 Token 拦截与多租户身份提取
    final authHeader = context.request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.json(
        statusCode: 401,
        body: {'success': false, 'error': '未授权访问，缺失 Token'},
      );
    }

    final token = authHeader.substring(7);
    int currentMerchantId;

    try {
      // TODO: 商业项目中，这里需要用 dart_jsonwebtoken 之类的包验证签名并解出 payload
      // 现在的核心架构思想是：merchant_id 绝对不能由前端随便传，必须由后端在这里从加密 Token 里解析出来！
      if (token == 'test-token-123') {
        currentMerchantId = 1001; // 解析出：商户 A
      } else if (token == 'test-token-456') {
        currentMerchantId = 1002; // 解析出：商户 B
      } else {
        throw Exception('Invalid Token');
      }
    } catch (e) {
      return Response.json(
        statusCode: 403,
        body: {'success': false, 'error': 'Token 验证失败或已过期'},
      );
    }

    // 4. 将 数据库 Pool 和 解析出的 merchantId 一起注入到 Context 中
    final injectedHandler = handler
        .use(provider<Pool>((_) => _pool!))
        .use(provider<int>((_) => currentMerchantId)); // ✨ 向后传递商户 ID

    // 放行请求到具体的 Route (例如 index.dart)
    return await injectedHandler(context);
  };
}
