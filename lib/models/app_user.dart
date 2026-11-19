import '../core/enums.dart';

class AppUser {
  final String id;
  String name;
  final UserRole role;
  String phone;

  /// Scope: an SDO has a subDivisionId, an XEN a divisionId, an SE a circleId.
  final String? circleId;
  final String? divisionId;
  final String? subDivisionId;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.circleId,
    this.divisionId,
    this.subDivisionId,
  });
}
