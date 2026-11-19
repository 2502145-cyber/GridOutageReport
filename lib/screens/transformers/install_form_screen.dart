import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums.dart';
import '../../data/repository.dart';
import '../../models/transformer.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_field.dart';

class InstallFormScreen extends StatefulWidget {
  const InstallFormScreen({super.key});

  @override
  State<InstallFormScreen> createState() => _InstallFormScreenState();
}

class _InstallFormScreenState extends State<InstallFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kva = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  String? _feederId;
  String? _existingCode;
  String? _feederError;
  String? _existingError;
  InstallReason _reason = InstallReason.newConnectionLoad;

  bool get _needsExisting => _reason != InstallReason.newConnectionLoad;

  @override
  void dispose() {
    _kva.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final repo = context.read<Repository>();
    setState(() {
      _feederError = _feederId == null ? 'Select a feeder' : null;
      _existingError = (_needsExisting && _existingCode == null)
          ? 'Select the transformer'
          : null;
    });
    if (!_formKey.currentState!.validate() ||
        _feederId == null ||
        (_needsExisting && _existingCode == null)) {
      return;
    }
    final j = repo.createJob(
      feederId: _feederId!,
      reason: _reason,
      kva: int.parse(_kva.text.trim()),
      location: _location.text,
      requestNotes: _notes.text,
      existingCode: _needsExisting ? _existingCode : null,
    );
    final sdo = repo.sdoFor(j.subDivisionId);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(sdo == null
          ? '${j.id} created (no SDO assigned to this area).'
          : '${j.id} created and routed to ${sdo.name}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final feeders = repo.scopedFeeders;
    final List<Transformer> onFeeder = _feederId == null
        ? []
        : repo.transformers.where((t) => t.feederId == _feederId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New transformer job')),
      body: PageBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PickerField<InstallReason>(
                label: 'Reason',
                value: _reason,
                items: [
                  for (final r in InstallReason.values) PickerItem(r, r.label),
                ],
                onChanged: (v) => setState(() {
                  _reason = v ?? _reason;
                  _existingCode = null;
                  _existingError = null;
                }),
              ),
              const SizedBox(height: 16),
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
                  _existingCode = null;
                }),
              ),
              if (_needsExisting) ...[
                const SizedBox(height: 16),
                PickerField<String>(
                  label: 'Existing transformer',
                  value: _existingCode,
                  errorText: _existingError,
                  items: [
                    for (final t in onFeeder)
                      PickerItem(t.code, '${t.code}  (${t.kva} kVA)'),
                  ],
                  onChanged: (v) => setState(() {
                    _existingCode = v;
                    _existingError = null;
                    if (v != null) {
                      final t = repo.transformers.firstWhere((x) => x.code == v);
                      _kva.text = '${t.kva}';
                      _location.text = t.location;
                    }
                  }),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _kva,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Capacity (kVA)', hintText: 'e.g. 100'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a capacity above zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                    labelText: 'Location', hintText: 'Pole / street / landmark'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Location is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Request notes'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Request notes are required'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Create job'),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
