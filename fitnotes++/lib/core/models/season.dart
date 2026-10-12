import 'package:characters/characters.dart';

import '../database/database.dart';

String initialsFromName(String name) =>
    name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).map((word) => word.characters.first).join().toUpperCase();

extension SeasonLabel on PrResetMarker {
  String get displayName => note?.trim().isNotEmpty == true ? note!.trim() : 'Season $id';
  String get displayInitials => initials?.trim().isNotEmpty == true ? initials!.trim() : initialsFromName(displayName);
}
