import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "http://127.0.0.1:8000";

  static Future<bool> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    return response.statusCode == 200;
  }
}