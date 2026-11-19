/// Geographic tree: Company -> Circle -> Division -> Sub-division -> Feeder.
/// In reports, a Circle is treated as the "district" grouping.
class Circle {
  final String id;
  String name;
  Circle({required this.id, required this.name});
}

class Division {
  final String id;
  String name;
  final String circleId;
  Division({required this.id, required this.name, required this.circleId});
}

class SubDivision {
  final String id;
  String name;
  final String divisionId;

  /// The SDO responsible for this sub-division. Reports route to this user.
  String? sdoUserId;

  SubDivision({
    required this.id,
    required this.name,
    required this.divisionId,
    this.sdoUserId,
  });
}

class Feeder {
  final String id;
  String name;
  final String subDivisionId;
  int consumers;
  Feeder({
    required this.id,
    required this.name,
    required this.subDivisionId,
    required this.consumers,
  });
}
