import 'dart:math';
import '../core/enums.dart';
import '../models/app_user.dart';
import '../models/area.dart';
import '../models/install_job.dart';
import '../models/outage.dart';
import '../models/transformer.dart';
import 'repository.dart';

/// Demo data. Circle, division and sub-division names below are ILLUSTRATIVE,
/// loosely modeled on IESCO's service area. Replace them with the real
/// hierarchy (from IESCO's records) before real use.
const _layout = <String, Map<String, List<String>>>{
  'Islamabad': {
    'Islamabad City Division': ['F-6 / F-7 Sub-Division', 'G-9 / G-10 Sub-Division'],
    'Islamabad Rural Division': ['Tarnol Sub-Division', 'Bhara Kahu Sub-Division'],
  },
  'Rawalpindi': {
    'Rawalpindi City Division': ['Saddar Sub-Division', 'Chaklala Sub-Division'],
    'Rawalpindi Cantt Division': ['Westridge Sub-Division', 'Gulzar-e-Quaid Sub-Division'],
  },
  'Attock': {
    'Attock Division': ['Attock City Sub-Division', 'Hassanabdal Sub-Division'],
    'Hazro Division': ['Hazro Sub-Division', 'Jand Sub-Division'],
  },
  'Chakwal': {
    'Chakwal Division': ['Chakwal City Sub-Division', 'Talagang Sub-Division'],
    'Choa Saidan Shah Division': ['Choa Saidan Shah Sub-Division', 'Kallar Kahar Sub-Division'],
  },
  'Jhelum': {
    'Jhelum Division': ['Jhelum City Sub-Division', 'Sohawa Sub-Division'],
    'Pind Dadan Khan Division': ['Pind Dadan Khan Sub-Division', 'Dina Sub-Division'],
  },
};

const _causes = [
  'Conductor snapping',
  'Transformer overload',
  'Insulator flashover',
  'Tree contact',
  'Cable fault',
  'Fuse blown',
  'Grid tripping',
  'Lightning',
];

const _kva = [25, 50, 100, 200, 400];

void seedRepository(Repository repo) {
  final rnd = Random(7);
  final now = DateTime.now();
  var cN = 0, dN = 0, sN = 0, fN = 0;

  repo.users.addAll([
    AppUser(id: 'ho1', name: 'Head Office Manager', role: UserRole.headOffice),
    AppUser(id: 'adm1', name: 'System Admin', role: UserRole.admin),
    AppUser(id: 'rep1', name: 'Call Center Agent', role: UserRole.reporter, phone: '0300-1111111'),
    AppUser(id: 'rep2', name: 'Lineman Kamran', role: UserRole.reporter, phone: '0300-2222222'),
  ]);

  _layout.forEach((circleName, divs) {
    final c = Circle(id: 'C${++cN}', name: circleName);
    repo.circles.add(c);
    repo.users.add(AppUser(
        id: 'se$cN', name: 'SE $circleName', role: UserRole.se, circleId: c.id));
    divs.forEach((divName, subs) {
      final d = Division(id: 'D${++dN}', name: divName, circleId: c.id);
      repo.divisions.add(d);
      repo.users.add(AppUser(
          id: 'xen$dN',
          name: 'XEN ${divName.replaceAll(' Division', '')}',
          role: UserRole.xen,
          divisionId: d.id));
      for (final subName in subs) {
        final sId = 'S${++sN}';
        final uid = 'sdo$sN';
        repo.users.add(AppUser(
          id: uid,
          name: 'SDO ${subName.replaceAll(' Sub-Division', '')}',
          role: UserRole.sdo,
          subDivisionId: sId,
          phone: '0300-000${sN.toString().padLeft(4, '0')}',
        ));
        repo.subDivisions.add(
            SubDivision(id: sId, name: subName, divisionId: d.id, sdoUserId: uid));
        for (var i = 1; i <= 2; i++) {
          final fId = 'F${++fN}';
          final feeder = Feeder(
            id: fId,
            name: '${subName.split(' ').first} Feeder $i',
            subDivisionId: sId,
            consumers: 800 + rnd.nextInt(2200),
          );
          repo.feeders.add(feeder);
          for (var k = 1; k <= 3; k++) {
            final n = repo.transformers.length + 1;
            repo.transformers.add(Transformer(
              id: 'T-$n',
              code: 'TX-${circleName.substring(0, 3).toUpperCase()}-${n.toString().padLeft(4, '0')}',
              kva: _kva[rnd.nextInt(_kva.length)],
              feederId: fId,
              location: '${feeder.name}, pole ${k * 12}',
              lat: 33.5 + rnd.nextDouble() * 0.6,
              lng: 72.6 + rnd.nextDouble() * 0.8,
              installDate: DateTime(2015 + rnd.nextInt(9), 1 + rnd.nextInt(12), 1 + rnd.nextInt(27)),
              history: ['Initial entry (seed data)'],
            ));
          }
        }
      }
    });
  });

  final prevYear = now.year - 1;
  final curStart = DateTime(now.year, 1, 1);
  final curEnd = now.subtract(const Duration(days: 2));

  for (final f in repo.feeders) {
    for (var i = 0; i < 8; i++) {
      _seedOutage(repo, rnd, f,
          _rand(rnd, DateTime(prevYear, 1, 1), DateTime(prevYear, 12, 31, 23)));
    }
    if (curEnd.isAfter(curStart)) {
      for (var i = 0; i < 7; i++) {
        _seedOutage(repo, rnd, f, _rand(rnd, curStart, curEnd));
      }
    }
  }

  _seedOpenOutages(repo, rnd, now);
  _seedJobs(repo, rnd, now);
  repo.runEscalations();
}

DateTime _rand(Random r, DateTime from, DateTime to) =>
    from.add(Duration(minutes: r.nextInt(max(1, to.difference(from).inMinutes))));

OutageType _pickType(Random r) {
  final v = r.nextInt(100);
  if (v < 15) return OutageType.planned;
  if (v < 45) return OutageType.forced;
  if (v < 80) return OutageType.fault;
  return OutageType.loadShedding;
}

void _seedOutage(Repository repo, Random rnd, Feeder f, DateTime start) {
  final type = _pickType(rnd);
  final cause = type == OutageType.planned
      ? 'Maintenance work'
      : type == OutageType.loadShedding
          ? 'Load management'
          : _causes[rnd.nextInt(_causes.length)];
  final mins = type == OutageType.planned
      ? 120 + rnd.nextInt(420)
      : 30 + rnd.nextInt(470);
  final end = start.add(Duration(minutes: mins));
  final o = Outage(
    id: repo.genId('OUT', start.year, repo.outages.map((e) => e.id)),
    feederId: f.id,
    subDivisionId: f.subDivisionId,
    type: type,
    cause: cause,
    description: '$cause on ${f.name}',
    startTime: start,
    endTime: end,
    status: OutageStatus.closed,
    consumersAffected: max(50, (f.consumers * (0.3 + rnd.nextDouble() * 0.7)).round()),
    reportedBy: 'rep1',
    crew: 'Lineman team ${1 + rnd.nextInt(4)}',
    causeFound: cause,
    actionTaken: 'Repaired and restored supply',
  );
  o.timeline.addAll([
    OutageEvent(time: start, text: 'Reported by Call Center Agent', by: 'Call Center Agent'),
    OutageEvent(time: end, text: 'Restored. Cause: $cause', by: 'System (seed)'),
  ]);
  repo.outages.add(o);
}

void _seedOpenOutages(Repository repo, Random rnd, DateTime now) {
  const ages = [25, 90, 200, 250, 400, 130, 700, 45];
  const statuses = [
    OutageStatus.reported,
    OutageStatus.assigned,
    OutageStatus.inProgress,
  ];
  for (var i = 0; i < ages.length; i++) {
    final f = repo.feeders[(i * 5 + 3) % repo.feeders.length];
    final start = now.subtract(Duration(minutes: ages[i]));
    final status = statuses[i % statuses.length];
    final type = i % 3 == 0 ? OutageType.fault : OutageType.forced;
    final o = Outage(
      id: repo.genId('OUT', start.year, repo.outages.map((e) => e.id)),
      feederId: f.id,
      subDivisionId: f.subDivisionId,
      type: type,
      cause: _causes[(i * 3) % _causes.length],
      description: 'Supply down on ${f.name}',
      startTime: start,
      consumersAffected: max(50, (f.consumers * 0.6).round()),
      reportedBy: 'rep1',
      status: status,
      crew: status == OutageStatus.reported ? null : 'Lineman team ${1 + i % 4}',
    );
    o.timeline.add(OutageEvent(
        time: start, text: 'Reported by Call Center Agent', by: 'Call Center Agent'));
    final sdo = repo.sdoFor(f.subDivisionId);
    if (sdo != null) {
      o.timeline.add(OutageEvent(
          time: start, text: 'Auto-routed to ${sdo.name}', by: 'System'));
      repo.notify(sdo.id, 'New ${type.label} outage on ${f.name} (${o.id})', o.id);
    }
    repo.outages.add(o);
  }
}

void _seedJobs(Repository repo, Random rnd, DateTime now) {
  final prevYear = now.year - 1;
  final curStart = DateTime(now.year, 1, 1);
  final curEnd = now.subtract(const Duration(days: 60));

  // Completed jobs in the previous and current year.
  for (final f in repo.feeders) {
    for (final year in [prevYear, now.year]) {
      if (rnd.nextInt(100) < 55) continue;
      final from = year == prevYear ? DateTime(prevYear, 1, 1) : curStart;
      final to = year == prevYear ? DateTime(prevYear, 11, 1) : curEnd;
      if (!to.isAfter(from)) continue;
      final reason = InstallReason.values[rnd.nextInt(InstallReason.values.length)];
      _seedJob(repo, rnd, f, reason, _rand(rnd, from, to), complete: true, now: now);
    }
  }

  // A few jobs still in progress at different stages.
  for (var i = 0; i < 9; i++) {
    final f = repo.feeders[(i * 4 + 1) % repo.feeders.length];
    final reason = InstallReason.values[i % InstallReason.values.length];
    final created = now.subtract(Duration(days: 3 + rnd.nextInt(12)));
    _seedJob(repo, rnd, f, reason, created, complete: false, now: now, stopAt: i % 6);
  }
}

void _seedJob(
  Repository repo,
  Random rnd,
  Feeder f,
  InstallReason reason,
  DateTime createdAt, {
  required bool complete,
  required DateTime now,
  int stopAt = 0,
}) {
  final feederTx = repo.transformers.where((t) => t.feederId == f.id).toList();
  final needsExisting = reason != InstallReason.newConnectionLoad;
  final existing = needsExisting ? feederTx[rnd.nextInt(feederTx.length)] : null;
  final code = existing?.code ?? repo.newTransformerCode(f.id);
  final kva = _kva[rnd.nextInt(_kva.length)];

  final job = InstallJob(
    id: repo.genId('INS', createdAt.year, repo.jobs.map((e) => e.id)),
    feederId: f.id,
    subDivisionId: f.subDivisionId,
    transformerCode: code,
    kva: kva,
    location: existing?.location ?? '${f.name}, new site',
    reason: reason,
    createdAt: createdAt,
    createdBy: 'rep2',
  );
  job.records.add(StageRecord(
      stage: InstallStage.requested,
      time: createdAt,
      officer: 'Lineman Kamran',
      notes: 'Request logged: ${reason.label}'));

  final lastIndex = complete ? InstallStage.values.length - 1 : stopAt;
  var t = createdAt;
  for (var i = 1; i <= lastIndex; i++) {
    final stage = InstallStage.values[i];
    if (complete) {
      final gapHours = reason == InstallReason.failure
          ? 4 + rnd.nextInt(26)
          : 24 + rnd.nextInt(170);
      t = t.add(Duration(hours: gapHours));
    } else {
      t = t.add(Duration(
          minutes: max(1, now.difference(createdAt).inMinutes ~/ (lastIndex + 1))));
    }
    job.records.add(StageRecord(
      stage: stage,
      time: t,
      officer: repo.sdoFor(f.subDivisionId)?.name ?? 'SDO',
      notes: '${stage.label} completed',
      attachments: stage.requiresPhoto ? ['photo_${stage.name}.jpg'] : const [],
    ));
    job.stage = stage;
  }

  if (complete) {
    job.completedAt = t;
    if (existing != null) {
      existing.kva = kva;
      existing.status = TransformerStatus.active;
      existing.installDate = t;
      existing.history.add('${repo.fmtStamp(t)} ${reason.isReplacement ? 'Replaced' : 'Upgraded'} via job ${job.id} ($kva kVA)');
    } else {
      repo.transformers.add(Transformer(
        id: 'T-${repo.transformers.length + 1}',
        code: code,
        kva: kva,
        feederId: f.id,
        location: job.location,
        installDate: t,
        history: ['${repo.fmtStamp(t)} Installed via job ${job.id} ($kva kVA)'],
      ));
    }
  } else if (existing != null && reason == InstallReason.failure) {
    existing.status = TransformerStatus.failed;
    existing.history.add('${repo.fmtStamp(createdAt)} Failure reported (job ${job.id})');
  }
  repo.jobs.add(job);
}
