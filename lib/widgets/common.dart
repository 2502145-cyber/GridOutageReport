import 'package:flutter/material.dart';
import '../core/enums.dart';

void showMsg(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
}

Color outageStatusColor(OutageStatus s) {
  switch (s) {
    case OutageStatus.reported:
      return Colors.red.shade700;
    case OutageStatus.assigned:
      return Colors.orange.shade800;
    case OutageStatus.inProgress:
      return Colors.blue.shade700;
    case OutageStatus.restored:
      return Colors.teal.shade700;
    case OutageStatus.closed:
      return Colors.grey.shade700;
  }
}

Color escalationColor(EscalationLevel e) =>
    e == EscalationLevel.se ? Colors.red.shade900 : Colors.deepOrange.shade700;

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(title, style: TextStyle(color: Colors.grey.shade700)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard(
      {super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class BarItem {
  final String label;
  final double value;
  final String? valueLabel;
  const BarItem(this.label, this.value, [this.valueLabel]);
}

/// Simple horizontal bar chart with no external dependency.
class BarList extends StatelessWidget {
  final List<BarItem> items;
  final Color color;
  const BarList({super.key, required this.items, this.color = const Color(0xFF1565C0)});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No data.');
    final maxV = items.map((e) => e.value).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(it.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 14,
                        width: maxV == 0
                            ? 2.0
                            : (c.maxWidth * it.value / maxV)
                                .clamp(2.0, c.maxWidth)
                                .toDouble(),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(it.valueLabel ?? it.value.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}

/// Centers content and caps its width so screens look right on wide displays.
class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String confirm = 'OK',
  bool multiline = false,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(confirm)),
      ],
    ),
  );
}
