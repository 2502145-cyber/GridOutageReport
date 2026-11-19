import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/formatters.dart';
import '../../data/repository.dart';
import '../../models/install_job.dart';
import '../../models/transformer.dart';
import '../../widgets/common.dart';
import 'install_detail_screen.dart';
import 'install_form_screen.dart';

class TransformersScreen extends StatelessWidget {
  const TransformersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('New job'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InstallFormScreen())),
        ),
        body: Column(
          children: [
            const TabBar(tabs: [
              Tab(text: 'Installation jobs'),
              Tab(text: 'Transformer register'),
            ]),
            const Expanded(
              child: TabBarView(children: [_JobsTab(), _RegisterTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  int filter = 0; // 0 open, 1 completed, 2 all

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final jobs = repo.visibleJobs.where((j) {
      if (filter == 0) return !j.isComplete;
      if (filter == 1) return j.isComplete;
      return true;
    }).toList();

    return PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (final e in const ['Open', 'Completed', 'All'].asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => setState(() => filter = e.key),
                  ),
                ),
              const Spacer(),
              Text('${jobs.length} job(s)',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: jobs.isEmpty
                ? const Center(child: Text('No jobs.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: jobs.length,
                    itemBuilder: (_, i) => _JobTile(job: jobs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final InstallJob job;
  const _JobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final progress =
        (InstallStage.values.indexOf(job.stage) + 1) / InstallStage.values.length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => InstallDetailScreen(jobId: job.id))),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.12),
          child: Icon(
              job.isComplete ? Icons.check_circle_outline : Icons.construction,
              color: job.isComplete ? Colors.green.shade700 : Colors.blue.shade700),
        ),
        title: Text('${job.id}  -  ${job.transformerCode} (${job.kva} kVA)'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${job.reason.label}  |  ${repo.subDivisionById(job.subDivisionId).name}'),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
        trailing: StatusChip(job.stage.label,
            job.isComplete ? Colors.green.shade700 : Colors.blue.shade700),
      ),
    );
  }
}

class _RegisterTab extends StatefulWidget {
  const _RegisterTab();

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  String query = '';

  Color _statusColor(TransformerStatus s) {
    switch (s) {
      case TransformerStatus.active:
        return Colors.green.shade700;
      case TransformerStatus.failed:
        return Colors.red.shade700;
      case TransformerStatus.underMaintenance:
        return Colors.orange.shade800;
      case TransformerStatus.decommissioned:
        return Colors.grey.shade700;
    }
  }

  void _showHistory(BuildContext context, Transformer t) {
    final repo = context.read<Repository>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.code, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            InfoRow('Capacity', '${t.kva} kVA'),
            InfoRow('Status', t.status.label),
            InfoRow('Location', t.location),
            InfoRow('Feeder', repo.feederById(t.feederId).name),
            InfoRow('Area', repo.areaPath(repo.feederById(t.feederId).subDivisionId)),
            InfoRow('GPS', '${t.lat.toStringAsFixed(5)}, ${t.lng.toStringAsFixed(5)}'),
            InfoRow('Installed', fmtDate(t.installDate)),
            const Divider(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            for (final h in t.history.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, size: 18),
                title: Text(h),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final q = query.trim().toLowerCase();
    final list = repo.visibleTransformers.where((t) {
      if (q.isEmpty) return true;
      return '${t.code} ${t.location} ${repo.feederById(t.feederId).name}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by ID, location or feeder',
                isDense: true,
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    onTap: () => _showHistory(context, t),
                    leading: const CircleAvatar(child: Icon(Icons.electrical_services)),
                    title: Text('${t.code}  -  ${t.kva} kVA'),
                    subtitle: Text(
                        '${t.location}\nInstalled ${fmtDate(t.installDate)}'),
                    isThreeLine: true,
                    trailing: StatusChip(t.status.label, _statusColor(t.status)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
