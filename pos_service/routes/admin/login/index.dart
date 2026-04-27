import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }
  return _login(context);
}

Future<Response> _login(RequestContext context) async {
  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final username = body['username']?.toString();
    final password = body['password']?.toString();

    if (username == null || password == null) {
      return Response.json(
        statusCode: 400,
        body: {'success': false, 'error': '用户名和密码不能为空'},
      );
    }

    // v1 硬编码管理员
    if (username == 'admin' && password == 'admin123') {
      return Response.json(body: {
        'success': true,
        'data': {
          'token': 'admin-token-001',
          'merchant_id': 1001,
          'username': 'admin',
        },
      });
    }

    return Response.json(
      statusCode: 401,
      body: {'success': false, 'error': '用户名或密码错误'},
    );
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'success': false, 'error': '登录处理异常: ${e.toString()}'},
    );
  }
}
