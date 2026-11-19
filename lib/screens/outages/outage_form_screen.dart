import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../core/formatters.dart';
import '../../data/repository.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_field.dart';

class OutageFormScreen extends StatefulWidget {
  const OutageFormScreen({super.key});

  @override
  State<OutageFormScreen> createState() => _OutageFormScreenState();
}

class _OutageFormScreenState extends State<OutageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cause = TextEditingController();
  final _desc = TextEditingController();
  final _consumers = TextEditingController();
  String? _feederId;
  String? _feederError;
  OutageType _type = OutageType.fault;
  DateTime _start = DateTime.now();

  @override
  void dispose() {
    _cause.dispose();
    _desc.dispose();
    _consumers.dispose();
    super.dispose();
  }

  void _submit() {
    final repo = context.read<Repository>();
    setState(() => _feederError = _feederId == null ? 'Select a feeder' : null);
    if (!_formKey.currentState!.validate() || _feederId == null) return;
    if (_start.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      showMsg(context, 'Start time cannot be in the future.', error: true);
      return;
    }
    final o = repo.reportOutage(
      feederId: _feederId!,
      type: _type,
      cause: _cause.text,
      description: _desc.text,
      startTime: _start,
      consumersAffected: int.parse(_consumers.text.trim()),
    );
    final sdo = repo.sdoFor(o.subDivisionId);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(sdo == null
          ? '${o.id} reported, but no SDO is assigned to this area.'
          : '${o.id} reported and routed to ${sdo.name}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final feeders = repo.scopedFeeders;
    final sdo = _feederId == null
        ? null
        : repo.sdoFor(repo.feederById(_feederId!).subDivisionId);

    return Scaffold(
      appBar: AppBar(title: const Text('Report outage')),
      body: PageBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PickerField<String>(
                label: 'Feeder / area',
                value: _feederId,
                searchable: true,
                errorText: _feederError,
                items: [
                  for (final f in feeders)
                    PickerItem(f.id,
                        '${f.name}  (${repo.subDivisionById(f.subDivisionId).name})'),
                ],
                onChanged: (v) => setState(() {
                  _feederId = v;
                  _feederError = null;
                  if (v != null) {
                    _consumers.text = '${repo.feederById(v).consumers}';
                  }
                }),
              ),
              if (_feederId != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.alt_route),
                    title: Text(sdo == null
                        ? 'No SDO assigned - admin will be alerted'
                        : 'Will be routed to ${sdo.name}'),
                    subtitle: Text(
                        repo.areaPath(repo.feederById(_feederId!).subDivisionId)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PickerField<OutageType>(
                label: 'Outage type',
                value: _type,
                items: [
                  for (final t in OutageType.values) PickerItem(t, t.label),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cause,
                decoration: const InputDecoration(
                    labelText: 'Cause (as reported)',
                    hintText: 'e.g. Conductor snapping, tree contact'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Cause is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _consumers,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Consumers affected'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a number above zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Outage start time'),
                child: Row(
                  children: [
                    Expanded(child: Text(fmtDateTime(_start))),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Change'),
                      onPressed: () async {
                        final d = await pickDateTime(context, _start);
                        if (d != null) setState(() => _start = d);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Submit report'),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
