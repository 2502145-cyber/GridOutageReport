import 'package:flutter/material.dart';

class PickerItem<T> {
  final T value;
  final String label;
  const PickerItem(this.value, this.label);
}

/// Full-width dropdown built on DropdownMenu (stable across Flutter versions).
/// Set [searchable] for long lists such as feeders.
class PickerField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<PickerItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? errorText;
  final bool searchable;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
    this.searchable = false,
  });

  @override
  Widget build(BuildContext context) => DropdownMenu<T>(
        key: ValueKey('$label-$value-${items.length}'),
        label: Text(label),
        initialSelection: value,
        expandedInsets: EdgeInsets.zero,
        errorText: errorText,
        enableFilter: searchable,
        requestFocusOnTap: searchable ? true : null,
        menuHeight: 320,
        onSelected: onChanged,
        dropdownMenuEntries: [
          for (final i in items)
            DropdownMenuEntry<T>(value: i.value, label: i.label),
        ],
      );
}

/// Date picker followed by time picker. Returns null if cancelled.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
