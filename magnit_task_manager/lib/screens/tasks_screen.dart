import 'package:flutter/material.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои задачи"),
      ),
      body: const Center(
        child: Text(
          "Задачи появятся здесь",
          style: TextStyle(
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}