import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'tasks_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final loginController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool loading = false;

  Future<void> login() async {

    setState(() {
      loading = true;
    });

    final success =
        await ApiService.login(
      loginController.text,
      passwordController.text,
    );

    setState(() {
      loading = false;
    });

    if (!mounted) return;

    if (success) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const TasksScreen(),
        ),
      );

    } else {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Ошибка входа"),
        ),
      );

}
  }

  @override
  Widget build(
      BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text(
        "Вход",
      )),
      body: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller:
                  loginController,
              decoration:
                  const InputDecoration(
                labelText:
                    "Логин",
              ),
            ),

            const SizedBox(
                height: 20),

            TextField(
              controller:
                  passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(
                labelText:
                    "Пароль",
              ),
            ),

            const SizedBox(
                height: 30),

            ElevatedButton(
              onPressed:
                  loading
                      ? null
                      : login,
              child: Text(
                loading
                    ? "..."
                    : "Войти",
              ),
            ),
          ],
        ),
      ),
    );
  }
}