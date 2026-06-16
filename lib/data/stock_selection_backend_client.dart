import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class StockSelectionBackendClient {
  static String get defaultBaseUrl => Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  final String baseUrl;
  final http.Client _client;

  StockSelectionBackendClient({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl == null || baseUrl.trim().isEmpty) ? defaultBaseUrl : baseUrl.trim(),
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> catalog() => _get('/api/xg/catalog');

  Future<Map<String, dynamic>> analyzeSingle(Map<String, dynamic> payload) => _post('/api/xg/single', payload);

  Future<Map<String, dynamic>> backtest(Map<String, dynamic> payload) => _post('/api/xg/backtest', payload);

  Future<Map<String, dynamic>> scan(Map<String, dynamic> payload) => _post('/api/xg/scan', payload);

  Future<Map<String, dynamic>> scanS8(Map<String, dynamic> payload) => _post('/api/xg/s8/scan', payload);

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('${_trim(baseUrl)}$path');
    final response = await _client.get(uri).timeout(const Duration(seconds: 60));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${_trim(baseUrl)}$path');
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(minutes: 20));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('xg backend ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('xg backend response is not a JSON object');
  }

  static String _trim(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  void close() => _client.close();
}
