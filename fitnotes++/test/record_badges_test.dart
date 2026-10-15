import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitnotes_plus/core/database/database.dart';
import 'package:fitnotes_plus/core/providers.dart';
import 'package:fitnotes_plus/core/models/season.dart';
import 'package:fitnotes_plus/core/repositories/progress_repository.dart';
import 'package:fitnotes_plus/core/repositories/stats_repository.dart';
import 'package:fitnotes_plus/core/repositories/workout_repository.dart';

void main() {
  test('only each scope\'s best sets keep trophies, and completed seasons retain their winners', () async {
    final db = AppDatabase.memory();
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final exercise = (await db.select(db.exercises).get()).firstWhere((e) => e.name == 'Flat Barbell Bench Press');
    final repo = WorkoutRepository(db);
    final progress = ProgressRepository(db);
    final oldRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-01-01', rawWeight: 100, reps: 5);
    final seasonRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-03-01', rawWeight: 80, reps: 5);
    await progress.startSeason('2025-03-01', 'Spring training', initials: 'ST1');
    final subscription = container.listen(recordBadgesProvider(exercise.id), (_, _) {});
    addTearDown(subscription.close);
    await container.read(exerciseHistoryProvider(exercise.id).future);
    await container.read(exerciseProvider(exercise.id).future);
    await container.read(settingsProvider.future);
    await container.read(seasonsProvider.future);
    final spring = (await progress.watchSeasons().first).single;
    expect(container.read(recordBadgesProvider(exercise.id)), {
      oldRecord: (scope: RecordScope.allTime, season: null),
      seasonRecord: (scope: RecordScope.season, season: spring),
    });
    Future<Map<int, RecordAchievement>> refresh() async {
      container.invalidate(exerciseHistoryProvider(exercise.id));
      container.invalidate(seasonsProvider);
      await container.read(exerciseHistoryProvider(exercise.id).future);
      await container.read(seasonsProvider.future);
      return container.read(recordBadgesProvider(exercise.id));
    }

    final newRecord = await repo.addSet(exerciseId: exercise.id, date: '2025-03-02', rawWeight: 110, reps: 5);
    final springBest = {newRecord: (scope: RecordScope.allTime, season: null)};
    expect(await refresh(), springBest, reason: '110 replaces both the old all-time and weaker Spring records');
    await progress.startSeason('2025-04-01', 'Summer strength');
    expect(await refresh(), springBest, reason: 'Starting a season must keep the completed season\'s best');
    final summer = (await progress.watchSeasons().first).first;
    final firstSummer = await repo.addSet(exerciseId: exercise.id, date: '2025-04-01', rawWeight: 70, reps: 5);
    final betterSummer = await repo.addSet(exerciseId: exercise.id, date: '2025-04-02', rawWeight: 90, reps: 5);
    expect(await refresh(), {...springBest, betterSummer: (scope: RecordScope.season, season: summer)});
    final newAllTime = await repo.addSet(exerciseId: exercise.id, date: '2025-04-03', rawWeight: 120, reps: 5);
    await repo.addSet(exerciseId: exercise.id, date: '2025-04-04', rawWeight: 200, reps: 5, planned: true);
    expect(await refresh(), {
      newRecord: (scope: RecordScope.season, season: spring),
      newAllTime: (scope: RecordScope.allTime, season: null),
    });
    expect(spring.displayInitials, 'ST1');
    expect(summer.displayInitials, 'SS');
    expect((await db.select(db.workoutSets).get()).length, 7);
    await repo.deleteSet(newAllTime);
    expect(await refresh(), {...springBest, betterSummer: (scope: RecordScope.season, season: summer)});
    await repo.updateSet(betterSummer, rawWeight: 60);
    expect(await refresh(), {...springBest, firstSummer: (scope: RecordScope.season, season: summer)});
    await db.update(db.appSettings).write(const AppSettingsCompanion(trackPersonalRecords: Value(false)));
    container.invalidate(settingsProvider);
    await container.read(settingsProvider.future);
    expect(container.read(recordBadgesProvider(exercise.id)), isEmpty);
  });
}
