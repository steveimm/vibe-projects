import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/repositories/exercise_repository.dart';
import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../shared/widgets.dart';

final _libraryProvider = StreamProvider.autoDispose
    .family<List<ExerciseListItem>, ({String search, int? category, bool archived})>(
      (ref, key) => ref
          .watch(exerciseRepositoryProvider)
          .watchExercises(search: key.search, categoryId: key.category, archived: key.archived),
    );

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key, this.pickMode = false, this.date, this.returnSelection = false});
  final bool pickMode;
  final bool returnSelection;
  final String? date;
  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final _search = TextEditingController();
  int? _category;
  bool _favourites = false;
  bool _archived = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? [];
    final data = ref.watch(_libraryProvider((search: _search.text, category: _category, archived: _archived)));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Choose an exercise' : 'Exercises'),
        actions: [
          IconButton(tooltip: 'Create exercise', onPressed: _create, icon: const Icon(Icons.add_rounded)),
          if (!widget.pickMode)
            PopupMenuButton<String>(
              tooltip: 'Library options',
              onSelected: (action) {
                if (action == 'categories') {
                  context.push('/categories');
                } else {
                  setState(() {
                    _archived = !_archived;
                    _favourites = false;
                  });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'categories', child: Text('Manage categories')),
                PopupMenuItem(value: 'archived', child: Text(_archived ? 'Show active exercises' : 'Show archived exercises')),
              ],
            ),
        ],
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search exercises',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Favorites'),
                      avatar: const Icon(Icons.star_rounded, size: 16),
                      selected: _favourites,
                      onSelected: (v) => setState(() => _favourites = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        avatar: CircleAvatar(radius: 4, backgroundColor: Color(category.colorArgb)),
                        selected: _category == category.id,
                        onSelected: (_) => setState(() => _category = category.id),
                      ),
                    ),
                ],
              ),
            ),
            if (_archived)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Archived exercises remain in your history. Restore one to log it again.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ErrorState(onRetry: () => ref.invalidate(_libraryProvider)),
                data: (all) {
                  final list = all.where((e) => !_favourites || e.isFavourite).toList();
                  if (list.isEmpty) {
                    return SingleChildScrollView(
                      child: EmptyState(
                        icon: _favourites ? Icons.star_outline_rounded : Icons.search_rounded,
                        title: _archived
                            ? 'No archived exercises here'
                            : _favourites
                            ? 'No favorites'
                            : 'No matching exercises',
                        message: _archived
                            ? 'Change your search or return to your active exercise library.'
                            : _favourites
                            ? 'Tap the star beside an exercise to add it to favorites.'
                            : 'Try a different search or add your own exercise.',
                        action: _archived
                            ? TextButton(
                                onPressed: () => setState(() => _archived = false),
                                child: const Text('Back to active exercises'),
                              )
                            : TextButton.icon(
                                onPressed: _create,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create exercise'),
                              ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 14, right: 4),
                          minVerticalPadding: 12,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Color(e.colorArgb).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(Icons.fitness_center_rounded, size: 20, color: Color(e.colorArgb)),
                          ),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${e.categoryName} · ${e.workoutCount == 0 ? 'Not logged yet' : Fmt.count(e.workoutCount, 'workout')}',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                          ),
                          trailing: _archived
                              ? IconButton(
                                  tooltip: 'Restore exercise',
                                  icon: const Icon(Icons.unarchive_outlined),
                                  onPressed: () => attempt(
                                    context,
                                    () => ref.read(exerciseRepositoryProvider).setArchived(e.id, false),
                                    success: 'Exercise restored',
                                  ),
                                )
                              : IconButton(
                                  tooltip: e.isFavourite ? 'Remove from favorites' : 'Add to favorites',
                                  icon: Icon(
                                    e.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: e.isFavourite ? const Color(0xFFAA762E) : colors.onSurfaceVariant,
                                  ),
                                  onPressed: () => attempt(
                                    context,
                                    () => ref.read(exerciseRepositoryProvider).setFavourite(e.id, !e.isFavourite),
                                  ),
                                ),
                          onTap: () => _open(e.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final id = await context.push<int>('/exercises/edit${_category == null ? '' : '?category=$_category'}');
    if (id != null && mounted) _open(id);
  }

  void _open(int id) {
    if (widget.returnSelection) {
      context.pop(id);
      return;
    }
    final date = widget.date ?? ref.read(selectedDateProvider) ?? Dates.today();
    if (widget.pickMode) {
      context.pushReplacement('/log/$id?date=$date');
    } else {
      context.push('/log/$id?date=${date.isEmpty ? Dates.today() : date}');
    }
  }
}
