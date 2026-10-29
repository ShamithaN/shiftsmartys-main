import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Use FlutterSecureStorage (consistent with AuthService)
  final _storage = const FlutterSecureStorage();

  // Helper to get the saved token
  Future<String?> getAppToken() async {
    return await _storage.read(key: 'appToken');
  }

  // Helper to build the correct headers
  Future<Map<String, String>> _getHeaders(bool useAuth) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (useAuth) {
      final token = await getAppToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        print(
            "⚠️ Warning: useAuth was true but no token was found in FlutterSecureStorage.");
      }
    }
    return headers;
  }

  /// Performs a GET request
  Future<http.Response> get(String url, {bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.get(
      Uri.parse(url),
      headers: headers,
    );
  }

  /// Performs a POST request
  Future<http.Response> post(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Performs a PUT request
  Future<http.Response> put(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Performs a DELETE request
  Future<http.Response> delete(String url, {bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.delete(
      Uri.parse(url),
      headers: headers,
    );
  }

  /// Performs a PATCH request
  Future<http.Response> patch(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.patch(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
