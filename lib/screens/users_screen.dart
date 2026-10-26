import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';

/// Admin only: add, remove and reset the passwords of people who use the app.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<Session>().api.users();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showMessage(context, done);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var role = 'user';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'user', label: Text('User')),
                    ButtonSegment(value: 'admin', label: Text('Admin')),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) => setDialogState(() => role = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final api = context.read<Session>().api;
    await _run(
      () => api.createUser(email: email.text.trim(), password: password.text, name: name.text.trim(), role: role),
      'User added',
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    final me = context.watch<Session>().user;
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: const Text('Add user'),
      ),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final u in users)
                  ListTile(
                    leading: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                    title: Text(u.displayName),
                    subtitle: Text('${u.email} · ${u.role}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) async {
                        if (choice == 'password') {
                          final password = await askPassword(context, 'New password for ${u.email}');
                          if (password != null && password.isNotEmpty) {
                            await _run(() => api.resetPassword(u.id, password), 'Password changed');
                          }
                        } else if (choice == 'delete') {
                          if (await confirm(context, 'Delete ${u.email}?', 'Delete')) {
                            await _run(() => api.deleteUser(u.id), 'User deleted');
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'password', child: Text('Reset password')),
                        if (u.id != me?.id) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
