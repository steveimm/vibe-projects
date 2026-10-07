import '../database/database.dart';

class SettingsRepository {
  SettingsRepository(this.db);

  final AppDatabase db;

  Stream<AppSettingsRow> watch() => (db.select(db.appSettings)..where((s) => s.id.equals(1))).watchSingle();

  Future<void> update(AppSettingsCompanion changes) => (db.update(db.appSettings)..where((s) => s.id.equals(1))).write(changes);
}
