import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/enums.dart';
import '../core/formatters.dart';
import '../data/repository.dart';
import '../models/install_job.dart';
import '../models/outage.dart';
import 'report_service.dart';

/// Builds the standard report PDFs. Field layout mirrors the mandatory fields
/// in the app's forms; align the wording with the official NEPRA / IESCO forms
/// once you have them.
class PdfService {
  final Repository repo;
  PdfService(this.repo);

  static const _company = 'Distribution Company - Grid Report Manager';

  // ------------------------------------------------------------- building blocks

  pw.Widget _header(String title, String subtitle) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_company,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11)),
          pw.Divider(),
        ],
      );

  pw.Widget _footer(pw.Context c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Generated ${fmtDateTime(DateTime.now())}  |  Page ${c.pageNumber}/${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      );

  pw.Widget _kv(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(5),
        },
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(r[0],
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10)),
              ),
            ]),
        ],
      );

  pw.Widget _grid(List<String> head, List<List<String>> rows) {
    pw.Widget cell(String t, {bool bold = false, PdfColor? bg}) => pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(children: [
          for (final h in head) cell(h, bold: true, bg: PdfColors.grey300),
        ]),
        for (final r in rows) pw.TableRow(children: [for (final c in r) cell(c)]),
      ],
    );
  }

  pw.Widget _h2(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  // ------------------------------------------------------------ per-record forms

  Future<Uint8List> outageReport(Outage o) async {
    final feeder = repo.feederById(o.feederId);
    final now = DateTime.now();
    final dur = o.duration(now);
    final limit = repo.rules.restorationLimitFor(o.type);
    final within = dur.inMinutes <= limit;
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (c) => [
        _header('Outage / Interruption Report', 'Report No. ${o.id}'),
        _kv([
          ['Area', repo.areaPath(o.subDivisionId)],
          ['Feeder', feeder.name],
          ['Outage type', o.type.label],
          ['Reported cause', o.cause],
          ['Description', o.description],
          ['Start time', fmtDateTime(o.startTime)],
          ['Restoration time', o.endTime == null ? 'Not yet restored' : fmtDateTime(o.endTime)],
          ['Total duration', fmtDuration(dur)],
          ['Consumers affected', '${o.consumersAffected}'],
          ['Crew', o.crew ?? '-'],
          ['Cause found', o.causeFound ?? '-'],
          ['Action taken', o.actionTaken ?? '-'],
          ['Reported by', repo.userById(o.reportedBy)?.name ?? o.reportedBy],
          ['Status', o.status.label],
          ['Escalation', o.escalation.label],
          [
            'Time-limit compliance',
            '${within ? 'WITHIN' : 'EXCEEDED'} the configured limit of ${fmtDuration(Duration(minutes: limit))}'
          ],
        ]),
        _h2('Timeline'),
        _grid(['Time', 'Event', 'By'], [
          for (final e in o.timeline) [fmtDateTime(e.time), e.text, e.by],
        ]),
      ],
    ));
    return doc.save();
  }

  Future<Uint8List> installReport(InstallJob j) async {
    final doc = pw.Document();
    final limit = repo.rules.installLimitFor(j.reason);
    final end = j.completedAt ?? DateTime.now();
    final took = end.difference(j.createdAt);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (c) => [
        _header('Transformer ${j.isComplete ? 'Completion' : 'Installation Progress'} Report',
            'Job No. ${j.id}'),
        _kv([
          ['Area', repo.areaPath(j.subDivisionId)],
          ['Feeder', repo.feederById(j.feederId).name],
          ['Transformer ID', j.transformerCode],
          ['Capacity', '${j.kva} kVA'],
          ['Location', j.location],
          ['Reason', j.reason.label],
          ['Current stage', j.stage.label],
          ['Requested', fmtDateTime(j.createdAt)],
          ['Commissioned', fmtDateTime(j.completedAt)],
          ['Elapsed', fmtDuration(took)],
          [
            'Time-limit compliance',
            '${took <= limit ? 'WITHIN' : 'EXCEEDED'} the configured limit of ${fmtDuration(limit)}'
          ],
        ]),
        _h2('Stage log'),
        _grid(['Stage', 'Time', 'Officer', 'Notes', 'Attachments'], [
          for (final r in j.records)
            [
              r.stage.label,
              fmtDateTime(r.time),
              r.officer,
              r.notes,
              r.attachments.isEmpty ? '-' : r.attachments.join(', '),
            ],
        ]),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------- monthly & annual

  Future<Uint8List> monthlyReport(
      ReportService rs, String subDivisionId, int year, int month) async {
    final s = rs.monthly(subDivisionId, year, month);
    final outs = rs.outagesFor(subDivisionId, year, month);
    final jobs = rs.jobsFor(subDivisionId, year, month);
    final now = DateTime.now();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (c) => [
        _header('Monthly Sub-Division Report',
            '${s.name} - ${monthNames[month - 1]} $year'),
        _kv([
          ['Area', repo.areaPath(subDivisionId)],
          ['Outages', '${s.outageCount}'],
          ['Total hours lost', s.totalHours.toStringAsFixed(1)],
          ['Average restoration time', fmtMinutes(s.avgRestorationMinutes)],
          ['Consumers affected (sum)', '${s.consumersAffected}'],
          ['Time-limit compliance', fmtPercent(s.outageCompliance)],
          ['Pending outages', '${s.pendingOutages}'],
          ['Transformers installed', '${s.txInstalled}'],
          ['Transformers replaced', '${s.txReplaced}'],
          ['Transformer failures', '${s.txFailed}'],
          ['Pending installation jobs', '${s.pendingJobs}'],
        ]),
        _h2('Outages'),
        outs.isEmpty
            ? pw.Text('None in this period.')
            : _grid(['ID', 'Type', 'Cause', 'Start', 'Duration', 'Status'], [
                for (final o in outs)
                  [
                    o.id,
                    o.type.label,
                    o.cause,
                    fmtDateTime(o.startTime),
                    fmtDuration(o.duration(now)),
                    o.status.label,
                  ],
              ]),
        _h2('Installation jobs'),
        jobs.isEmpty
            ? pw.Text('None in this period.')
            : _grid(['ID', 'Transformer', 'kVA', 'Reason', 'Stage'], [
                for (final j in jobs)
                  [j.id, j.transformerCode, '${j.kva}', j.reason.label, j.stage.label],
              ]),
      ],
    ));
    return doc.save();
  }

  Future<Uint8List> annualReport(AnnualReport a) async {
    final c = a.company;
    final p = a.previous;
    String delta(num cur, num prev) {
      if (prev == 0) return cur == 0 ? '0' : 'n/a';
      final d = (cur - prev) / prev * 100;
      return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}%';
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (ctx) => [
        _header('Annual Performance Report ${a.year}', 'All districts and company-wide'),
        _h2('Company-wide summary (vs ${a.year - 1})'),
        _grid(['Measure', '${a.year}', '${a.year - 1}', 'Change'], [
          ['Total outages', '${c.outageCount}', '${p.outageCount}', delta(c.outageCount, p.outageCount)],
          ['Total hours lost', c.totalHours.toStringAsFixed(0), p.totalHours.toStringAsFixed(0), delta(c.totalHours, p.totalHours)],
          ['Avg restoration time', fmtMinutes(c.avgRestorationMinutes), fmtMinutes(p.avgRestorationMinutes), delta(c.avgRestorationMinutes, p.avgRestorationMinutes)],
          ['Outage time-limit compliance', fmtPercent(c.outageCompliance), fmtPercent(p.outageCompliance), '-'],
          ['Transformers installed', '${c.txInstalled}', '${p.txInstalled}', delta(c.txInstalled, p.txInstalled)],
          ['Transformers replaced', '${c.txReplaced}', '${p.txReplaced}', delta(c.txReplaced, p.txReplaced)],
          ['Transformer failures', '${c.txFailed}', '${p.txFailed}', delta(c.txFailed, p.txFailed)],
          ['Failure rate (of register)', fmtPercent(c.failureRate), fmtPercent(p.failureRate), '-'],
          ['Installation compliance', fmtPercent(c.jobCompliance), fmtPercent(p.jobCompliance), '-'],
        ]),
        _h2('Causes breakdown'),
        _grid(['Cause', 'Outages', 'Share'], [
          for (final e in (c.causes.entries.toList()
            ..sort((x, y) => y.value.compareTo(x.value))))
            [e.key, '${e.value}', fmtPercent(c.outageCount == 0 ? 0 : e.value / c.outageCount)],
        ]),
        _h2('By outage type'),
        _grid(['Type', 'Outages'], [
          for (final t in OutageType.values) [t.label, '${c.byType[t] ?? 0}'],
        ]),
        _h2('District performance'),
        _grid(
          ['District', 'Outages', 'Hours lost', 'Avg restore', 'Compliance', 'Installed', 'Replaced', 'Failures'],
          [
            for (final d in a.districts)
              [
                d.name,
                '${d.outageCount}',
                d.totalHours.toStringAsFixed(0),
                fmtMinutes(d.avgRestorationMinutes),
                fmtPercent(d.outageCompliance),
                '${d.txInstalled}',
                '${d.txReplaced}',
                '${d.txFailed}',
              ],
          ],
        ),
        _h2('Best performing sub-divisions'),
        _grid(['Sub-division', 'Compliance', 'Avg restore', 'Outages'], [
          for (final s in a.best)
            [s.name, fmtPercent(s.outageCompliance), fmtMinutes(s.avgRestorationMinutes), '${s.outageCount}'],
        ]),
        _h2('Worst performing sub-divisions'),
        _grid(['Sub-division', 'Compliance', 'Avg restore', 'Outages'], [
          for (final s in a.worst)
            [s.name, fmtPercent(s.outageCompliance), fmtMinutes(s.avgRestorationMinutes), '${s.outageCount}'],
        ]),
      ],
    ));
    return doc.save();
  }

  // ----------------------------------------------------------------- output

  Future<void> preview(Uint8List bytes, String name) =>
      Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
}
