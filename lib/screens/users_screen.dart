import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Pulls the human readable message out of a failed RPC call.
String _errorText(Object e, String fallback) =>
    e is PostgrestException && e.message.isNotEmpty ? e.message : fallback;

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final u = await _api.getUsers();
      if (!mounted) return;
      setState(() { _users = u; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final status = e.toString();
      final message = status.contains('403')
          ? 'Admin access required for this page'
          : status.contains('401')
              ? 'Session expired — please log in again'
              : 'Failed to load users — check your connection';
      setState(() { _loading = false; _error = message; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.danger));
    }
  }

  void _showAddDialog() {
    final username = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    String role = 'user';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Add User'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setDlg(() => role = v ?? 'user'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              await _createUser(username.text, name.text, password.text, role);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ));
  }

  Future<void> _createUser(String username, String name, String password, String role) async {
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username and password required'), backgroundColor: AppTheme.danger));
      return;
    }
    try {
      await _api.createUser(username: username, name: name, password: password, role: role);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(e, 'Failed to create user')), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showEditDialog(dynamic user) {
    final name = TextEditingController(text: (user['name'] ?? '') as String);
    final password = TextEditingController();
    String role = (user['role'] ?? 'user') as String;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: Text('Edit ${user['username']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Reset password (optional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setDlg(() => role = v ?? 'user'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateUser(user['id'] as int, name.text, role, password.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ));
  }

  Future<void> _updateUser(int id, String name, String role, String password) async {
    try {
      await _api.updateUser(id, name: name, role: role, password: password.isEmpty ? null : password);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(e, 'Failed to update user')), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteUser(int id, String username) async {
    final auth = context.read<AuthProvider>();
    if (id == auth.user?['id']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete your own account'), backgroundColor: AppTheme.warning));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete "$username"? This permanently removes their account and data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteUser(id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(e, 'Failed to delete user')), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'users_add',
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add User', style: TextStyle(color: Colors.white)),
      ),
      body: _loading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, size: 56, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _users.isEmpty
              ? const Center(child: Text('No users yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final isAdmin = u['role'] == 'admin';
                      final isSelf = u['id'] == context.read<AuthProvider>().user?['id'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? AppTheme.primary : AppTheme.accent,
                          child: Text((u['username'] ?? '?').toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text('${u['name'] ?? ''}'.isEmpty ? (u['username'] ?? '').toString() : '${u['name']}'),
                        subtitle: Text('@${u['username']}${isSelf ? ' (you)' : ''}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: isAdmin ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(isAdmin ? 'Admin' : 'User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAdmin ? AppTheme.primary : AppTheme.accent)),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _showEditDialog(u);
                              if (v == 'delete') _deleteUser(u['id'] as int, (u['username'] ?? '').toString());
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}