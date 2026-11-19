import '../core/enums.dart';

class Transformer {
  final String id;
  final String code; // e.g. TX-ISB-0001
  int kva;
  final String feederId;
  String location;
  double lat;
  double lng;
  DateTime installDate;
  TransformerStatus status;
  final List<String> history;

  Transformer({
    required this.id,
    required this.code,
    required this.kva,
    required this.feederId,
    required this.location,
    required this.installDate,
    this.lat = 0,
    this.lng = 0,
    this.status = TransformerStatus.active,
    List<String>? history,
  }) : history = history ?? [];
}
