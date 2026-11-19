import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums.dart';
import '../data/repository.dart';
import 'admin_screen.dart';
import 'audit_screen.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'outages/outage_list_screen.dart';
import 'reports_screen.dart';
import 'transformers/transformers_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final Widget page;
  final bool isNotifications;
  const _Dest(this.label, this.icon, this.page, {this.isNotifications = false});
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  List<_Dest> _destinations(UserRole role) => [
        const _Dest('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
        const _Dest('Outages', Icons.flash_off, OutageListScreen()),
        const _Dest('Transformers', Icons.electrical_services, TransformersScreen()),
        if (role != UserRole.reporter)
          const _Dest('Reports', Icons.assessment_outlined, ReportsScreen()),
        const _Dest('Notifications', Icons.notifications_outlined,
            NotificationsScreen(),
            isNotifications: true),
        if (role == UserRole.headOffice || role == UserRole.admin)
          const _Dest('Audit log', Icons.history, AuditScreen()),
        if (role == UserRole.admin)
          const _Dest('Admin', Icons.settings_outlined, AdminScreen()),
      ];

  Widget _icon(_Dest d, int unread) {
    final icon = Icon(d.icon);
    if (!d.isNotifications) return icon;
    return Badge(
      label: Text('$unread'),
      isLabelVisible: unread > 0,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final user = repo.currentUser!;
    final dests = _destinations(user.role);
    if (index >= dests.length) index = 0;
    final wide = MediaQuery.of(context).size.width >= 800;
    final unread = repo.unreadCount;

    void logout() {
      Navigator.of(context).popUntil((r) => r.isFirst);
      repo.logout();
    }

    final appBar = AppBar(
      title: Text(dests[index].label),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${user.name}  |  ${user.role.label}',
                style: const TextStyle(fontSize: 12)),
          ),
        ),
        IconButton(
            tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: logout),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                      icon: _icon(d, unread), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: dests[index].page),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                title: Text(user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user.role.label),
              ),
              const Divider(),
              for (var i = 0; i < dests.length; i++)
                ListTile(
                  leading: _icon(dests[i], unread),
                  title: Text(dests[i].label),
                  selected: i == index,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => index = i);
                  },
                ),
            ],
          ),
        ),
      ),
      body: dests[index].page,
    );
  }
}
