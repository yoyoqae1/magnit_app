import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final titleController = TextEditingController();
  final descController = TextEditingController();

  List<Map<String, dynamic>> users = [];
  int? selectedUserId;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    try {
      final result = await ApiService.getUsers();
      if (!mounted) return;
      setState(() => users = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить список сотрудников: $e')),
      );
    }
  }

  Future<void> submit() async {
    final title = titleController.text.trim();

    // Дублируем минимальную проверку с бэкенда (там title >= 3 символов) —
    // чтобы пользователь не ждал round-trip к серверу ради простой опечатки.
    // Бэкенд всё равно остаётся источником истины и перепроверяет это сам.
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Название минимум 3 символа")),
      );
      return;
    }
    if (selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Выберите исполнителя")),
      );
      return;
    }

    setState(() => loading = true);
    final ok = await ApiService.createTask(
      title,
      descController.text.trim(),
      selectedUserId!,
    );
    if (!mounted) return;
    setState(() => loading = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ошибка создания задачи")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Новая задача")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Название"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Описание"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selectedUserId,
              hint: const Text("Выберите исполнителя"),
              items: users.map((u) {
                return DropdownMenuItem<int>(
                  value: u['id'],
                  child: Text("${u['username']} (${u['role']})"),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedUserId = val),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : submit,
              child: Text(loading ? "..." : "Создать"),
            ),
          ],
        ),
      ),
    );
  }
}