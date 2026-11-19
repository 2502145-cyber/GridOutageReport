import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/formatters.dart';
import '../../data/repository.dart';
import '../../models/outage.dart';
import '../../widgets/common.dart';
import 'outage_detail_screen.dart';
import 'outage_form_screen.dart';

class _Filter {
  final String label;
  final bool Function(Outage) test;
  const _Filter(this.label, this.test);
}

class OutageListScreen extends StatefulWidget {
  const OutageListScreen({super.key});

  @override
  State<OutageListScreen> createState() => _OutageListScreenState();
}

class _OutageListScreenState extends State<OutageListScreen> {
  int filterIndex = 1;
  String query = '';

  static final _filters = <_Filter>[
    _Filter('All', (o) => true),
    _Filter('Open', (o) => o.isOpen),
    _Filter('Escalated', (o) => o.isOpen && o.escalation != EscalationLevel.none),
    _Filter('Restored', (o) => o.status == OutageStatus.restored),
    _Filter('Closed', (o) => o.status == OutageStatus.closed),
  ];

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final q = query.trim().toLowerCase();
    final list = repo.visibleOutages.where((o) {
      if (!_filters[filterIndex].test(o)) return false;
      if (q.isEmpty) return true;
      final hay =
          '${o.id} ${repo.feederById(o.feederId).name} ${o.cause} ${repo.areaPath(o.subDivisionId)}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Report outage'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OutageFormScreen())),
      ),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by ID, feeder, cause or area',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < _filters.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_filters[i].label),
                        selected: filterIndex == i,
                        onSelected: (_) => setState(() => filterIndex = i),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${list.length} outage(s)',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No outages match.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) => OutageTile(outage: list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class OutageTile extends StatelessWidget {
  final Outage outage;
  const OutageTile({super.key, required this.outage});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final o = outage;
    final feeder = repo.feederById(o.feederId);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OutageDetailScreen(outageId: o.id))),
        leading: CircleAvatar(
          backgroundColor: outageStatusColor(o.status).withOpacity(0.12),
          child: Icon(Icons.flash_off, color: outageStatusColor(o.status)),
        ),
        title: Text('${o.id}  -  ${feeder.name}'),
        subtitle: Text(
            '${o.type.label}: ${o.cause}\n${repo.subDivisionById(o.subDivisionId).name}  |  ${fmtDateTime(o.startTime)}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusChip(o.status.label, outageStatusColor(o.status)),
            if (o.isOpen && o.escalation != EscalationLevel.none) ...[
              const SizedBox(height: 4),
              StatusChip(o.escalation.label, escalationColor(o.escalation)),
            ],
          ],
        ),
      ),
    );
  }
}
