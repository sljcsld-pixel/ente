import 'dart:io';

import 'package:photos/db/files_db.dart';
import 'package:photos/models/file/file.dart';
import 'package:photos/models/file/extensions/file_props.dart';
import 'package:photos/module/download/thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineThumbnailProgress {
  const OfflineThumbnailProgress({
    required this.total,
    required this.processed,
    required this.pinned,
    required this.failed,
    required this.skippedForBudget,
    required this.bytes,
    required this.isRunning,
  });

  final int total;
  final int processed;
  final int pinned;
  final int failed;
  final int skippedForBudget;
  final int bytes;
  final bool isRunning;
}

/// Pins only Ente's encrypted-at-rest, decrypted thumbnail payloads. It never
/// invokes the original-file download code path.
class OfflineThumbnailsService {
  OfflineThumbnailsService._();

  static final OfflineThumbnailsService instance = OfflineThumbnailsService._();
  static const _budgetPreferenceKey = 'ente_gallery.offline_thumbnail_budget';
  static const int defaultBudgetBytes = 4 * 1024 * 1024 * 1024;
  static const int minBudgetBytes = 1024 * 1024 * 1024;
  static const int maxBudgetBytes = 16 * 1024 * 1024 * 1024;

  bool _stopRequested = false;
  bool _isRunning = false;

  Future<int> getBudgetBytes() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_budgetPreferenceKey) ?? defaultBudgetBytes;
  }

  Future<void> setBudgetBytes(int bytes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _budgetPreferenceKey,
      bytes.clamp(minBudgetBytes, maxBudgetBytes).toInt(),
    );
  }

  Future<OfflineThumbnailProgress> getProgress() async {
    final directory = Directory(offlineThumbnailDirectoryPath());
    var count = 0;
    var bytes = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || entity.path.endsWith('.partial')) continue;
        final length = await entity.length();
        if (length <= 0) continue;
        count++;
        bytes += length;
      }
    }
    return OfflineThumbnailProgress(
      total: 0,
      processed: count,
      pinned: count,
      failed: 0,
      skippedForBudget: 0,
      bytes: bytes,
      isRunning: _isRunning,
    );
  }

  void stop() => _stopRequested = true;

  Future<OfflineThumbnailProgress> pinAll({
    required int budgetBytes,
    required void Function(OfflineThumbnailProgress) onProgress,
  }) async {
    if (_isRunning) throw StateError('Offline thumbnail download is running');
    _isRunning = true;
    _stopRequested = false;
    var processed = 0;
    var pinned = 0;
    var failed = 0;
    var skippedForBudget = 0;
    var bytes = 0;
    var files = <EnteFile>[];
    try {
      files = (await FilesDB.instance.getAllFilesFromDB(const <int>{}))
          .where((file) => file.isRemoteOnlyFile && file.uploadedFileID != null)
          .toList(growable: false);
      final directory = Directory(offlineThumbnailDirectoryPath());
      await directory.create(recursive: true);
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || entity.path.endsWith('.partial')) continue;
        bytes += await entity.length();
      }
      var state = _snapshot(
        files.length,
        processed,
        pinned,
        failed,
        skippedForBudget,
        bytes,
      );
      onProgress(state);

      for (final file in files) {
        if (_stopRequested) break;
        final target = offlineThumbnailPath(file);
        if (await target.exists() && await target.length() > 0) {
          processed++;
          pinned++;
        } else {
          if (await target.exists()) await target.delete();
          try {
            final cached = await getThumbnailForUploadedFile(file);
            if (cached == null) {
              failed++;
              processed++;
            } else {
              final thumbnailBytes = await cached.length();
              if (thumbnailBytes <= 0 || bytes + thumbnailBytes > budgetBytes) {
                skippedForBudget++;
                processed++;
              } else {
                final partial = File('${target.path}.partial');
                if (await partial.exists()) await partial.delete();
                await partial.writeAsBytes(
                  await cached.readAsBytes(),
                  flush: true,
                );
                await partial.rename(target.path);
                bytes += thumbnailBytes;
                pinned++;
                processed++;
              }
            }
          } on Object {
            failed++;
            processed++;
          }
        }
        if (processed % 20 == 0 || processed == files.length) {
          state = _snapshot(
            files.length,
            processed,
            pinned,
            failed,
            skippedForBudget,
            bytes,
          );
          onProgress(state);
        }
      }
      state = _snapshot(
        files.length,
        processed,
        pinned,
        failed,
        skippedForBudget,
        bytes,
      );
      onProgress(state);
      return state;
    } finally {
      _isRunning = false;
      _stopRequested = false;
    }
  }

  Future<void> clearAll() async {
    if (_isRunning) throw StateError('Cannot clear while download is running');
    final directory = Directory(offlineThumbnailDirectoryPath());
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
  }

  OfflineThumbnailProgress _snapshot(
    int total,
    int processed,
    int pinned,
    int failed,
    int skippedForBudget,
    int bytes,
  ) => OfflineThumbnailProgress(
    total: total,
    processed: processed,
    pinned: pinned,
    failed: failed,
    skippedForBudget: skippedForBudget,
    bytes: bytes,
    isRunning: _isRunning,
  );
}
