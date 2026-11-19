import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/formatters.dart';
import '../../data/repository.dart';
import '../../models/install_job.dart';
import '../../services/pdf_service.dart';
import '../../widgets/common.dart';

class InstallDetailScreen extends StatelessWidget {
  final String jobId;
  const InstallDetailScreen({super.key, required this.jobId});

  Future<void> _pdf(BuildContext context, InstallJob j) async {
    final pdf = context.read<PdfService>();
    final bytes = await pdf.installReport(j);
    await pdf.preview(bytes, '${j.id}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final j = repo.jobs.firstWhere((x) => x.id == jobId);
    final limit = repo.rules.installLimitFor(j.reason);
    final took = (j.completedAt ?? DateTime.now()).difference(j.createdAt);
    final breached = took > limit;
    final color = breached ? Colors.red.shade700 : Colors.green.shade700;
    final canAct = repo.canManage(j.subDivisionId) && !j.isComplete;
    final next = j.stage.next;

    return Scaffold(
      appBar: AppBar(title: Text(j.id), actions: [
        IconButton(
          tooltip: 'Report (PDF)',
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _pdf(context, j),
        ),
      ]),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(spacing: 8, children: [
              StatusChip(j.stage.label,
                  j.isComplete ? Colors.green.shade700 : Colors.blue.shade700),
              StatusChip(j.reason.label, Colors.indigo),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Row(children: [
                Icon(breached ? Icons.warning_amber : Icons.timer_outlined,
                    color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${j.isComplete ? 'Completed in' : 'Open for'} ${fmtDuration(took)} - '
                    '${breached ? 'EXCEEDED' : 'within'} limit of ${fmtDuration(limit)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            SectionCard(
              title: 'Job details',
              child: Column(children: [
                InfoRow('Transformer', j.transformerCode),
                InfoRow('Capacity', '${j.kva} kVA'),
                InfoRow('Location', j.location),
                InfoRow('Feeder', repo.feederById(j.feederId).name),
                InfoRow('Area', repo.areaPath(j.subDivisionId)),
                InfoRow('Requested', fmtDateTime(j.createdAt)),
                InfoRow('Commissioned', fmtDateTime(j.completedAt)),
                InfoRow('Routed to', repo.sdoFor(j.subDivisionId)?.name ?? 'No SDO assigned'),
              ]),
            ),
            SectionCard(
              title: 'Stages',
              child: Column(children: [
                for (final s in InstallStage.values) _StageRow(job: j, stage: s),
              ]),
            ),
            if (canAct && next != null)
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text('Complete stage: ${next.label}'),
                onPressed: () async {
                  final r = await showDialog<_StageResult>(
                    context: context,
                    builder: (_) => _StageDialog(stage: next),
                  );
                  if (r == null || !context.mounted) return;
                  final err = repo.advanceJob(j,
                      notes: r.notes, attachments: r.attachments);
                  if (err != null) showMsg(context, err, error: true);
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(j.isComplete
                  ? 'Open completion report (PDF)'
                  : 'Open progress report (PDF)'),
              onPressed: () => _pdf(context, j),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final InstallJob job;
  final InstallStage stage;
  const _StageRow({required this.job, required this.stage});

  @override
  Widget build(BuildContext context) {
    final rec = job.recordFor(stage);
    final isNext = rec == null && job.stage.next == stage;
    final icon = rec != null
        ? Icon(Icons.check_circle, color: Colors.green.shade700)
        : Icon(isNext ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: isNext ? Colors.blue.shade700 : Colors.grey);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon,
      title: Text(stage.label,
          style: TextStyle(
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
      subtitle: rec == null
          ? Text(isNext
              ? 'Next${stage.requiresPhoto ? ' (photo required)' : ''}'
              : 'Pending')
          : Text(
              '${fmtDateTime(rec.time)}  |  ${rec.officer}\n${rec.notes}'
              '${rec.attachments.isEmpty ? '' : '\nAttachments: ${rec.attachments.join(', ')}'}'),
      isThreeLine: rec != null,
    );
  }
}

class _StageResult {
  final String notes;
  final List<String> attachments;
  _StageResult(this.notes, this.attachments);
}

class _StageDialog extends StatefulWidget {
  final InstallStage stage;
  const _StageDialog({required this.stage});

  @override
  State<_StageDialog> createState() => _StageDialogState();
}

class _StageDialogState extends State<_StageDialog> {
  final _notes = TextEditingController();
  final List<String> _photos = [];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Complete: ${widget.stage.label}'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Notes (required)'),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 6, children: [
                  for (final p in _photos)
                    Chip(
                      label: Text(p),
                      onDeleted: () => setState(() => _photos.remove(p)),
                    ),
                ]),
                TextButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(widget.stage.requiresPhoto
                      ? 'Attach photo (required)'
                      : 'Attach photo (optional)'),
                  onPressed: () => setState(
                      () => _photos.add('photo_${_photos.length + 1}.jpg')),
                ),
                Text(
                  'Placeholder: this build records a file name only. Add the '
                  'image_picker package to capture real photos.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
            onPressed: () =>
                Navigator.pop(context, _StageResult(_notes.text, _photos)),
            child: const Text('Save stage'),
          ),
        ],
      );
}
