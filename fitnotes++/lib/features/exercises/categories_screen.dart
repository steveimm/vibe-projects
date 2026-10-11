import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

const categoryPalette = [
  0xFF326A59,
  0xFF4478AF,
  0xFF9C713D,
  0xFFBC6056,
  0xFF8465A3,
  0xFF40858C,
  0xFF7A843C,
  0xFF616D7A,
  0xFFB35E88,
];

Future<int?> editCategory(BuildContext context, {Category? category}) => showDialog<int>(
  context: context,
  builder: (_) => _CategoryDialog(category: category),
);

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Categories')),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: AppFloatingActionButton(tooltip: 'Add category', onPressed: () => editCategory(context)),
    body: ContentWidth(
      child: ref
          .watch(categoriesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorState(onRetry: () => ref.invalidate(categoriesProvider)),
            data: (categories) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final c = categories[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(radius: 10, backgroundColor: Color(c.colorArgb)),
                    title: Text(c.name),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => editCategory(context, category: c),
                  ),
                );
              },
            ),
          ),
    ),
  );
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.category});
  final Category? category;
  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.category?.name);
  late int _color = widget.category?.colorArgb ?? categoryPalette.first;
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.category == null ? 'New category' : 'Edit category'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => v!.trim().isEmpty ? 'Enter a category name.' : null,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in {...categoryPalette, _color})
                Semantics(
                  label: 'Category color ${color.toRadixString(16)}',
                  selected: _color == color,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _color = color),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(color),
                          child: _color == color ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      if (widget.category != null) TextButton(onPressed: _busy ? null : _delete, child: const Text('Delete')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
    ],
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    int? id = widget.category?.id;
    final success = await attempt(context, () async {
      final repo = ref.read(exerciseRepositoryProvider);
      final categories = await repo.getCategories();
      if (categories.any((c) => c.id != id && c.name.toLowerCase() == _name.text.trim().toLowerCase())) {
        throw const FormatException('A category with this name already exists.');
      }
      if (id == null) {
        id = await repo.createCategory(name: _name.text.trim(), colorArgb: _color);
      } else {
        await repo.updateCategory(id!, _name.text, _color);
      }
    });
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, id);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, title: 'Delete category?', message: 'Only categories with no exercises can be removed.') ||
        !mounted) {
      return;
    }
    final success = await attempt(context, () => ref.read(exerciseRepositoryProvider).deleteCategory(widget.category!.id));
    if (success && mounted) Navigator.pop(context);
  }
}
