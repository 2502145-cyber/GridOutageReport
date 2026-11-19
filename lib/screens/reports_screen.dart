import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums.dart';
import '../core/formatters.dart';
import '../data/repository.dart';
import '../services/pdf_service.dart';
import '../services/report_service.dart';
import '../widgets/common.dart';
import '../widgets/picker_field.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<Repository>().currentUser!.role;
    // Company-wide annual report is for head office and admin.
    final hasAnnual = role == UserRole.headOffice || role == UserRole.admin;
    if (!hasAnnual) return const _MonthlyTab();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          TabBar(tabs: [
            Tab(text: 'Annual (all districts)'),
            Tab(text: 'Monthly (sub-division)'),
          ]),
          Expanded(child: TabBarView(children: [_AnnualTab(), _MonthlyTab()])),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- monthly

class _MonthlyTab extends StatefulWidget {
  const _MonthlyTab();

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  String? subId;
  int year = DateTime.now().year;
  int month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final rs = context.read<ReportService>();
    final subs = repo.scopedSubDivisions;
    if (subId == null || !subs.any((s) => s.id == subId)) subId = subs.first.id;
    final s = rs.monthly(subId!, year, month);
    final causes = (s.causes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PickerField<String>(
            label: 'Sub-division',
            value: subId,
            searchable: true,
            items: [for (final x in subs) PickerItem(x.id, x.name)],
            onChanged: (v) => setState(() => subId = v ?? subId),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: PickerField<int>(
                label: 'Month',
                value: month,
                items: [
                  for (var m = 1; m <= 12; m++) PickerItem(m, monthNames[m - 1]),
                ],
                onChanged: (v) => setState(() => month = v ?? month),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PickerField<int>(
                label: 'Year',
                value: year,
                items: [for (final y in rs.availableYears) PickerItem(y, '$y')],
                onChanged: (v) => setState(() => year = v ?? year),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SectionCard(
            title: '${s.name} - ${monthNames[month - 1]} $year',
            trailing: IconButton(
              tooltip: 'Open PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final pdf = context.read<PdfService>();
                final bytes = await pdf.monthlyReport(rs, subId!, year, month);
                await pdf.preview(bytes, 'monthly_${s.name}_$year-$month.pdf');
              },
            ),
            child: Column(children: [
              InfoRow('Area', repo.areaPath(subId!)),
              InfoRow('Outages', '${s.outageCount}'),
              InfoRow('Total hours lost', s.totalHours.toStringAsFixed(1)),
              InfoRow('Avg restoration', fmtMinutes(s.avgRestorationMinutes)),
              InfoRow('Consumers affected', '${s.consumersAffected}'),
              InfoRow('Time-limit compliance', fmtPercent(s.outageCompliance)),
              InfoRow('Pending outages', '${s.pendingOutages}'),
              InfoRow('Transformers installed', '${s.txInstalled}'),
              InfoRow('Transformers replaced', '${s.txReplaced}'),
              InfoRow('Transformer failures', '${s.txFailed}'),
              InfoRow('Pending jobs', '${s.pendingJobs}'),
            ]),
          ),
          SectionCard(
            title: 'Causes',
            child: BarList(
              color: Colors.orange.shade800,
              items: [for (final c in causes) BarItem(c.key, c.value.toDouble())],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- annual

class _AnnualTab extends StatefulWidget {
  const _AnnualTab();

  @override
  State<_AnnualTab> createState() => _AnnualTabState();
}

class _AnnualTabState extends State<_AnnualTab> {
  int year = DateTime.now().year;

  String _delta(num cur, num prev) {
    if (prev == 0) return cur == 0 ? '0' : 'n/a';
    final d = (cur - prev) / prev * 100;
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}%';
  }

  TableRow _row(List<String> cells, {bool head = false}) => TableRow(
        decoration: head ? BoxDecoration(color: Colors.grey.shade200) : null,
        children: [
          for (final c in cells)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(c,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: head ? FontWeight.bold : FontWeight.normal)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final rs = context.read<ReportService>();
    context.watch<Repository>();
    final a = rs.annual(year);
    final c = a.company;
    final p = a.previous;
    final causes = c.causes.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            SizedBox(
              width: 160,
              child: PickerField<int>(
                label: 'Year',
                value: year,
                items: [for (final y in rs.availableYears) PickerItem(y, '$y')],
                onChanged: (v) => setState(() => year = v ?? year),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Annual report PDF'),
              onPressed: () async {
                final pdf = context.read<PdfService>();
                final bytes = await pdf.annualReport(a);
                await pdf.preview(bytes, 'annual_report_$year.pdf');
              },
            ),
          ]),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Company-wide: $year vs ${year - 1}',
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                _row(['Measure', '$year', '${year - 1}', 'Change'], head: true),
                _row(['Total outages', '${c.outageCount}', '${p.outageCount}', _delta(c.outageCount, p.outageCount)]),
                _row(['Hours lost', c.totalHours.toStringAsFixed(0), p.totalHours.toStringAsFixed(0), _delta(c.totalHours, p.totalHours)]),
                _row(['Avg restoration', fmtMinutes(c.avgRestorationMinutes), fmtMinutes(p.avgRestorationMinutes), _delta(c.avgRestorationMinutes, p.avgRestorationMinutes)]),
                _row(['Outage compliance', fmtPercent(c.outageCompliance), fmtPercent(p.outageCompliance), '-']),
                _row(['Transformers installed', '${c.txInstalled}', '${p.txInstalled}', _delta(c.txInstalled, p.txInstalled)]),
                _row(['Transformers replaced', '${c.txReplaced}', '${p.txReplaced}', _delta(c.txReplaced, p.txReplaced)]),
                _row(['Transformer failures', '${c.txFailed}', '${p.txFailed}', _delta(c.txFailed, p.txFailed)]),
                _row(['Failure rate', fmtPercent(c.failureRate), fmtPercent(p.failureRate), '-']),
                _row(['Installation compliance', fmtPercent(c.jobCompliance), fmtPercent(p.jobCompliance), '-']),
              ],
            ),
          ),
          SectionCard(
            title: 'Causes breakdown',
            child: BarList(
              color: Colors.orange.shade800,
              items: [for (final e in causes) BarItem(e.key, e.value.toDouble())],
            ),
          ),
          SectionCard(
            title: 'Outages by type',
            child: BarList(items: [
              for (final t in OutageType.values)
                BarItem(t.label, (c.byType[t] ?? 0).toDouble()),
            ]),
          ),
          SectionCard(
            title: 'District performance',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('District')),
                  DataColumn(label: Text('Outages'), numeric: true),
                  DataColumn(label: Text('Hours lost'), numeric: true),
                  DataColumn(label: Text('Avg restore')),
                  DataColumn(label: Text('Compliance')),
                  DataColumn(label: Text('Installed'), numeric: true),
                  DataColumn(label: Text('Replaced'), numeric: true),
                  DataColumn(label: Text('Failures'), numeric: true),
                ],
                rows: [
                  for (final d in a.districts)
                    DataRow(cells: [
                      DataCell(Text(d.name)),
                      DataCell(Text('${d.outageCount}')),
                      DataCell(Text(d.totalHours.toStringAsFixed(0))),
                      DataCell(Text(fmtMinutes(d.avgRestorationMinutes))),
                      DataCell(Text(fmtPercent(d.outageCompliance))),
                      DataCell(Text('${d.txInstalled}')),
                      DataCell(Text('${d.txReplaced}')),
                      DataCell(Text('${d.txFailed}')),
                    ]),
                ],
              ),
            ),
          ),
          SectionCard(
            title: 'Best performing sub-divisions',
            child: BarList(color: Colors.green.shade700, items: [
              for (final s in a.best)
                BarItem(s.name, s.outageCompliance * 100, fmtPercent(s.outageCompliance)),
            ]),
          ),
          SectionCard(
            title: 'Worst performing sub-divisions',
            child: BarList(color: Colors.red.shade700, items: [
              for (final s in a.worst)
                BarItem(s.name, s.outageCompliance * 100, fmtPercent(s.outageCompliance)),
            ]),
          ),
        ],
      ),
    );
  }
}
