import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

// 1. 在全局范围内创建一个连接池 (Pool)
// 这样服务器启动时只会创建一次池，所有请求共享它
final _pool = Pool.withEndpoints(
  [
    Endpoint(
      host: 'localhost',
      database: 'pos_db',
      username: 'jie', // 你的 PostgreSQL 用户名
      password: '123456', // 你的 PostgreSQL 密码
    ),
  ],
  settings: const PoolSettings(
    sslMode: SslMode.disable, // 本地开发通常关闭 SSL
    maxConnectionCount: 10, // 最大连接数
  ),
);

Handler middleware(Handler handler) {
  // 2. 使用 provider 中间件将 pool 注入到 context 中
  // 这样在任何 route 里都可以通过 context.read<Pool>() 拿到它
  return handler.use(
    provider<Pool>((context) => _pool),
  );
}
