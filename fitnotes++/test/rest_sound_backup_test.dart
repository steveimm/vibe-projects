import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/services/backup_service.dart';

void main() {
  test('selected sound survives backup and restoring version 4 resets it to the bundled chime', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final folder = Directory.systemTemp.createTempSync('fitnotes-sound-');
    addTearDown(() => folder.deleteSync(recursive: true));
    await db.select(db.appSettings).get();
    const uri = 'content://media/internal/audio/media/42';
    await db.update(db.appSettings).write(const AppSettingsCompanion(restTimerSoundUri: Value(uri)));
    final backup = File('${folder.path}/sound.fitnotesplus')..writeAsBytesSync(await BackupService(db).backup(directory: folder));
    await db.update(db.appSettings).write(const AppSettingsCompanion(restTimerSoundUri: Value(null)));
    await BackupService(db).restore(backup.path);
    expect((await db.select(db.appSettings).getSingle()).restTimerSoundUri, uri);
    final old = backup.copySync('${folder.path}/v4.fitnotesplus');
    final raw = sqlite.sqlite3.open(old.path);
    raw.execute('ALTER TABLE app_settings DROP COLUMN rest_timer_sound_uri');
    raw.execute('ALTER TABLE exercises DROP COLUMN weight_unit');
    raw.execute('PRAGMA user_version = 4');
    raw.close();
    final migrated = AppDatabase(NativeDatabase(old.copySync('${folder.path}/migrate.sqlite')));
    addTearDown(migrated.close);
    expect((await migrated.select(migrated.appSettings).getSingle()).restTimerSoundUri, isNull);
    await BackupService(db).restore(old.path);
    expect((await db.select(db.appSettings).getSingle()).restTimerSoundUri, isNull);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
