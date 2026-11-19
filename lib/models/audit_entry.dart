class AuditEntry {
  final DateTime time;
  final String userName;
  final String action;
  final String entityId;
  AuditEntry({
    required this.time,
    required this.userName,
    required this.action,
    required this.entityId,
  });
}

class AppNotification {
  final String id;
  final String toUserId;
  final String message;
  final DateTime time;
  final String? entityId;
  bool read;
  AppNotification({
    required this.id,
    required this.toUserId,
    required this.message,
    required this.time,
    this.entityId,
    this.read = false,
  });
}
