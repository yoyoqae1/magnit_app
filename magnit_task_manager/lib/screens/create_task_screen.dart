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

  Future<void> loadUsers() async {
    final result = await ApiService.getUsers();
    setState(() => users = result);
  }

  Future<void> submit() async {
    if (titleController.text.isEmpty || selectedUserId == null) return;

    setState(() => loading = true);
    final ok = await ApiService.createTask(
      titleController.text,
      descController.text,
      selectedUserId!,
    );
    setState(() => loading = false);

    if (!mounted) return;
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
              value: selectedUserId,
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