enum UserRole { reporter, sdo, xen, se, headOffice, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.reporter:
        return 'Reporter';
      case UserRole.sdo:
        return 'SDO (Sub-Division)';
      case UserRole.xen:
        return 'XEN (Division)';
      case UserRole.se:
        return 'SE (Circle)';
      case UserRole.headOffice:
        return 'Head Office';
      case UserRole.admin:
        return 'Admin';
    }
  }

  /// Roles allowed to act on outages and jobs (assign, update, close).
  bool get canManage =>
      this == UserRole.sdo ||
      this == UserRole.xen ||
      this == UserRole.se ||
      this == UserRole.admin;

  bool get seesAllAreas =>
      this == UserRole.headOffice || this == UserRole.admin;
}

enum OutageType { planned, forced, fault, loadShedding }

extension OutageTypeX on OutageType {
  String get label {
    switch (this) {
      case OutageType.planned:
        return 'Planned';
      case OutageType.forced:
        return 'Forced';
      case OutageType.fault:
        return 'Fault';
      case OutageType.loadShedding:
        return 'Load-shedding';
    }
  }
}

enum OutageStatus { reported, assigned, inProgress, restored, closed }

extension OutageStatusX on OutageStatus {
  String get label {
    switch (this) {
      case OutageStatus.reported:
        return 'Reported';
      case OutageStatus.assigned:
        return 'Assigned';
      case OutageStatus.inProgress:
        return 'In progress';
      case OutageStatus.restored:
        return 'Restored';
      case OutageStatus.closed:
        return 'Closed';
    }
  }

  bool get isOpen =>
      this == OutageStatus.reported ||
      this == OutageStatus.assigned ||
      this == OutageStatus.inProgress;
}

enum EscalationLevel { none, xen, se }

extension EscalationLevelX on EscalationLevel {
  String get label {
    switch (this) {
      case EscalationLevel.none:
        return 'None';
      case EscalationLevel.xen:
        return 'Escalated to XEN';
      case EscalationLevel.se:
        return 'Escalated to SE';
    }
  }
}

enum InstallReason { newConnectionLoad, overload, failure, replacement }

extension InstallReasonX on InstallReason {
  String get label {
    switch (this) {
      case InstallReason.newConnectionLoad:
        return 'New connection load';
      case InstallReason.overload:
        return 'Overload';
      case InstallReason.failure:
        return 'Transformer failure';
      case InstallReason.replacement:
        return 'Replacement';
    }
  }

  /// Counts as a "replaced" transformer in reports (vs. newly installed).
  bool get isReplacement =>
      this == InstallReason.failure || this == InstallReason.replacement;
}

enum InstallStage {
  requested,
  survey,
  approval,
  materialIssued,
  installation,
  testing,
  commissioned,
}

extension InstallStageX on InstallStage {
  String get label {
    switch (this) {
      case InstallStage.requested:
        return 'Requested';
      case InstallStage.survey:
        return 'Survey';
      case InstallStage.approval:
        return 'Approval';
      case InstallStage.materialIssued:
        return 'Material issued';
      case InstallStage.installation:
        return 'Installation';
      case InstallStage.testing:
        return 'Testing';
      case InstallStage.commissioned:
        return 'Commissioned';
    }
  }

  InstallStage? get next {
    final i = InstallStage.values.indexOf(this);
    if (i + 1 >= InstallStage.values.length) return null;
    return InstallStage.values[i + 1];
  }

  /// Stages that must carry at least one photo/attachment.
  bool get requiresPhoto =>
      this == InstallStage.installation || this == InstallStage.testing;
}

enum TransformerStatus { active, failed, underMaintenance, decommissioned }

extension TransformerStatusX on TransformerStatus {
  String get label {
    switch (this) {
      case TransformerStatus.active:
        return 'Active';
      case TransformerStatus.failed:
        return 'Failed';
      case TransformerStatus.underMaintenance:
        return 'Under maintenance';
      case TransformerStatus.decommissioned:
        return 'Decommissioned';
    }
  }
}
