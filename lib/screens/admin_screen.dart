import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/compliance_rules.dart';
import '../core/enums.dart';
import '../data/repository.dart';
import '../models/app_user.dart';
import '../widgets/common.dart';
import '../widgets/picker_field.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(tabs: [
            Tab(text: 'Area tree'),
            Tab(text: 'Users'),
            Tab(text: 'Time limits'),
          ]),
          Expanded(
            child: TabBarView(children: [_AreaTab(), _UsersTab(), _RulesTab()]),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- area tree

class _AreaTab extends StatelessWidget {
  const _AreaTab();

  Future<void> _addCircle(BuildContext context) async {
    final repo = context.read<Repository>();
    final name = await askText(context,
        title: 'Add circle', label: 'Circle name', confirm: 'Add');
    if (name == null || !context.mounted) return;
    final err = repo.addCircle(name);
    if (err != null) showMsg(context, err, error: true);
  }

  Future<void> _addDivision(BuildContext context, String circleId) async {
    final repo = context.read<Repository>();
    final name = await askText(context,
        title: 'Add division', label: 'Division name', confirm: 'Add');
    if (name == null || !context.mounted) return;
    final err = repo.addDivision(name, circleId);
    if (err != null) showMsg(context, err, error: true);
  }

  Future<void> _addSub(BuildContext context, String divisionId) async {
    final repo = context.read<Repository>();
    final name = await askText(context,
        title: 'Add sub-division', label: 'Sub-division name', confirm: 'Add');
    if (name == null || !context.mounted) return;
    final err = repo.addSubDivision(name, divisionId);
    if (err != null) showMsg(context, err, error: true);
  }

  Future<void> _addFeeder(BuildContext context, String subId) async {
    final repo = context.read<Repository>();
    final r = await showDialog<(String, int)>(
        context: context, builder: (_) => const _FeederDialog());
    if (r == null || !context.mounted) return;
    final err = repo.addFeeder(r.$1, subId, r.$2);
    if (err != null) showMsg(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final unassigned =
        repo.subDivisions.where((s) => s.sdoUserId == null).length;

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text(
                unassigned == 0
                    ? 'All sub-divisions have an SDO.'
                    : '$unassigned sub-division(s) have no SDO - reports there cannot be routed.',
                style: TextStyle(
                    color: unassigned == 0
                        ? Colors.green.shade700
                        : Colors.red.shade700),
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: const Text('Circle'),
              onPressed: () => _addCircle(context),
            ),
          ]),
          const SizedBox(height: 8),
          for (final c in repo.circles)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.public),
                title: Text('${c.name} (circle)'),
                childrenPadding: const EdgeInsets.only(left: 12),
                children: [
                  for (final d in repo.divisions.where((d) => d.circleId == c.id))
                    ExpansionTile(
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text(d.name),
                      children: [
                        for (final s in repo.subDivisions
                            .where((s) => s.divisionId == d.id))
                          _SubTile(
                            subId: s.id,
                            onAddFeeder: () => _addFeeder(context, s.id),
                          ),
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Add sub-division'),
                          onTap: () => _addSub(context, d.id),
                        ),
                      ],
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add division'),
                    onTap: () => _addDivision(context, c.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final String subId;
  final VoidCallback onAddFeeder;
  const _SubTile({required this.subId, required this.onAddFeeder});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final s = repo.subDivisionById(subId);
    final sdos = repo.users.where((u) => u.role == UserRole.sdo).toList();
    final feeders = repo.feeders.where((f) => f.subDivisionId == s.id).toList();

    return ExpansionTile(
      leading: const Icon(Icons.location_city_outlined),
      title: Text(s.name),
      subtitle: Text(
        s.sdoUserId == null
            ? 'No SDO assigned'
            : 'SDO: ${repo.userById(s.sdoUserId)?.name ?? '?'}',
        style: TextStyle(color: s.sdoUserId == null ? Colors.red.shade700 : null),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: PickerField<String>(
            label: 'Assigned SDO',
            value: s.sdoUserId,
            items: [for (final u in sdos) PickerItem(u.id, u.name)],
            onChanged: (v) => repo.assignSdo(s.id, v),
          ),
        ),
        for (final f in feeders)
          ListTile(
            dense: true,
            leading: const Icon(Icons.cable),
            title: Text(f.name),
            subtitle: Text('${f.consumers} consumers'),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add),
          title: const Text('Add feeder'),
          onTap: onAddFeeder,
        ),
      ],
    );
  }
}

class _FeederDialog extends StatefulWidget {
  const _FeederDialog();

  @override
  State<_FeederDialog> createState() => _FeederDialogState();
}

class _FeederDialogState extends State<_FeederDialog> {
  final _name = TextEditingController();
  final _consumers = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _consumers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add feeder'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Feeder name')),
          const SizedBox(height: 12),
          TextField(
              controller: _consumers,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consumers')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context,
                (_name.text, int.tryParse(_consumers.text.trim()) ?? 0)),
            child: const Text('Add'),
          ),
        ],
      );
}

// --------------------------------------------------------------------- users

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final users = [...repo.users]..sort((a, b) {
        final r = a.role.index.compareTo(b.role.index);
        return r != 0 ? r : a.name.compareTo(b.name);
      });

    String scope(AppUser u) {
      if (u.subDivisionId != null) {
        return repo.subDivisionById(u.subDivisionId!).name;
      }
      if (u.divisionId != null) return repo.divisionById(u.divisionId!).name;
      if (u.circleId != null) return repo.circleById(u.circleId!).name;
      return 'All / none';
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add user'),
        onPressed: () => showDialog(
            context: context, builder: (_) => const _UserDialog()),
      ),
      body: PageBody(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(child: Text(u.name.substring(0, 1))),
              title: Text(u.name),
              subtitle: Text('${u.role.label}  |  ${scope(u)}'),
            );
          },
        ),
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog();

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  UserRole role = UserRole.sdo;
  String? circleId, divisionId, subId;
  String? error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    return AlertDialog(
      title: const Text('Add user'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            PickerField<UserRole>(
              label: 'Role',
              value: role,
              items: [for (final r in UserRole.values) PickerItem(r, r.label)],
              onChanged: (v) => setState(() => role = v ?? role),
            ),
            if (role == UserRole.se) ...[
              const SizedBox(height: 12),
              PickerField<String>(
                label: 'Circle',
                value: circleId,
                items: [for (final c in repo.circles) PickerItem(c.id, c.name)],
                onChanged: (v) => setState(() => circleId = v),
              ),
            ],
            if (role == UserRole.xen) ...[
              const SizedBox(height: 12),
              PickerField<String>(
                label: 'Division',
                value: divisionId,
                items: [for (final d in repo.divisions) PickerItem(d.id, d.name)],
                onChanged: (v) => setState(() => divisionId = v),
              ),
            ],
            if (role == UserRole.sdo) ...[
              const SizedBox(height: 12),
              PickerField<String>(
                label: 'Sub-division (becomes its SDO)',
                value: subId,
                searchable: true,
                items: [
                  for (final s in repo.subDivisions) PickerItem(s.id, s.name),
                ],
                onChanged: (v) => setState(() => subId = v),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final err = repo.addUser(
              name: _name.text,
              role: role,
              phone: _phone.text,
              circleId: circleId,
              divisionId: divisionId,
              subDivisionId: subId,
            );
            if (err != null) {
              setState(() => error = err);
            } else {
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- rules

class _RulesTab extends StatelessWidget {
  const _RulesTab();

  Future<void> _edit(BuildContext context, String title, int current,
      void Function(int) apply) async {
    final v = await askText(context,
        title: title, label: 'New value (currently $current)', confirm: 'Save');
    if (v == null || !context.mounted) return;
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) {
      showMsg(context, 'Enter a whole number above zero.', error: true);
      return;
    }
    apply(n);
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.watch<ComplianceRules>();

    Widget tile(String title, String value, VoidCallback onTap) => ListTile(
          title: Text(title),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 18),
          ]),
          onTap: onTap,
        );

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.amber.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'These defaults are placeholders. Set them from the NEPRA '
                'distribution performance standards and IESCO rules. All '
                'compliance checks, escalations and reports read these values.',
              ),
            ),
          ),
          SectionCard(
            title: 'Restoration limits (minutes)',
            child: Column(children: [
              for (final t in OutageType.values)
                tile(t.label, '${rules.restorationLimitFor(t)} min',
                    () => _edit(context, '${t.label} limit (minutes)',
                        rules.restorationLimitFor(t),
                        (n) => rules.setRestorationLimit(t, n))),
            ]),
          ),
          SectionCard(
            title: 'Escalation',
            child: Column(children: [
              tile('Escalate to XEN after', '${rules.escalateToXenMinutes} min',
                  () => _edit(context, 'Escalate to XEN (minutes)',
                      rules.escalateToXenMinutes, (n) => rules.update(escalateXen: n))),
              tile('Escalate to SE after', '${rules.escalateToSeMinutes} min',
                  () => _edit(context, 'Escalate to SE (minutes)',
                      rules.escalateToSeMinutes, (n) => rules.update(escalateSe: n))),
            ]),
          ),
          SectionCard(
            title: 'Transformer jobs',
            child: Column(children: [
              tile('Standard job limit', '${rules.installJobLimitDays} days',
                  () => _edit(context, 'Standard job limit (days)',
                      rules.installJobLimitDays, (n) => rules.update(installDays: n))),
              tile('Failed-transformer replacement',
                  '${rules.failureReplacementLimitHours} h',
                  () => _edit(context, 'Replacement limit (hours)',
                      rules.failureReplacementLimitHours,
                      (n) => rules.update(failureHours: n))),
            ]),
          ),
        ],
      ),
    );
  }
}
