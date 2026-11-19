import '../core/enums.dart';
import '../data/repository.dart';
import '../models/install_job.dart';
import '../models/outage.dart';

/// Aggregated numbers for one unit (a sub-division, a district/circle, or the
/// whole company) over one period.
class UnitStats {
  final String id;
  final String name;
  UnitStats(this.id, this.name);

  int outageCount = 0;
  double totalMinutes = 0;
  int restoredCount = 0;
  double restoredMinutes = 0;
  int consumersAffected = 0;
  int pendingOutages = 0;
  int outagesEvaluated = 0;
  int outagesCompliant = 0;
  final Map<String, int> causes = {};
  final Map<OutageType, int> byType = {};

  int txInstalled = 0;
  int txReplaced = 0;
  int txFailed = 0;
  int pendingJobs = 0;
  int jobsEvaluated = 0;
  int jobsCompliant = 0;
  int transformerCount = 0;

  double get totalHours => totalMinutes / 60;
  double get avgRestorationMinutes =>
      restoredCount == 0 ? 0 : restoredMinutes / restoredCount;

  /// Share of outages restored (or still open) within the configured limit.
  double get outageCompliance =>
      outagesEvaluated == 0 ? 1 : outagesCompliant / outagesEvaluated;

  double get jobCompliance =>
      jobsEvaluated == 0 ? 1 : jobsCompliant / jobsEvaluated;

  double get failureRate =>
      transformerCount == 0 ? 0 : txFailed / transformerCount;
}

class AnnualReport {
  final int year;
  final UnitStats company;
  final UnitStats previous;
  final List<UnitStats> districts; // one per circle
  final List<UnitStats> subDivisions; // all, sorted best to worst
  AnnualReport({
    required this.year,
    required this.company,
    required this.previous,
    required this.districts,
    required this.subDivisions,
  });

  List<UnitStats> get best => subDivisions.take(3).toList();
  List<UnitStats> get worst => subDivisions.reversed.take(3).toList();
}

class ReportService {
  final Repository repo;
  ReportService(this.repo);

  List<int> get availableYears {
    if (repo.outages.isEmpty) return [DateTime.now().year];
    final ys = repo.outages.map((o) => o.startTime.year).toSet().toList()
      ..sort();
    return ys.reversed.toList();
  }

  UnitStats compute({
    required String id,
    required String name,
    required int year,
    int? month,
    required bool Function(String subDivisionId) include,
  }) {
    final s = UnitStats(id, name);
    final now = DateTime.now();
    bool inPeriod(DateTime d) =>
        d.year == year && (month == null || d.month == month);

    for (final o in repo.outages) {
      if (!include(o.subDivisionId) || !inPeriod(o.startTime)) continue;
      s.outageCount++;
      final dur = o.duration(now);
      s.totalMinutes += dur.inMinutes;
      s.consumersAffected += o.consumersAffected;
      s.causes[o.cause] = (s.causes[o.cause] ?? 0) + 1;
      s.byType[o.type] = (s.byType[o.type] ?? 0) + 1;
      final limit = repo.rules.restorationLimitFor(o.type);
      if (o.endTime != null) {
        s.restoredCount++;
        s.restoredMinutes += dur.inMinutes;
        s.outagesEvaluated++;
        if (dur.inMinutes <= limit) s.outagesCompliant++;
      } else {
        s.pendingOutages++;
        if (dur.inMinutes > limit) s.outagesEvaluated++; // overdue = breach
      }
    }

    for (final j in repo.jobs) {
      if (!include(j.subDivisionId)) continue;
      final limit = repo.rules.installLimitFor(j.reason);
      final done = j.completedAt;
      if (j.isComplete && done != null && inPeriod(done)) {
        if (j.reason.isReplacement) {
          s.txReplaced++;
        } else {
          s.txInstalled++;
        }
        s.jobsEvaluated++;
        if (done.difference(j.createdAt) <= limit) s.jobsCompliant++;
      }
      if (j.reason == InstallReason.failure && inPeriod(j.createdAt)) {
        s.txFailed++;
      }
      if (!j.isComplete && inPeriod(j.createdAt)) {
        s.pendingJobs++;
        if (now.difference(j.createdAt) > limit) s.jobsEvaluated++;
      }
    }

    for (final t in repo.transformers) {
      if (include(repo.feederById(t.feederId).subDivisionId)) {
        s.transformerCount++;
      }
    }
    return s;
  }

  UnitStats monthly(String subDivisionId, int year, int month) {
    final sub = repo.subDivisionById(subDivisionId);
    return compute(
      id: sub.id,
      name: sub.name,
      year: year,
      month: month,
      include: (id) => id == subDivisionId,
    );
  }

  List<Outage> outagesFor(String subDivisionId, int year, int month) {
    final list = repo.outages
        .where((o) =>
            o.subDivisionId == subDivisionId &&
            o.startTime.year == year &&
            o.startTime.month == month)
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  List<InstallJob> jobsFor(String subDivisionId, int year, int month) {
    final list = repo.jobs
        .where((j) =>
            j.subDivisionId == subDivisionId &&
            j.createdAt.year == year &&
            j.createdAt.month == month)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  AnnualReport annual(int year) {
    final subToCircle = <String, String>{
      for (final s in repo.subDivisions) s.id: repo.circleOfSub(s.id).id,
    };
    UnitStats company(int y) => compute(
        id: 'ALL',
        name: 'Company-wide (all districts)',
        year: y,
        include: (_) => true);

    final districts = [
      for (final c in repo.circles)
        compute(
          id: c.id,
          name: c.name,
          year: year,
          include: (sid) => subToCircle[sid] == c.id,
        ),
    ];

    final subs = [
      for (final s in repo.subDivisions)
        compute(
          id: s.id,
          name: s.name,
          year: year,
          include: (sid) => sid == s.id,
        ),
    ]..sort((a, b) {
        final c = b.outageCompliance.compareTo(a.outageCompliance);
        if (c != 0) return c;
        return a.avgRestorationMinutes.compareTo(b.avgRestorationMinutes);
      });

    return AnnualReport(
      year: year,
      company: company(year),
      previous: company(year - 1),
      districts: districts,
      subDivisions: subs,
    );
  }
}
