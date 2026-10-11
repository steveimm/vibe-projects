import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';

void main() {
  test('all-time records remain gold across resets and take precedence over season records', () async {
    final db = AppDatabase.memory();
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final exercise = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
    final repo = WorkoutRepository(db);
    final oldRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-01-01', rawWeight: 100, reps: 5);
    final seasonRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-03-01', rawWeight: 80, reps: 5);
    final newRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-03-02', rawWeight: 110, reps: 5);
    await db.into(db.prResetMarkers).insert(PrResetMarkersCompanion.insert(date: '2025-03-01', createdAt: DateTime(2025, 3, 1)));
    final subscription = container.listen(recordBadgesProvider(exercise.id), (_, _) {});
    addTearDown(subscription.close);
    await container.read(exerciseHistoryProvider(exercise.id).future);
    await container.read(exerciseProvider(exercise.id).future);
    await container.read(settingsProvider.future);
    await container.read(seasonsProvider.future);
    expect(container.read(recordBadgesProvider(exercise.id)), {
      oldRecord: RecordScope.allTime,
      seasonRecord: RecordScope.currentSeason,
      newRecord: RecordScope.allTime,
    });
    await db.update(db.appSettings).write(const AppSettingsCompanion(trackPersonalRecords: Value(false)));
    container.invalidate(settingsProvider);
    await container.read(settingsProvider.future);
    expect(container.read(recordBadgesProvider(exercise.id)), isEmpty);
  });
}
