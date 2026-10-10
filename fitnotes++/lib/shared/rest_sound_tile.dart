import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/device_service.dart';
import 'widgets.dart';

final restSoundNameProvider = FutureProvider.autoDispose.family<String, String?>((ref, uri) async {
  if (uri == null) return 'Soft chime';
  return await DeviceService.call<String>('restSoundName', {'uri': uri}) ?? 'Device sound';
});

class RestSoundTile extends ConsumerStatefulWidget {
  const RestSoundTile({
    super.key,
    required this.uri,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.showIcon = true,
  });
  final String? uri;
  final ValueChanged<String?>? onChanged;
  final EdgeInsetsGeometry padding;
  final bool showIcon;
  @override
  ConsumerState<RestSoundTile> createState() => _RestSoundTileState();
}

class _RestSoundTileState extends ConsumerState<RestSoundTile> {
  bool _previewing = false;

  @override
  void dispose() {
    if (_previewing) unawaited(DeviceService.call('stopRestSoundPreview'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: ListTile(
      contentPadding: widget.padding,
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      leading: widget.showIcon ? Icon(Icons.music_note_outlined, size: 22, color: Theme.of(context).colorScheme.primary) : null,
      title: const Text('Rest sound', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
        ref.watch(restSoundNameProvider(widget.uri)).asData?.value ?? 'Device sound',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: widget.onChanged == null ? null : _choose,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _previewing ? 'Stop sound preview' : 'Preview rest sound',
            onPressed: _preview,
            icon: Icon(_previewing ? Icons.stop_rounded : Icons.volume_up_outlined),
          ),
          const Icon(Icons.chevron_right_rounded, size: 19),
        ],
      ),
    ),
  );

  Future<void> _preview() async {
    if (_previewing) {
      await DeviceService.call('stopRestSoundPreview');
      return;
    }
    setState(() => _previewing = true);
    await attempt(context, () async {
      await DeviceService.call('previewRestSound', {'uri': widget.uri});
    });
    if (mounted) setState(() => _previewing = false);
  }

  Future<void> _choose() async {
    await DeviceService.call('stopRestSoundPreview');
    if (!mounted) return;
    final source = await showDialog<int>(
      context: context,
      builder: (context) => AppDialog(
        title: const Text('Rest sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Soft chime'),
              trailing: widget.uri == null ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, 0),
            ),
            if (DeviceService.nativeTimers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Device sounds'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, 1),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Plays for up to 5 seconds.', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    if (source == 0) {
      widget.onChanged?.call(null);
    } else {
      await attempt(context, () async {
        final uri = await DeviceService.call<String>('pickRestSound', {'uri': widget.uri});
        if (mounted && uri != null) widget.onChanged?.call(uri);
      });
    }
  }
}
