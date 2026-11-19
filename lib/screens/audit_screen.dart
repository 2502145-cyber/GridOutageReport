import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../data/repository.dart';
import '../widgets/common.dart';

/// Every state change is recorded by the repository. Essential for
/// government use: who did what, and when.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final q = query.trim().toLowerCase();
    final list = repo.audit.where((e) {
      if (q.isEmpty) return true;
      return '${e.userName} ${e.action} ${e.entityId}'.toLowerCase().contains(q);
    }).toList();

    return PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by user, action or record ID',
                isDense: true,
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No audit entries yet.'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history),
                        title: Text('${e.action}  -  ${e.entityId}'),
                        subtitle: Text('${e.userName}  |  ${fmtDateTime(e.time)}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
