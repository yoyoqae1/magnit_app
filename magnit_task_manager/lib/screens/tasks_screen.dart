import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() => loading = true);
    final result = await ApiService.getTasks();
    setState(() {
      tasks = result;
      loading = false;
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new': return 'Новая';
      case 'in_progress': return 'В работе';
      case 'done': return 'Выполнена';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return Colors.blue;
      case 'in_progress': return Colors.orange;
      case 'done': return Colors.green;
      default: return Colors.grey;
    }
  }

  Future<void> _changeStatus(int taskId, String current) async {
    // Определяем следующий статус
    String next;
    if (current == 'new') {
      next = 'in_progress';
    } else if (current == 'in_progress') next = 'done';
    else return; // done — менять нельзя

    final ok = await ApiService.updateTaskStatus(taskId, next);
    if (ok) loadTasks();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final role = ApiService.userRole ?? '';
    final canCreate = role == 'director' || role == 'senior_seller';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Задачи"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Выйти",
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? const Center(child: Text("Задач пока нет"))
              : RefreshIndicator(
                  onRefresh: loadTasks,
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(task['title']),
                          subtitle: Text(task['description'] ?? ''),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Chip(
                                label: Text(
                                  _statusLabel(task['status']),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor: _statusColor(task['status']),
                              ),
                            ],
                          ),
                          onTap: task['status'] != 'done'
                              ? () => _changeStatus(task['id'], task['status'])
                              : null,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateTaskScreen()),
                );
                loadTasks();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}