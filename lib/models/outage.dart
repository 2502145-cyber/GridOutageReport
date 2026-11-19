import '../core/enums.dart';

class Outage {
  final String id; // e.g. OUT-2026-0001
  final String feederId;
  final String subDivisionId;
  final OutageType type;
  String cause; // reported cause
  String description;
  final DateTime startTime;
  DateTime? endTime; // restoration time
  OutageStatus status;
  int consumersAffected;
  final String reportedBy; // user id
  String? crew;
  String? causeFound;
  String? actionTaken;
  EscalationLevel escalation;
  final List<OutageEvent> timeline;

  Outage({
    required this.id,
    required this.feederId,
    required this.subDivisionId,
    required this.type,
    required this.cause,
    required this.description,
    required this.startTime,
    required this.consumersAffected,
    required this.reportedBy,
    this.endTime,
    this.status = OutageStatus.reported,
    this.crew,
    this.causeFound,
    this.actionTaken,
    this.escalation = EscalationLevel.none,
    List<OutageEvent>? timeline,
  }) : timeline = timeline ?? [];

  /// Total outage duration. For an open outage this runs up to [now].
  Duration duration(DateTime now) => (endTime ?? now).difference(startTime);

  bool get isOpen => status.isOpen;
}

class OutageEvent {
  final DateTime time;
  final String text;
  final String by;
  OutageEvent({required this.time, required this.text, required this.by});
}
