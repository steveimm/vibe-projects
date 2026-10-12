import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/database.dart';
import '../database/tables.dart';
import '../util/format.dart';

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static const tables = [
    'categories',
    'exercises',
    'exercise_multipliers',
    'workout_sets',
    'workout_day_notes',
    'pr_reset_markers',
    'app_settings',
    'routines',
    'routine_days',
    'routine_sets',
    'measurement_types',
    'measurements',
    'exercise_goals',
    'workout_sessions',
    'workout_exercise_orders',
  ];

  static Iterable<String> _tablesForVersion(int version) =>
      tables.where((table) => version >= 4 || table != 'workout_exercise_orders');

  Future<Uint8List> backup({Directory? directory}) async {
    final dir = directory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/fitnotes-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    try {
      await db.customStatement('VACUUM INTO ?', [file.path]);
      return await file.readAsBytes();
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<Map<String, int>> inspect(String path) async {
    final source = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    try {
      final version = source.select('PRAGMA user_version').single.values.first as int;
      if (version < 2 || version > db.schemaVersion) {
        throw const FormatException(
          'This is not a supported FitNotes++ backup. Use Import FitNotes for an original .fitnotes file.',
        );
      }
      if (source.select('PRAGMA quick_check').single.values.first != 'ok') throw const FormatException('The backup is damaged.');
      final names = source.select("SELECT name FROM sqlite_master WHERE type = 'table'").map((r) => r['name']).toSet();
      for (final table in db.allTables) {
        if (!_tablesForVersion(version).contains(table.actualTableName)) continue;
        final columns = source.select('PRAGMA table_info("${table.actualTableName}")').map((r) => r['name']).toSet();
        final expected = table.$columns.map((c) => c.$name).toSet();
        if (version < 6 && table.actualTableName == 'exercises') expected.remove('weight_unit');
        if (version < 7 && table.actualTableName == 'exercises') expected.remove('include_bodyweight');
        if (version < 7 && table.actualTableName == 'workout_sets') expected.remove('bodyweight');
        if (version < 8 && table.actualTableName == 'workout_sets') expected.remove('logged_at');
        if (version < 5 && table.actualTableName == 'app_settings') expected.remove('rest_timer_sound_uri');
        if (version == 2 && table.actualTableName == 'workout_sessions') {
          expected.removeAll(['elapsed_seconds', 'running_since']);
        }
        if (!expected.every(columns.contains) || columns.length != expected.length) {
          throw const FormatException('The backup schema is incompatible with this app version.');
        }
      }
      if (!_tablesForVersion(version).every(names.contains)) throw const FormatException('The backup is missing required data.');
      if (source.select('SELECT id FROM app_settings').length != 1 ||
          source.select('SELECT id FROM app_settings').single['id'] != 1) {
        throw const FormatException('The backup has invalid settings.');
      }
      if (source.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const FormatException('The backup contains broken exercise or routine references.');
      }
      return {
        for (final table in _tablesForVersion(version))
          table: source.select('SELECT COUNT(*) AS n FROM "$table"').single['n'] as int,
      };
    } on sqlite.SqliteException {
      throw const FormatException('Choose a valid FitNotes++ backup file.');
    } finally {
      source.close();
    }
  }

  Future<void> restore(String path) async {
    await inspect(path);
    final source = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    try {
      final version = source.select('PRAGMA user_version').single.values.first as int;
      final rows = {
        for (final table in tables)
          table: _tablesForVersion(version).contains(table)
              ? source.select('SELECT * FROM "$table"').map((r) => Map<String, Object?>.from(r)).toList()
              : <Map<String, Object?>>[],
      };
      if (version == 2) {
        for (final session in rows['workout_sessions']!) {
          final end = session['ended_at'] as int?;
          final start = session['started_at'] as int;
          session['elapsed_seconds'] = end == null ? 0 : (end - start).clamp(0, 2147483647);
          session['running_since'] = end == null ? start : null;
        }
      }
      await db.transaction(() async {
        for (final table in tables.reversed) {
          await db.customStatement('DELETE FROM "$table"');
        }
        for (final table in tables) {
          for (final row in rows[table]!) {
            final columns = row.keys.map((k) => '"$k"').join(',');
            final slots = List.filled(row.length, '?').join(',');
            await db.customStatement('INSERT INTO "$table" ($columns) VALUES ($slots)', row.values.toList());
          }
        }
      });
      db.markTablesUpdated(db.allTables);
    } finally {
      source.close();
    }
  }

  Future<Uint8List> csv() async {
    final rows = await db.customSelect('''
      SELECT s.*, e.name AS exercise, c.name AS category, e.type AS type
      FROM workout_sets s JOIN exercises e ON e.id=s.exercise_id JOIN categories c ON c.id=e.category_id
      WHERE s.is_planned=0 ORDER BY s.date,s.created_at,s.id
    ''').get();
    final csv = StringBuffer('Date,Exercise,Category,Weight,Weight Unit,Reps,Distance,Distance Unit,Time,Comment\r\n');
    for (final row in rows) {
      final s = db.workoutSets.map(row.data);
      final type = ExerciseType.values[row.read<int>('type')];
      final values = <Object>[
        s.date,
        row.read<String>('exercise'),
        row.read<String>('category'),
        type.hasWeight ? Fmt.number(s.effectiveWeight, precision: 6) : '',
        type.hasWeight ? 'kgs' : '',
        type.hasReps ? s.reps : '',
        type.hasDistance ? Fmt.number(s.distance, precision: 6) : '',
        type.hasDistance ? 'm' : '',
        type.hasTime
            ? '${s.durationSeconds ~/ 3600}:${((s.durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s.durationSeconds % 60).toString().padLeft(2, '0')}'
            : '',
        s.note ?? '',
      ];
      csv.writeln(values.map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','));
    }
    return Uint8List.fromList(utf8.encode(csv.toString()));
  }
}
