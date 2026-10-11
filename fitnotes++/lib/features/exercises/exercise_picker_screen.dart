import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/repositories/exercise_repository.dart';
import '../../shared/widgets.dart';

final _pickerExercisesProvider = StreamProvider.autoDispose
    .family<List<ExerciseListItem>, ({String search, int? category, bool archived, bool favourites})>(
      (ref, key) => ref
          .watch(exerciseRepositoryProvider)
          .watchExercises(search: key.search, categoryId: key.category, archived: key.archived, favourites: key.favourites),
    );

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key, required this.date, this.returnSelection = false});
  final String date;
  final bool returnSelection;
  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int? _category;
  bool _favourites = false, _archived = false;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showBodyParts() {
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _category = null;
      _favourites = false;
      _archived = false;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(categoriesProvider)
      .when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Body part')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Body part')),
          body: ErrorState(onRetry: () => ref.invalidate(categoriesProvider)),
        ),
        data: (categories) {
          final category = categories.where((c) => c.id == _category).firstOrNull;
          final filtered = _search.text.isNotEmpty || _favourites || _archived;
          return PopScope(
            canPop: category == null && !filtered,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _showBodyParts();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(category?.name ?? 'Body part'),
                leading: category == null ? null : BackButton(onPressed: _showBodyParts),
                actions: [
                  if (!_archived)
                    IconButton(
                      tooltip: 'Favorites only',
                      icon: Icon(_favourites ? Icons.star_rounded : Icons.star_outline_rounded),
                      color: _favourites ? const Color(0xFFAA762E) : null,
                      onPressed: () => setState(() => _favourites = !_favourites),
                    ),
                  AppMenuButton<String>(
                    tooltip: 'Exercise options',
                    onSelected: (value) {
                      if (value == 'categories') {
                        context.push('/categories');
                      } else {
                        setState(() {
                          _archived = !_archived;
                          _favourites = false;
                        });
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'categories', child: Text('Manage body parts')),
                      PopupMenuItem(
                        value: 'archived',
                        child: Text(_archived ? 'Show active exercises' : 'Show archived exercises'),
                      ),
                    ],
                  ),
                ],
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              floatingActionButton: _archived ? null : AppFloatingActionButton(tooltip: 'Create exercise', onPressed: _create),
              body: ContentWidth(child: _pickerContent(categories, category)),
            ),
          );
        },
      );

  Widget _bodyParts(List<Category> categories) => categories.isEmpty
      ? const Center(child: Text('No body parts'))
      : ListView.separated(
          key: const PageStorageKey('body-parts'),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, index) {
            final category = categories[index];
            return Card(
              child: ListTile(
                minTileHeight: 48,
                minVerticalPadding: 4,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: CircleAvatar(radius: 10, backgroundColor: Color(category.colorArgb)),
                title: Text(category.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _category = category.id),
              ),
            );
          },
        );

  Widget _pickerContent(List<Category> categories, Category? category) {
    final showBodyParts = category == null && _search.text.trim().isEmpty && !_favourites && !_archived;
    final key = (search: _search.text, category: category?.id, archived: _archived, favourites: _favourites);
    final data = showBodyParts ? null : ref.watch(_pickerExercisesProvider(key));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _archived ? 'Search archived exercises' : 'Search exercises',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: showBodyParts
              ? _bodyParts(categories)
              : data!.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => ErrorState(onRetry: () => ref.invalidate(_pickerExercisesProvider(key))),
                  data: (exercises) => exercises.isEmpty
                      ? Center(
                          child: Text(
                            _archived
                                ? 'No archived exercises'
                                : _favourites
                                ? 'No favorites'
                                : 'No matching exercises',
                          ),
                        )
                      : ListView.separated(
                          key: ValueKey(category?.id),
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          itemCount: exercises.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final exercise = exercises[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                minTileHeight: 56,
                                minVerticalPadding: 8,
                                title: Text(exercise.name),
                                trailing: _archived
                                    ? IconButton(
                                        tooltip: 'Restore exercise',
                                        icon: const Icon(Icons.unarchive_outlined),
                                        onPressed: () => attempt(
                                          context,
                                          () => ref.read(exerciseRepositoryProvider).setArchived(exercise.id, false),
                                        ),
                                      )
                                    : IconButton(
                                        tooltip: exercise.isFavourite ? 'Remove from favorites' : 'Add to favorites',
                                        icon: Icon(exercise.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded),
                                        color: exercise.isFavourite
                                            ? const Color(0xFFAA762E)
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                        onPressed: () => attempt(
                                          context,
                                          () => ref
                                              .read(exerciseRepositoryProvider)
                                              .setFavourite(exercise.id, !exercise.isFavourite),
                                        ),
                                      ),
                                onTap: _archived ? null : () => _open(exercise.id),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final id = await context.push<int>('/exercises/edit${_category == null ? '' : '?category=$_category'}');
    if (id == null || !mounted) return;
    if (!widget.returnSelection) {
      final exercise = await ref.read(exerciseRepositoryProvider).watchExercise(id).first;
      if (!mounted) return;
      setState(() {
        _category = exercise.categoryId;
        _search.clear();
        _favourites = false;
        _archived = false;
      });
    }
    _open(id);
  }

  void _open(int id) {
    FocusScope.of(context).unfocus();
    if (widget.returnSelection) {
      context.pop(id);
    } else {
      context.push('/log/$id?date=${widget.date}&returnToWorkout=1');
    }
  }
}
