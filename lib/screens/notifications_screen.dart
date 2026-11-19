import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import 'outages/outage_detail_screen.dart';
import 'transformers/install_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final list = repo.myNotifications;

    return PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('${repo.unreadCount} unread'),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.done_all),
                label: const Text('Mark all read'),
                onPressed: repo.unreadCount == 0 ? null : repo.markAllRead,
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No notifications.'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final n = list[i];
                      final isEscalation = n.message.startsWith('ESCALATION');
                      return ListTile(
                        tileColor: n.read ? null : Colors.blue.withOpacity(0.06),
                        leading: Icon(
                          isEscalation ? Icons.trending_up : Icons.notifications,
                          color: isEscalation ? Colors.deepOrange : Colors.blue,
                        ),
                        title: Text(n.message,
                            style: TextStyle(
                                fontWeight:
                                    n.read ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(fmtDateTime(n.time)),
                        onTap: () {
                          n.read = true;
                          repo.touch();
                          final id = n.entityId;
                          if (id == null) return;
                          if (id.startsWith('OUT-')) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        OutageDetailScreen(outageId: id)));
                          } else if (id.startsWith('INS-')) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        InstallDetailScreen(jobId: id)));
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
