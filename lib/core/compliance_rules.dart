import 'package:flutter/foundation.dart';
import 'enums.dart';

/// Configurable time limits. Nothing here is hard-coded into the workflow:
/// every check reads these values, and an Admin can edit them in the app.
///
/// IMPORTANT: the defaults below are PLACEHOLDERS. Replace them with the
/// limits from the NEPRA Distribution Performance Standards and IESCO's own
/// internal rules before any real use.
class ComplianceRules extends ChangeNotifier {
  /// Maximum allowed restoration time per outage type, in minutes.
  final Map<OutageType, int> restorationLimitMinutes = {
    OutageType.planned: 480,
    OutageType.forced: 240,
    OutageType.fault: 240,
    OutageType.loadShedding: 360,
  };

  /// An open outage older than this is escalated to the XEN.
  int escalateToXenMinutes = 180;

  /// An open outage older than this is escalated to the SE.
  int escalateToSeMinutes = 360;

  /// Time limit for a standard installation job, in days.
  int installJobLimitDays = 30;

  /// Time limit for replacing a failed transformer, in hours.
  int failureReplacementLimitHours = 72;

  int restorationLimitFor(OutageType t) => restorationLimitMinutes[t] ?? 240;

  Duration installLimitFor(InstallReason reason) =>
      reason == InstallReason.failure
          ? Duration(hours: failureReplacementLimitHours)
          : Duration(days: installJobLimitDays);

  void setRestorationLimit(OutageType t, int minutes) {
    restorationLimitMinutes[t] = minutes;
    notifyListeners();
  }

  void update({
    int? escalateXen,
    int? escalateSe,
    int? installDays,
    int? failureHours,
  }) {
    if (escalateXen != null) escalateToXenMinutes = escalateXen;
    if (escalateSe != null) escalateToSeMinutes = escalateSe;
    if (installDays != null) installJobLimitDays = installDays;
    if (failureHours != null) failureReplacementLimitHours = failureHours;
    notifyListeners();
  }
}
