import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Ошибка для операций чтения (getTasks/getUsers) — отличаем от
/// "данных просто нет", чтобы UI не показывал "задач нет" при сбое сети.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static const String baseUrl = "http://37.99.222.184:8000";
  static const Duration _timeout = Duration(seconds: 10);

  static String? _accessToken;
  static String? _refreshToken;
  static String? _role;

  static bool get isLoggedIn => _accessToken != null;
  static String? get userRole => _role;

  //Вход / выход

  static Future<void> login(String username, String password) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty || password.isEmpty) {
      throw AuthException("Введите логин и пароль");
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse("$baseUrl/auth/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": trimmedUsername,
              "password": password,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw NetworkException("Сервер не отвечает. Проверьте подключение.");
    } catch (_) {
      throw NetworkException("Не удалось подключиться к серверу.");
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data["access_token"] as String;
      _refreshToken = data["refresh_token"] as String;
      _role = _decodeRole(_accessToken!);
      return;
    }

    if (response.statusCode == 401) {
      throw AuthException("Неверный логин или пароль", statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw AuthException("Аккаунт заблокирован", statusCode: 403);
    }
    throw AuthException(
      "Ошибка входа (код ${response.statusCode})",
      statusCode: response.statusCode,
    );
  }

  static Future<void> logout() async {
    final token = _refreshToken;
    _accessToken = null;
    _refreshToken = null;
    _role = null;

    if (token == null) return;

    // Отзываем refresh-токен на сервере. Без этого вызова токен,
    // оставшийся в памяти процесса (например, считанный отладчиком
    // или из дампа памяти), оставался бы рабочим ещё до 30 дней
    // после того, как пользователь нажал "выйти".
    try {
      await http
          .post(
            Uri.parse("$baseUrl/auth/logout"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"refresh_token": token}),
          )
          .timeout(_timeout);
    } catch (_) {
      // Сеть недоступна — локально пользователь всё равно вышел,
      // это не должно блокировать logout с точки зрения UI
    }
  }

  //JWT

  /// Декодирует поле "role" из payload JWT БЕЗ проверки подписи.
  /// Это нормально и безопасно ровно потому, что результат используется
  /// только для UI (показать/скрыть кнопку "создать задачу"), а не для
  /// реальных решений о доступе — те всегда проверяются на бэкенде
  /// через подпись токена. Клиент в принципе нельзя считать доверенным.
  static String? _decodeRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = _decodeBase64Segment(parts[1]);
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String _decodeBase64Segment(String segment) {
    var output = segment.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
    }
    return utf8.decode(base64.decode(output));
  }

  //Авторизованные запросы с авто-рефрешем

  static Map<String, String> _authHeaders() => {
    "Content-Type": "application/json",
    "Authorization": "Bearer $_accessToken",
  };

  static Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/auth/refresh"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"refresh_token": _refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data["access_token"] as String;
      _refreshToken = data["refresh_token"] as String;
      _role = _decodeRole(_accessToken!);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Единая точка для всех защищённых запросов: при 401 пробует
  /// один раз обновить access_token через refresh_token и повторяет
  /// запрос. Если рефреш тоже не сработал — разлогинивает.
  static Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    if (_accessToken == null) {
      throw AuthException("Не выполнен вход", statusCode: 401);
    }

    http.Response response;
    try {
      response = await request(_authHeaders()).timeout(_timeout);
    } on TimeoutException {
      throw NetworkException("Сервер не отвечает.");
    } catch (_) {
      throw NetworkException("Не удалось подключиться к серверу.");
    }

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await logout();
        throw AuthException("Сессия истекла, войдите снова", statusCode: 401);
      }
      try {
        response = await request(_authHeaders()).timeout(_timeout);
      } on TimeoutException {
        throw NetworkException("Сервер не отвечает.");
      } catch (_) {
        throw NetworkException("Не удалось подключиться к серверу.");
      }
    }

    return response;
  }

  //Задачи

  static Future<List<Map<String, dynamic>>> getTasks() async {
    final response = await _authorizedRequest(
      (headers) => http.get(Uri.parse("$baseUrl/tasks"), headers: headers),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException("Не удалось загрузить задачи", response.statusCode);
  }

  static Future<bool> createTask(
    String title,
    String description,
    int assigneeId,
  ) async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.post(
          Uri.parse("$baseUrl/tasks"),
          headers: headers,
          body: jsonEncode({
            "title": title,
            "description": description.isEmpty ? null : description,
            "assignee_id": assigneeId,
          }),
        ),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateTaskStatus(int taskId, String status) async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.patch(
          Uri.parse("$baseUrl/tasks/$taskId/status"),
          headers: headers,
          body: jsonEncode({"status": status}),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Пользователи ──────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _authorizedRequest(
      (headers) => http.get(Uri.parse("$baseUrl/users"), headers: headers),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(
      "Не удалось загрузить список сотрудников",
      response.statusCode,
    );
  }
}
