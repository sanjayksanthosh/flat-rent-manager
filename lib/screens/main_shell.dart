import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'properties_screen.dart';
import 'tenants_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Tabs are created only the first time they are opened, so startup does not
  // build every screen (and its data crunching) before the first frame.
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      context.read<AppProvider>().bindSession('${user?['id']}');
    });
  }

  Future<void> _showChangePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final auth = context.read<AuthProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              if (next.text != confirm.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppTheme.danger),
                );
                return;
              }
              final error = await auth.changePassword(current.text, next.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error ?? 'Password changed'),
                  backgroundColor: error == null ? AppTheme.success : AppTheme.danger,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Widget _buildPage(int i, bool isAdmin) {    return _pageCache.putIfAbsent(i, () {
      switch (i) {
        case 0: return const HomeScreen();
        case 1: return const PropertiesScreen();
        case 2: return const TenantsScreen();
        case 3: return const PaymentsScreen();
        case 4: return const ReportsScreen();
        default: return isAdmin ? const UsersScreen() : const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    final count = isAdmin ? 6 : 5;
    final pages = List<Widget>.generate(count, (i) {
      if (i == _index) return _buildPage(i, isAdmin);
      return _pageCache[i] ?? const SizedBox.shrink();
    });

    final bottomNavDestinations = [
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: 'Buildings'),
      const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Tenants'),
      const NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Payments'),
      const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
      if (isAdmin) const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Users'),
    ];

    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: AppTheme.primary,
          child: Row(children: [
            const Icon(Icons.apartment, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            const Expanded(child: Text('Rent Manager', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
            Text('Signed in: ${auth.displayName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.key_outlined, size: 16, color: Colors.white),
              tooltip: 'Change password',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: _showChangePassword,
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 16, color: Colors.white),
              tooltip: 'Logout',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ]),
        ),
        // Slim, non-blocking progress while a background refresh is running.
        SizedBox(
          height: 2,
          child: p.refreshing
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox.shrink(),
        ),
        if (!p.isOnline && !p.refreshing)
          GestureDetector(
            onTap: () => p.retrySync(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.warning,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.cloud_off, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Offline — tap to retry sync', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        if (auth.mustChangePassword)
          GestureDetector(
            onTap: _showChangePassword,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.accent,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.key_outlined, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('You are using a temporary password — tap to change it', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        Expanded(child: IndexedStack(index: _index, children: pages)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) setState(() => _index = i);
        },
        destinations: bottomNavDestinations,
      ),
    );
  }
}
