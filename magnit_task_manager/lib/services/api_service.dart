import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';


class ApiService {

  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return "http://127.0.0.1:8000";

      case TargetPlatform.android:
        return "http://192.168.0.125:8000";

      default:
        return "http://127.0.0.1:8000";
    }
  }

  // Токены храним в памяти (позже можно вынести в secure storage)
  static String? accessToken;
  static String? refreshToken;
  static String? userRole;

  //Авторизация

  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        accessToken = data["access_token"];
        refreshToken = data["refresh_token"];
        // Достаём роль из JWT payload (средняя часть токена)
        userRole = _getRoleFromToken(accessToken!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    if (refreshToken == null) return;
    try {
      await http.post(
        Uri.parse("$baseUrl/auth/logout"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh_token": refreshToken}),
      );
    } catch (_) {}
    accessToken = null;
    refreshToken = null;
    userRole = null;
  }

  //Задачи

  static Future<List<Map<String, dynamic>>> getTasks() async {
    final response = await http.get(
      Uri.parse("$baseUrl/tasks"),
      headers: _authHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<bool> createTask(
    String title,
    String description,
    int assigneeId,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/tasks"),
      headers: _authHeaders(),
      body: jsonEncode({
        "title": title,
        "description": description,
        "assignee_id": assigneeId,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updateTaskStatus(int taskId, String status) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/tasks/$taskId/status"),
      headers: _authHeaders(),
      body: jsonEncode({"status": status}),
    );
    return response.statusCode == 200;
  }

  //Пользователи

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(
      Uri.parse("$baseUrl/users"),
      headers: _authHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  //Вспомогательные

  static Map<String, String> _authHeaders() {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $accessToken",
    };
  }

  // Декодируем JWT payload чтобы достать роль
  static String? _getRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT payload — base64, добавляем padding если нужно
      String payload = parts[1];
      while (payload.length % 4 != 0) payload += '=';
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded);
      return data["role"];
    } catch (_) {
      return null;
    }
  }
}
