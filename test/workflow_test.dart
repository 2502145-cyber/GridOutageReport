import 'package:flutter_test/flutter_test.dart';
import 'package:grid_report_manager/core/compliance_rules.dart';
import 'package:grid_report_manager/core/enums.dart';
import 'package:grid_report_manager/data/repository.dart';
import 'package:grid_report_manager/data/seed_data.dart';
import 'package:grid_report_manager/services/report_service.dart';

Repository _repo() {
  final r = Repository(ComplianceRules());
  seedRepository(r);
  return r;
}

void main() {
  test('outage is routed to the SDO who owns the feeder sub-division', () {
    final r = _repo();
    final sdo = r.users.firstWhere((u) => u.role == UserRole.sdo);
    final feeder =
        r.feeders.firstWhere((f) => f.subDivisionId == sdo.subDivisionId);
    r.login(r.users.firstWhere((u) => u.role == UserRole.reporter));

    final o = r.reportOutage(
      feederId: feeder.id,
      type: OutageType.fault,
      cause: 'Fuse blown',
      description: 'Supply down',
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      consumersAffected: 100,
    );

    expect(o.subDivisionId, sdo.subDivisionId);
    expect(
      r.notifications.any((n) => n.toUserId == sdo.id && n.entityId == o.id),
      isTrue,
    );
  });

  test('only the owning SDO can act, and restore needs a cause', () {
    final r = _repo();
    final sdos = r.users.where((u) => u.role == UserRole.sdo).toList();
    final owner = sdos[0];
    final other = sdos[1];
    final feeder =
        r.feeders.firstWhere((f) => f.subDivisionId == owner.subDivisionId);
    r.login(r.users.firstWhere((u) => u.role == UserRole.reporter));
    final o = r.reportOutage(
      feederId: feeder.id,
      type: OutageType.forced,
      cause: 'Tree contact',
      description: 'Tree on line',
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      consumersAffected: 50,
    );

    r.login(other);
    expect(r.assignOutage(o, 'Team A'), isNotNull);

    r.login(owner);
    expect(r.assignOutage(o, 'Team A'), isNull);
    expect(
      r.restoreOutage(o,
          causeFound: '', actionTaken: 'Fixed', endTime: DateTime.now()),
      isNotNull,
    );
    expect(
      r.restoreOutage(o,
          causeFound: 'Tree', actionTaken: 'Cleared', endTime: DateTime.now()),
      isNull,
    );
    expect(r.closeOutage(o), isNull);
    expect(o.status, OutageStatus.closed);
  });

  test('overdue open outage escalates to the SE', () {
    final r = _repo();
    final feeder = r.feeders.first;
    r.login(r.users.firstWhere((u) => u.role == UserRole.reporter));
    final o = r.reportOutage(
      feederId: feeder.id,
      type: OutageType.fault,
      cause: 'Cable fault',
      description: 'Underground cable',
      startTime: DateTime.now().subtract(const Duration(minutes: 400)),
      consumersAffected: 200,
    );

    expect(r.runEscalations(), greaterThanOrEqualTo(1));
    expect(o.escalation, EscalationLevel.se);
  });

  test('installation job enforces notes and photos, then commissions', () {
    final r = _repo();
    final sdo = r.users.firstWhere((u) => u.role == UserRole.sdo);
    final feeder =
        r.feeders.firstWhere((f) => f.subDivisionId == sdo.subDivisionId);
    r.login(sdo);
    final j = r.createJob(
      feederId: feeder.id,
      reason: InstallReason.newConnectionLoad,
      kva: 100,
      location: 'Pole 7',
      requestNotes: 'New housing block',
    );

    expect(r.advanceJob(j, notes: ''), isNotNull); // notes required
    expect(r.advanceJob(j, notes: 'Surveyed'), isNull);
    expect(r.advanceJob(j, notes: 'Approved'), isNull);
    expect(r.advanceJob(j, notes: 'Material issued'), isNull);
    expect(j.stage, InstallStage.materialIssued);
    expect(r.advanceJob(j, notes: 'Installed'), isNotNull); // photo required
    expect(r.advanceJob(j, notes: 'Installed', attachments: ['a.jpg']), isNull);
    expect(r.advanceJob(j, notes: 'Tested', attachments: ['b.jpg']), isNull);
    expect(r.advanceJob(j, notes: 'Live'), isNull);

    expect(j.isComplete, isTrue);
    expect(r.transformers.any((t) => t.code == j.transformerCode), isTrue);
  });

  test('annual report: district totals add up to the company total', () {
    final r = _repo();
    final a = ReportService(r).annual(DateTime.now().year - 1);
    final sum = a.districts.fold<int>(0, (s, d) => s + d.outageCount);
    expect(a.company.outageCount, greaterThan(0));
    expect(sum, a.company.outageCount);
  });
}
