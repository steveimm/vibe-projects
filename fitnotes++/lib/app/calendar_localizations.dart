import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CalendarLocalizations extends DefaultMaterialLocalizations {
  const CalendarLocalizations(this.weekStart);
  final int weekStart;
  @override
  int get firstDayOfWeekIndex => weekStart % 7;
}

class CalendarLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const CalendarLocalizationsDelegate(this.weekStart);
  final int weekStart;
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(CalendarLocalizations(weekStart));
  @override
  bool shouldReload(CalendarLocalizationsDelegate old) => weekStart != old.weekStart;
}
