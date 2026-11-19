import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums.dart';
import '../data/repository.dart';
import '../widgets/picker_field.dart';

/// Demo sign-in: pick a role and a user. Replace with real authentication
/// (phone/OTP, CNIC, or the company's SSO) when connecting a backend.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole role = UserRole.sdo;
  String? userId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final users = repo.users.where((u) => u.role == role).toList();
    final selected =
        users.any((u) => u.id == userId) ? userId : users.first.id;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.electric_bolt, size: 56, color: Color(0xFF0D47A1)),
                const SizedBox(height: 8),
                Text('Grid Report Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Outage and transformer reporting',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 28),
                PickerField<UserRole>(
                  label: 'Role',
                  value: role,
                  items: [
                    for (final r in UserRole.values) PickerItem(r, r.label),
                  ],
                  onChanged: (v) => setState(() {
                    role = v ?? role;
                    userId = null;
                  }),
                ),
                const SizedBox(height: 16),
                PickerField<String>(
                  label: 'User',
                  value: selected,
                  items: [for (final u in users) PickerItem(u.id, u.name)],
                  onChanged: (v) => setState(() => userId = v),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                  onPressed: () =>
                      repo.login(users.firstWhere((u) => u.id == selected)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Demo mode: no password. Data is in memory and resets on restart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
