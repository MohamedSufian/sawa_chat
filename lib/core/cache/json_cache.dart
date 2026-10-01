import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final jsonCacheProvider = Provider<JsonCache>((ref) => JsonCache());

/// Tiny on-disk cache of raw server rows, for "stale-while-revalidate":
/// screens show the last copy instantly (and offline), then refresh.
///
/// Rows are stored exactly as the API returned them, so the models' existing
/// `fromJson` parses them and no separate cache schema has to be kept in sync.
class JsonCache {
  Directory? _dir;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    return _dir = await Directory('${base.path}/cache').create(recursive: true);
  }

  Future<File> _file(String key) async =>
      File('${(await _directory()).path}/${key.replaceAll(RegExp(r'[^\w-]'), '_')}.json');

  Future<List<Map<String, dynamic>>?> readRows(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Cache read failed for $key: $e');
      return null;
    }
  }

  Future<void> writeRows(String key, List<Map<String, dynamic>> rows) async {
    try {
      final file = await _file(key);
      // Write then rename, so a crash mid-write never leaves a corrupt file.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(rows), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('Cache write failed for $key: $e');
    }
  }

  /// Called on sign-out so the next account never sees the previous one's data.
  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
    } catch (e) {
      debugPrint('Cache clear failed: $e');
    }
  }
}
