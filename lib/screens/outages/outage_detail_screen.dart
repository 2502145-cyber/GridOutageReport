import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/formatters.dart';
import '../../data/repository.dart';
import '../../models/outage.dart';
import '../../services/pdf_service.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_field.dart';

class OutageDetailScreen extends StatelessWidget {
  final String outageId;
  const OutageDetailScreen({super.key, required this.outageId});

  void _report(BuildContext context, String? error) {
    if (error != null) showMsg(context, error, error: true);
  }

  Future<void> _pdf(BuildContext context, Outage o) async {
    final pdf = context.read<PdfService>();
    final bytes = await pdf.outageReport(o);
    await pdf.preview(bytes, '${o.id}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final o = repo.outages.firstWhere((x) => x.id == outageId);
    final feeder = repo.feederById(o.feederId);
    final now = DateTime.now();
    final dur = o.duration(now);
    final limit = repo.rules.restorationLimitFor(o.type);
    final breached = dur.inMinutes > limit;
    final canAct = repo.canManage(o.subDivisionId);
    final sdo = repo.sdoFor(o.subDivisionId);

    final bannerColor = breached ? Colors.red.shade700 : Colors.green.shade700;
    final bannerText = o.isOpen
        ? 'Open for ${fmtDuration(dur)} - limit ${fmtDuration(Duration(minutes: limit))}'
        : 'Restored in ${fmtDuration(dur)} - ${breached ? 'EXCEEDED' : 'within'} limit of ${fmtDuration(Duration(minutes: limit))}';

    return Scaffold(
      appBar: AppBar(title: Text(o.id), actions: [
        IconButton(
          tooltip: 'Standard report (PDF)',
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _pdf(context, o),
        ),
      ]),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(spacing: 8, runSpacing: 4, children: [
              StatusChip(o.status.label, outageStatusColor(o.status)),
              StatusChip(o.type.label, Colors.indigo),
              if (o.isOpen && o.escalation != EscalationLevel.none)
                StatusChip(o.escalation.label, escalationColor(o.escalation)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bannerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bannerColor.withOpacity(0.5)),
              ),
              child: Row(children: [
                Icon(breached ? Icons.warning_amber : Icons.timer_outlined,
                    color: bannerColor),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(bannerText,
                        style: TextStyle(
                            color: bannerColor, fontWeight: FontWeight.w600))),
              ]),
            ),
            SectionCard(
              title: 'Report details',
              child: Column(children: [
                InfoRow('Area', repo.areaPath(o.subDivisionId)),
                InfoRow('Feeder', feeder.name),
                InfoRow('Routed to', sdo?.name ?? 'No SDO assigned'),
                InfoRow('Reported cause', o.cause),
                InfoRow('Description', o.description),
                InfoRow('Start time', fmtDateTime(o.startTime)),
                InfoRow('Restored at',
                    o.endTime == null ? 'Not yet restored' : fmtDateTime(o.endTime)),
                InfoRow('Duration', fmtDuration(dur)),
                InfoRow('Consumers', '${o.consumersAffected}'),
                InfoRow('Reported by',
                    repo.userById(o.reportedBy)?.name ?? o.reportedBy),
                InfoRow('Crew', o.crew ?? '-'),
                InfoRow('Cause found', o.causeFound ?? '-'),
                InfoRow('Action taken', o.actionTaken ?? '-'),
              ]),
            ),
            if (canAct && o.status != OutageStatus.closed)
              SectionCard(
                title: 'Actions',
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (o.status == OutageStatus.reported ||
                      o.status == OutageStatus.assigned)
                    FilledButton.icon(
                      icon: const Icon(Icons.engineering),
                      label: Text(o.crew == null ? 'Assign crew' : 'Reassign crew'),
                      onPressed: () async {
                        final crew = await askText(context,
                            title: 'Assign crew',
                            label: 'Crew / lineman name',
                            confirm: 'Assign');
                        if (crew == null || !context.mounted) return;
                        _report(context, repo.assignOutage(o, crew));
                      },
                    ),
                  if (o.status == OutageStatus.assigned)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start work'),
                      onPressed: () => _report(context, repo.startWork(o)),
                    ),
                  if (o.isOpen)
                    FilledButton.icon(
                      icon: const Icon(Icons.power),
                      label: const Text('Mark restored'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700),
                      onPressed: () async {
                        final r = await showDialog<_RestoreResult>(
                          context: context,
                          builder: (_) => _RestoreDialog(outage: o),
                        );
                        if (r == null || !context.mounted) return;
                        _report(
                            context,
                            repo.restoreOutage(o,
                                causeFound: r.causeFound,
                                actionTaken: r.actionTaken,
                                endTime: r.end));
                      },
                    ),
                  if (o.status == OutageStatus.restored)
                    FilledButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Close outage'),
                      onPressed: () => _report(context, repo.closeOutage(o)),
                    ),
                ]),
              ),
            SectionCard(
              title: 'Timeline',
              child: Column(children: [
                for (final e in o.timeline.reversed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 10),
                    title: Text(e.text),
                    subtitle: Text('${fmtDateTime(e.time)}  |  ${e.by}'),
                  ),
              ]),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Open standard outage report (PDF)'),
              onPressed: () => _pdf(context, o),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreResult {
  final String causeFound;
  final String actionTaken;
  final DateTime end;
  _RestoreResult(this.causeFound, this.actionTaken, this.end);
}

class _RestoreDialog extends StatefulWidget {
  final Outage outage;
  const _RestoreDialog({required this.outage});

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  late final TextEditingController _cause;
  final _action = TextEditingController();
  DateTime _end = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cause = TextEditingController(text: widget.outage.cause);
  }

  @override
  void dispose() {
    _cause.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Mark restored'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _cause,
                  decoration: const InputDecoration(labelText: 'Cause found'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _action,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Action taken'),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Restoration time'),
                  child: Row(children: [
                    Expanded(child: Text(fmtDateTime(_end))),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () async {
                        final d = await pickDateTime(context, _end);
                        if (d != null) setState(() => _end = d);
                      },
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, _RestoreResult(_cause.text, _action.text, _end)),
            child: const Text('Save'),
          ),
        ],
      );
}
