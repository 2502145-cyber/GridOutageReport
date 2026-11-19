const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${_two(d.day)} ${_months[d.month - 1]} ${d.year}';

String fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String fmtDateTime(DateTime? d) =>
    d == null ? '-' : '${fmtDate(d)}, ${fmtTime(d)}';

String fmtDuration(Duration d) {
  if (d.inMinutes < 1) return '< 1 min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  if (h >= 48) {
    final days = d.inDays;
    final rh = h % 24;
    return '${days}d ${rh}h';
  }
  return '${h}h ${_two(m)}m';
}

String fmtMinutes(double minutes) =>
    fmtDuration(Duration(minutes: minutes.round()));

String fmtPercent(double fraction) =>
    '${(fraction * 100).toStringAsFixed(1)}%';
