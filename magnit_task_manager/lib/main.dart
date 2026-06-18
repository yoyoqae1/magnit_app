import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/tasks_screen.dart';

void main() {
  runApp(const MagnitApp());
}

class MagnitApp extends StatelessWidget {
  const MagnitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Magnit Task Manager',
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/tasks': (context) => const TasksScreen(),
      },
    );
  }
}