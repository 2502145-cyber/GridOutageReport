import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/compliance_rules.dart';
import '../core/enums.dart';
import '../models/app_user.dart';
import '../models/area.dart';
import '../models/audit_entry.dart';
import '../models/install_job.dart';
import '../models/outage.dart';
import '../models/transformer.dart';

/// In-memory data store plus all workflow logic (routing, escalation, stage
/// validation, audit logging). Swap this class for a backend-backed one
/// later; the screens only talk to this API.
class Repository extends ChangeNotifier {
  final ComplianceRules rules;
  Repository(this.rules);

  final List<Circle> circles = [];
  final List<Division> divisions = [];
  final List<SubDivision> subDivisions = [];
  final List<Feeder> feeders = [];
  final List<AppUser> users = [];
  final List<Transformer> transformers = [];
  final List<Outage> outages = [];
  final List<InstallJob> jobs = [];
  final List<AuditEntry> audit = [];
  final List<AppNotification> notifications = [];

  AppUser? currentUser;
  Timer? _timer;

  // ---------------------------------------------------------------- lookups

  Feeder feederById(String id) => feeders.firstWhere((f) => f.id == id);
  SubDivision subDivisionById(String id) =>
      subDivisions.firstWhere((s) => s.id == id);
  Division divisionById(String id) => divisions.firstWhere((d) => d.id == id);
  Circle circleById(String id) => circles.firstWhere((c) => c.id == id);

  Division divisionOfSub(String subId) =>
      divisionById(subDivisionById(subId).divisionId);
  Circle circleOfSub(String subId) =>
      circleById(divisionOfSub(subId).circleId);

  AppUser? userById(String? id) {
    if (id == null) return null;
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  AppUser? sdoFor(String subDivisionId) =>
      userById(subDivisionById(subDivisionId).sdoUserId);

  String areaPath(String subDivisionId) {
    final s = subDivisionById(subDivisionId);
    final d = divisionById(s.divisionId);
    final c = circleById(d.circleId);
    return '${c.name} > ${d.name} > ${s.name}';
  }

  // ------------------------------------------------------------ session/scope

  void login(AppUser u) {
    currentUser = u;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  bool inScope(AppUser u, String subDivisionId) {
    switch (u.role) {
      case UserRole.reporter:
        return true;
      case UserRole.sdo:
        return u.subDivisionId == subDivisionId;
      case UserRole.xen:
        return divisionOfSub(subDivisionId).id == u.divisionId;
      case UserRole.se:
        return circleOfSub(subDivisionId).id == u.circleId;
      case UserRole.headOffice:
      case UserRole.admin:
        return true;
    }
  }

  bool canManage(String subDivisionId) {
    final u = currentUser;
    return u != null && u.role.canManage && inScope(u, subDivisionId);
  }

  List<SubDivision> get scopedSubDivisions {
    final u = currentUser;
    if (u == null) return [];
    return subDivisions.where((s) => inScope(u, s.id)).toList();
  }

  List<Feeder> get scopedFeeders {
    final ids = scopedSubDivisions.map((s) => s.id).toSet();
    return feeders.where((f) => ids.contains(f.subDivisionId)).toList();
  }

  List<Outage> get visibleOutages {
    final u = currentUser;
    if (u == null) return [];
    final list = outages.where((o) {
      if (u.role == UserRole.reporter) return o.reportedBy == u.id;
      return inScope(u, o.subDivisionId);
    }).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  List<InstallJob> get visibleJobs {
    final u = currentUser;
    if (u == null) return [];
    final list = jobs.where((j) {
      if (u.role == UserRole.reporter) return j.createdBy == u.id;
      return inScope(u, j.subDivisionId);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Transformer> get visibleTransformers {
    final u = currentUser;
    if (u == null) return [];
    return transformers
        .where((t) => inScope(u, feederById(t.feederId).subDivisionId))
        .toList();
  }

  // -------------------------------------------------------------- audit/notify

  void log(String action, String entityId) {
    audit.insert(
      0,
      AuditEntry(
        time: DateTime.now(),
        userName: currentUser?.name ?? 'System',
        action: action,
        entityId: entityId,
      ),
    );
  }

  void notify(String? toUserId, String message, [String? entityId]) {
    if (toUserId == null) return;
    notifications.insert(
      0,
      AppNotification(
        id: 'N-${DateTime.now().microsecondsSinceEpoch}-${notifications.length}',
        toUserId: toUserId,
        message: message,
        time: DateTime.now(),
        entityId: entityId,
      ),
    );
  }

  List<AppNotification> get myNotifications {
    final u = currentUser;
    if (u == null) return [];
    return notifications.where((n) => n.toUserId == u.id).toList();
  }

  int get unreadCount => myNotifications.where((n) => !n.read).length;

  void markAllRead() {
    for (final n in myNotifications) {
      n.read = true;
    }
    notifyListeners();
  }

  String genId(String prefix, int year, Iterable<String> existing) {
    final p = '$prefix-$year-';
    final n = existing.where((e) => e.startsWith(p)).length + 1;
    return '$p${n.toString().padLeft(4, '0')}';
  }

  // ------------------------------------------------------------ outage workflow

  /// Logs an outage and routes it automatically to the SDO who owns the
  /// feeder's sub-division.
  Outage reportOutage({
    required String feederId,
    required OutageType type,
    required String cause,
    required String description,
    required DateTime startTime,
    required int consumersAffected,
  }) {
    final feeder = feederById(feederId);
    final user = currentUser!;
    final now = DateTime.now();
    final o = Outage(
      id: genId('OUT', startTime.year, outages.map((e) => e.id)),
      feederId: feederId,
      subDivisionId: feeder.subDivisionId,
      type: type,
      cause: cause.trim(),
      description: description.trim(),
      startTime: startTime,
      consumersAffected: consumersAffected,
      reportedBy: user.id,
    );
    o.timeline.add(OutageEvent(
        time: now, text: 'Reported by ${user.name}', by: user.name));
    final sdo = sdoFor(feeder.subDivisionId);
    if (sdo != null) {
      o.timeline.add(OutageEvent(
          time: now,
          text: 'Auto-routed to ${sdo.name} (${areaPath(feeder.subDivisionId)})',
          by: 'System'));
      notify(sdo.id,
          'New ${type.label} outage on ${feeder.name} (${o.id}) - ${o.consumersAffected} consumers',
          o.id);
    } else {
      o.timeline.add(OutageEvent(
          time: now,
          text: 'No SDO assigned to this sub-division - needs admin action',
          by: 'System'));
      for (final a in users.where((u) => u.role == UserRole.admin)) {
        notify(a.id, 'Outage ${o.id} has no SDO assigned', o.id);
      }
    }
    outages.add(o);
    log('Reported outage', o.id);
    notifyListeners();
    return o;
  }

  String? assignOutage(Outage o, String crew) {
    if (!canManage(o.subDivisionId)) return 'You cannot manage this outage.';
    if (crew.trim().isEmpty) return 'Crew / lineman name is required.';
    if (!o.isOpen) return 'Outage is already restored.';
    o.crew = crew.trim();
    o.status = OutageStatus.assigned;
    o.timeline.add(OutageEvent(
        time: DateTime.now(),
        text: 'Assigned to crew: ${o.crew}',
        by: currentUser!.name));
    log('Assigned outage to ${o.crew}', o.id);
    notifyListeners();
    return null;
  }

  String? startWork(Outage o) {
    if (!canManage(o.subDivisionId)) return 'You cannot manage this outage.';
    if (o.crew == null) return 'Assign a crew first.';
    o.status = OutageStatus.inProgress;
    o.timeline.add(OutageEvent(
        time: DateTime.now(), text: 'Work started', by: currentUser!.name));
    log('Started work', o.id);
    notifyListeners();
    return null;
  }

  String? restoreOutage(
    Outage o, {
    required String causeFound,
    required String actionTaken,
    required DateTime endTime,
  }) {
    if (!canManage(o.subDivisionId)) return 'You cannot manage this outage.';
    if (causeFound.trim().isEmpty) return 'Cause found is required.';
    if (actionTaken.trim().isEmpty) return 'Action taken is required.';
    if (!endTime.isAfter(o.startTime)) {
      return 'Restoration time must be after the start time.';
    }
    if (endTime.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return 'Restoration time cannot be in the future.';
    }
    o.causeFound = causeFound.trim();
    o.actionTaken = actionTaken.trim();
    o.endTime = endTime;
    o.status = OutageStatus.restored;
    o.timeline.add(OutageEvent(
        time: DateTime.now(),
        text: 'Restored. Cause: ${o.causeFound}. Action: ${o.actionTaken}',
        by: currentUser!.name));
    log('Restored outage', o.id);
    notify(o.reportedBy, 'Outage ${o.id} has been restored', o.id);
    notifyListeners();
    return null;
  }

  String? closeOutage(Outage o) {
    if (!canManage(o.subDivisionId)) return 'You cannot manage this outage.';
    if (o.status != OutageStatus.restored) {
      return 'Restore the outage before closing it.';
    }
    o.status = OutageStatus.closed;
    o.timeline.add(OutageEvent(
        time: DateTime.now(),
        text: 'Closed - standard report generated',
        by: currentUser!.name));
    log('Closed outage', o.id);
    notifyListeners();
    return null;
  }

  /// Escalates overdue open outages: first to the XEN, then to the SE.
  /// Returns how many outages were escalated in this pass.
  int runEscalations() {
    final t = DateTime.now();
    var count = 0;
    for (final o in outages.where((o) => o.isOpen)) {
      final age = t.difference(o.startTime).inMinutes;
      if (o.type == OutageType.planned &&
          age < rules.restorationLimitFor(OutageType.planned)) {
        continue;
      }
      var target = EscalationLevel.none;
      if (age >= rules.escalateToSeMinutes) {
        target = EscalationLevel.se;
      } else if (age >= rules.escalateToXenMinutes) {
        target = EscalationLevel.xen;
      }
      if (target.index <= o.escalation.index) continue;
      o.escalation = target;
      count++;
      final div = divisionOfSub(o.subDivisionId);
      final recipients = users.where((u) => target == EscalationLevel.xen
          ? (u.role == UserRole.xen && u.divisionId == div.id)
          : (u.role == UserRole.se && u.circleId == div.circleId));
      for (final r in recipients) {
        notify(r.id,
            'ESCALATION: ${o.id} open for ${age ~/ 60}h ${age % 60}m in ${areaPath(o.subDivisionId)}',
            o.id);
      }
      o.timeline.add(OutageEvent(
          time: t,
          text: 'Auto-escalated: ${target.label}',
          by: 'System'));
      audit.insert(
          0,
          AuditEntry(
              time: t,
              userName: 'System',
              action: 'Escalated outage (${target.label})',
              entityId: o.id));
    }
    if (count > 0) notifyListeners();
    return count;
  }

  void startEscalationTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => runEscalations());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------ installation workflow

  String newTransformerCode(String feederId) {
    final c = circleOfSub(feederById(feederId).subDivisionId);
    final abbr = c.name.substring(0, 3).toUpperCase();
    final n = transformers.length + jobs.length + 1;
    return 'TX-$abbr-${n.toString().padLeft(4, '0')}';
  }

  InstallJob createJob({
    required String feederId,
    required InstallReason reason,
    required int kva,
    required String location,
    required String requestNotes,
    String? existingCode,
  }) {
    final feeder = feederById(feederId);
    final user = currentUser!;
    final now = DateTime.now();
    final j = InstallJob(
      id: genId('INS', now.year, jobs.map((e) => e.id)),
      feederId: feederId,
      subDivisionId: feeder.subDivisionId,
      transformerCode: existingCode ?? newTransformerCode(feederId),
      kva: kva,
      location: location.trim(),
      reason: reason,
      createdAt: now,
      createdBy: user.id,
    );
    j.records.add(StageRecord(
        stage: InstallStage.requested,
        time: now,
        officer: user.name,
        notes: requestNotes.trim()));
    if (existingCode != null && reason == InstallReason.failure) {
      for (final t in transformers.where((t) => t.code == existingCode)) {
        t.status = TransformerStatus.failed;
        t.history.add('${fmtStamp(now)} Failure reported (job ${j.id})');
      }
    }
    jobs.add(j);
    notify(sdoFor(feeder.subDivisionId)?.id,
        'New ${reason.label} job ${j.id} for ${j.transformerCode} (${j.kva} kVA)',
        j.id);
    log('Created installation job', j.id);
    notifyListeners();
    return j;
  }

  /// Moves a job to its next stage. Each stage needs notes; installation and
  /// testing also need at least one photo/attachment.
  String? advanceJob(InstallJob j,
      {required String notes, List<String> attachments = const []}) {
    final next = j.stage.next;
    if (next == null) return 'Job is already commissioned.';
    if (!canManage(j.subDivisionId)) return 'You cannot manage this job.';
    if (notes.trim().isEmpty) {
      return 'Notes are required for the ${next.label} stage.';
    }
    if (next.requiresPhoto && attachments.isEmpty) {
      return 'At least one photo is required for the ${next.label} stage.';
    }
    final now = DateTime.now();
    j.records.add(StageRecord(
      stage: next,
      time: now,
      officer: currentUser!.name,
      notes: notes.trim(),
      attachments: List.of(attachments),
    ));
    j.stage = next;
    if (next == InstallStage.commissioned) {
      j.completedAt = now;
      _commission(j);
      notify(j.createdBy,
          'Job ${j.id} commissioned: ${j.transformerCode} (${j.kva} kVA)', j.id);
    }
    log('Advanced job to ${next.label}', j.id);
    notifyListeners();
    return null;
  }

  void _commission(InstallJob j) {
    final stamp = fmtStamp(DateTime.now());
    final verb = j.reason.isReplacement ? 'Replaced' : 'Installed';
    for (final t in transformers) {
      if (t.code == j.transformerCode) {
        t.kva = j.kva;
        t.status = TransformerStatus.active;
        t.installDate = DateTime.now();
        t.history.add('$stamp $verb via job ${j.id} (${j.kva} kVA)');
        return;
      }
    }
    transformers.add(Transformer(
      id: 'T-${transformers.length + 1}',
      code: j.transformerCode,
      kva: j.kva,
      feederId: j.feederId,
      location: j.location,
      installDate: DateTime.now(),
      history: ['$stamp $verb via job ${j.id} (${j.kva} kVA)'],
    ));
  }

  String fmtStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------------- admin

  String? addCircle(String name) {
    if (name.trim().isEmpty) return 'Name is required.';
    circles.add(Circle(id: 'C${circles.length + 1}-${DateTime.now().microsecondsSinceEpoch}', name: name.trim()));
    log('Added circle', name.trim());
    notifyListeners();
    return null;
  }

  String? addDivision(String name, String circleId) {
    if (name.trim().isEmpty) return 'Name is required.';
    divisions.add(Division(id: 'D${divisions.length + 1}-${DateTime.now().microsecondsSinceEpoch}', name: name.trim(), circleId: circleId));
    log('Added division', name.trim());
    notifyListeners();
    return null;
  }

  String? addSubDivision(String name, String divisionId) {
    if (name.trim().isEmpty) return 'Name is required.';
    subDivisions.add(SubDivision(id: 'S${subDivisions.length + 1}-${DateTime.now().microsecondsSinceEpoch}', name: name.trim(), divisionId: divisionId));
    log('Added sub-division', name.trim());
    notifyListeners();
    return null;
  }

  String? addFeeder(String name, String subDivisionId, int consumers) {
    if (name.trim().isEmpty) return 'Feeder name is required.';
    if (consumers <= 0) return 'Consumers must be greater than zero.';
    feeders.add(Feeder(id: 'F${feeders.length + 1}-${DateTime.now().microsecondsSinceEpoch}', name: name.trim(), subDivisionId: subDivisionId, consumers: consumers));
    log('Added feeder', name.trim());
    notifyListeners();
    return null;
  }

  void assignSdo(String subDivisionId, String? userId) {
    final s = subDivisionById(subDivisionId);
    s.sdoUserId = userId;
    log('Assigned SDO ${userById(userId)?.name ?? '(none)'}', s.name);
    notifyListeners();
  }

  String? addUser({
    required String name,
    required UserRole role,
    required String phone,
    String? circleId,
    String? divisionId,
    String? subDivisionId,
  }) {
    if (name.trim().isEmpty) return 'Name is required.';
    if (role == UserRole.sdo && subDivisionId == null) {
      return 'Choose a sub-division for the SDO.';
    }
    if (role == UserRole.xen && divisionId == null) {
      return 'Choose a division for the XEN.';
    }
    if (role == UserRole.se && circleId == null) {
      return 'Choose a circle for the SE.';
    }
    final u = AppUser(
      id: 'U-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      role: role,
      phone: phone.trim(),
      circleId: circleId,
      divisionId: divisionId,
      subDivisionId: subDivisionId,
    );
    users.add(u);
    if (role == UserRole.sdo) {
      subDivisionById(subDivisionId!).sdoUserId = u.id;
    }
    log('Added user (${role.label})', u.name);
    notifyListeners();
    return null;
  }

  void touch() => notifyListeners();
}
