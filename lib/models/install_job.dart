import '../core/enums.dart';

/// One completed stage of an installation job: who did it, when, and the
/// mandatory notes/attachments captured at that stage.
class StageRecord {
  final InstallStage stage;
  final DateTime time;
  final String officer;
  final String notes;
  final List<String> attachments;
  StageRecord({
    required this.stage,
    required this.time,
    required this.officer,
    required this.notes,
    this.attachments = const [],
  });
}

class InstallJob {
  final String id; // e.g. INS-2026-0001
  final String feederId;
  final String subDivisionId;
  String transformerCode;
  int kva;
  String location;
  final InstallReason reason;
  InstallStage stage;
  final DateTime createdAt;
  DateTime? completedAt;
  final String createdBy;
  final List<StageRecord> records;

  InstallJob({
    required this.id,
    required this.feederId,
    required this.subDivisionId,
    required this.transformerCode,
    required this.kva,
    required this.location,
    required this.reason,
    required this.createdAt,
    required this.createdBy,
    this.stage = InstallStage.requested,
    this.completedAt,
    List<StageRecord>? records,
  }) : records = records ?? [];

  bool get isComplete => stage == InstallStage.commissioned;

  StageRecord? recordFor(InstallStage s) {
    for (final r in records) {
      if (r.stage == s) return r;
    }
    return null;
  }
}
