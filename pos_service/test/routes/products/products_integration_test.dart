import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Integration Tests /products API', () {
    const baseUrl = 'http://localhost:8080/products';

    test('POST create product - normal', () async {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': '集成测试商品', 'price': 123.45}),
      );
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['status'], 'created');
      expect(data['id'], isNotNull);
    });

    test('POST create product - missing field', () async {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'price': 123.45}),
      );
      expect(response.statusCode, isNot(200));
    });

    test('POST create product - invalid price', () async {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': '商品', 'price': 'abc'}),
      );
      expect(response.statusCode, isNot(200));
    });

    test('GET all products', () async {
      final response = await http.get(Uri.parse(baseUrl));
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['status'], 'ok');
      expect(data['items'], isList);
    });

    test('GET product by id - not found', () async {
      final response = await http.get(Uri.parse('$baseUrl?id=999999'));
      expect(response.statusCode, isNot(200));
    });

    test('PUT update product - normal', () async {
      // 先创建一个商品
      final createResp = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': '待更新', 'price': 1}),
      );
      final id = jsonDecode(createResp.body)['id'];
      // 更新
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'name': '已更新', 'price': 2}),
      );
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['status'], 'updated');
    });

    test('PUT update product - not found', () async {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': 999999, 'name': '不存在', 'price': 2}),
      );
      expect(response.statusCode, isNot(200));
    });

    test('DELETE product - normal', () async {
      // 先创建一个商品
      final createResp = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': '待删除', 'price': 1}),
      );
      final id = jsonDecode(createResp.body)['id'];
      // 删除
      final response = await http.delete(Uri.parse('$baseUrl?id=$id'));
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['status'], 'deleted');
    });

    test('DELETE product - not found', () async {
      final response = await http.delete(Uri.parse('$baseUrl?id=999999'));
      expect(response.statusCode, isNot(200));
    });

    test('DELETE product - missing id', () async {
      final response = await http.delete(Uri.parse(baseUrl));
      expect(response.statusCode, isNot(200));
    });
  });
}
