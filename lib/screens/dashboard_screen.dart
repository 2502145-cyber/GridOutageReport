import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums.dart';
import '../core/formatters.dart';
import '../data/repository.dart';
import '../services/report_service.dart';
import '../widgets/common.dart';
import 'outages/outage_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final rs = context.read<ReportService>();
    final user = repo.currentUser!;
    final year = DateTime.now().year;

    final outages = repo.visibleOutages;
    final open = outages.where((o) => o.isOpen).toList()
      ..sort((a, b) {
        final e = b.escalation.index.compareTo(a.escalation.index);
        return e != 0 ? e : a.startTime.compareTo(b.startTime);
      });
    final escalated =
        open.where((o) => o.escalation != EscalationLevel.none).length;
    final pendingJobs = repo.visibleJobs.where((j) => !j.isComplete).length;
    final isReporter = user.role == UserRole.reporter;

    final stats = rs.compute(
      id: 'scope',
      name: 'Scope',
      year: year,
      include: (sid) => repo.inScope(user, sid),
    );
    final topCauses = (stats.causes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    final showDistricts = user.role == UserRole.headOffice ||
        user.role == UserRole.admin ||
        user.role == UserRole.se;
    final districts = showDistricts ? rs.annual(year).districts : <UnitStats>[];

    Widget kpi(Widget w) => SizedBox(width: 270, child: w);

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${user.name}',
              style: Theme.of(context).textTheme.headlineSmall),
          Text(_scopeText(repo, user.role, user.id),
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              kpi(KpiCard(
                  title: 'Open outages',
                  value: '${open.length}',
                  icon: Icons.flash_off,
                  color: Colors.red.shade700)),
              kpi(KpiCard(
                  title: 'Escalated',
                  value: '$escalated',
                  icon: Icons.trending_up,
                  color: Colors.deepOrange.shade700,
                  subtitle: 'Past XEN / SE time limits')),
              kpi(KpiCard(
                  title: 'Pending installation jobs',
                  value: '$pendingJobs',
                  icon: Icons.electrical_services,
                  color: Colors.blue.shade700)),
              if (!isReporter)
                kpi(KpiCard(
                    title: 'Time-limit compliance ($year)',
                    value: fmtPercent(stats.outageCompliance),
                    icon: Icons.verified_outlined,
                    color: Colors.teal.shade700,
                    subtitle: '${stats.outageCount} outages in scope')),
            ],
          ),
          const SizedBox(height: 8),
          if (user.role.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.rule),
                label: const Text('Run escalation check now'),
                onPressed: () {
                  final n = repo.runEscalations();
                  showMsg(context,
                      n == 0 ? 'No new escalations.' : '$n outage(s) escalated.');
                },
              ),
            ),
          SectionCard(
            title: 'Open outages needing attention',
            child: open.isEmpty
                ? const Text('No open outages.')
                : Column(
                    children: [
                      for (final o in open.take(6)) OutageTile(outage: o),
                    ],
                  ),
          ),
          if (!isReporter) ...[
            SectionCard(
              title: 'Outages by type ($year)',
              child: BarList(items: [
                for (final t in OutageType.values)
                  BarItem(t.label, (stats.byType[t] ?? 0).toDouble()),
              ]),
            ),
            SectionCard(
              title: 'Top causes ($year)',
              child: BarList(color: Colors.orange.shade800, items: [
                for (final c in topCauses) BarItem(c.key, c.value.toDouble()),
              ]),
            ),
          ],
          if (showDistricts)
            SectionCard(
              title: 'Hours lost by district ($year)',
              child: BarList(color: Colors.red.shade700, items: [
                for (final d in districts)
                  BarItem(d.name, d.totalHours, '${d.totalHours.toStringAsFixed(0)} h'),
              ]),
            ),
        ],
      ),
    );
  }

  String _scopeText(Repository repo, UserRole role, String userId) {
    final u = repo.userById(userId)!;
    switch (role) {
      case UserRole.sdo:
        return 'Sub-division: ${repo.subDivisionById(u.subDivisionId!).name}';
      case UserRole.xen:
        return 'Division: ${repo.divisionById(u.divisionId!).name}';
      case UserRole.se:
        return 'Circle: ${repo.circleById(u.circleId!).name}';
      case UserRole.reporter:
        return 'Showing the reports you have logged';
      case UserRole.headOffice:
      case UserRole.admin:
        return 'Company-wide view';
    }
  }
}
