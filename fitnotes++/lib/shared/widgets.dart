import 'package:flutter/material.dart';

class AppDialog extends AlertDialog {
  const AppDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.scrollable = true,
    super.contentPadding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
  }) : super(titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0), buttonPadding: const EdgeInsets.symmetric(horizontal: 4));
}

class AppMenuButton<T> extends PopupMenuButton<T> {
  const AppMenuButton({
    super.key,
    required super.itemBuilder,
    super.onSelected,
    super.tooltip,
    super.icon,
    super.iconColor,
    super.enabled = true,
    super.padding = const EdgeInsets.all(8),
  }) : super(constraints: const BoxConstraints.tightFor(width: 240));
}

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child),
  );
}

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Entrance(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: 'Could not load data',
    action: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  );
}

class StatValue extends StatelessWidget {
  const StatValue(this.label, this.value, {super.key, this.inverse = false, this.centered = false});
  final String label;
  final String value;
  final bool inverse;
  final bool centered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: centered ? const EdgeInsets.symmetric(horizontal: 5) : const EdgeInsets.only(right: 10),
    child: Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
              child: Text(
                value,
                key: ValueKey(value),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: inverse ? Colors.white : Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: inverse ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

void notice(BuildContext context, String message, {SnackBarAction? action}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: Duration(seconds: action == null ? 4 : 8),
        persist: false,
        showCloseIcon: action != null && MediaQuery.accessibleNavigationOf(context),
      ),
    );
}

Future<bool> attempt(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) notice(context, success);
    return true;
  } catch (error) {
    if (context.mounted) {
      notice(context, error is FormatException ? error.message : 'Could not save the change. Please try again.');
    }
    return false;
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String action = 'Delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

Future<String?> prompt(
  BuildContext context, {
  required String title,
  required String label,
  String value = '',
  bool optional = false,
  int lines = 1,
  int maxLength = 120,
  TextInputType? keyboard,
  String? Function(String)? validate,
}) => showDialog<String>(
  context: context,
  builder: (_) => _Prompt(
    title: title,
    label: label,
    value: value,
    optional: optional,
    lines: lines,
    maxLength: maxLength,
    keyboard: keyboard,
    validate: validate,
  ),
);

class _Prompt extends StatefulWidget {
  const _Prompt({
    required this.title,
    required this.label,
    required this.value,
    required this.optional,
    required this.lines,
    required this.maxLength,
    this.keyboard,
    this.validate,
  });
  final String title, label, value;
  final bool optional;
  final int lines, maxLength;
  final TextInputType? keyboard;
  final String? Function(String)? validate;
  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  late final _controller = TextEditingController(text: widget.value);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        minLines: widget.lines,
        maxLines: widget.lines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboard,
        textCapitalization: widget.keyboard == null ? TextCapitalization.sentences : TextCapitalization.none,
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
        onFieldSubmitted: (_) => _save(),
        validator: (value) =>
            value!.trim().isEmpty && !widget.optional ? 'This field is required.' : widget.validate?.call(value.trim()),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
