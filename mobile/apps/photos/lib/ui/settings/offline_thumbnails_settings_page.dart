import 'dart:async';

import 'package:ente_components/ente_components.dart';
import 'package:flutter/material.dart';
import 'package:photos/services/offline_thumbnails_service.dart';

class OfflineThumbnailsSettingsPage extends StatefulWidget {
  const OfflineThumbnailsSettingsPage({super.key});

  @override
  State<OfflineThumbnailsSettingsPage> createState() =>
      _OfflineThumbnailsSettingsPageState();
}

class _OfflineThumbnailsSettingsPageState
    extends State<OfflineThumbnailsSettingsPage> {
  final _service = OfflineThumbnailsService.instance;
  late Future<int> _budgetFuture;
  OfflineThumbnailProgress? _progress;
  int? _budgetBytes;
  bool _isRunning = false;

  static const _budgets = [1, 2, 4, 8, 16];

  @override
  void initState() {
    super.initState();
    _budgetFuture = _service.getBudgetBytes();
    unawaited(_loadProgress());
  }

  Future<void> _loadProgress() async {
    final progress = await _service.getProgress();
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  Future<void> _start() async {
    final budget = _budgetBytes;
    if (budget == null) return;
    setState(() => _isRunning = true);
    try {
      final progress = await _service.pinAll(
        budgetBytes: budget,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) setState(() => _progress = progress);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cache thumbnails: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
      unawaited(_loadProgress());
    }
  }

  Future<void> _clear() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove offline thumbnails?'),
        content: const Text(
          'This deletes the persistent thumbnail copies. Your Ente originals and backups are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    await _service.clearAll();
    await _loadProgress();
  }

  Future<void> _setBudget(int gib) async {
    final bytes = gib * 1024 * 1024 * 1024;
    await _service.setBudgetBytes(bytes);
    if (mounted) setState(() => _budgetBytes = bytes);
  }

  String _size(int bytes) =>
      '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';

  @override
  Widget build(BuildContext context) => SettingsPageScaffold(
    title: 'Keep thumbnails offline',
    children: [
      const Text(
        'Save remote thumbnails on this device for offline browsing. This does not download originals; opening a full-resolution photo still needs the original file.',
      ),
      const SizedBox(height: 20),
      FutureBuilder<int>(
        future: _budgetFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData && _budgetBytes == null) {
            _budgetBytes = snapshot.data;
          }
          final current = _budgetBytes ?? snapshot.data;
          if (current == null) return const LinearProgressIndicator();
          final selectedGib = _budgets.firstWhere(
            (gib) => gib * 1024 * 1024 * 1024 >= current,
            orElse: () => _budgets.last,
          );
          return Row(
            children: [
              const Expanded(child: Text('Maximum storage')),
              DropdownButton<int>(
                value: selectedGib,
                items: [
                  for (final gib in _budgets)
                    DropdownMenuItem(value: gib, child: Text('$gib GB')),
                ],
                onChanged: _isRunning || _budgetBytes == null
                    ? null
                    : (gib) {
                        if (gib != null) unawaited(_setBudget(gib));
                      },
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      if (_progress != null) ...[
        LinearProgressIndicator(
          value: _progress!.total == 0
              ? null
              : (_progress!.processed / _progress!.total)
                    .clamp(0.0, 1.0)
                    .toDouble(),
        ),
        const SizedBox(height: 12),
        Text(
          _isRunning
              ? 'Processed ${_progress!.processed} of ${_progress!.total}'
              : '${_progress!.pinned} thumbnails saved • ${_size(_progress!.bytes)}',
        ),
        if (_progress!.skippedForBudget > 0)
          Text('${_progress!.skippedForBudget} exceeded the storage cap.'),
        if (_progress!.failed > 0)
          Text(
            '${_progress!.failed} could not be downloaded; resume to retry.',
          ),
      ],
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _isRunning ? null : _start,
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(_isRunning ? 'Saving…' : 'Start / resume'),
          ),
          if (_isRunning)
            OutlinedButton(onPressed: _service.stop, child: const Text('Stop')),
          TextButton(
            onPressed: _isRunning || (_progress?.bytes ?? 0) == 0
                ? null
                : _clear,
            child: const Text('Remove saved thumbnails'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'This can take hours for a large library and uses your current internet connection. Downloads run one thumbnail at a time while this screen is open. If the app closes, start again later to resume. The operating system may still remove Ente’s ordinary temporary cache; these saved copies are kept separately.',
      ),
    ],
  );
}
