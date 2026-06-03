import 'dart:io';

/// Scans a configured notes directory and returns file paths
/// whose content matches keywords from a task title.
class NoteLinker {
  String? _notesDir;

  /// Configure the notes directory to scan.
  void setNotesDir(String dir) => _notesDir = dir;

  /// Return up to [maxResults] note file paths relevant to [taskTitle].
  /// Matching is naive full-text substring search — good enough for
  /// personal markdown/text note collections.
  Future<List<String>> findRelated(String taskTitle, {int maxResults = 3}) async {
    final dir = _notesDir;
    if (dir == null || dir.isEmpty) return [];
    final directory = Directory(dir);
    if (!await directory.exists()) return [];

    // Extract potential keywords: split on common separators + Chinese word boundaries
    final keywords = taskTitle
        .split(RegExp(r'[\s，。！？,.!?、：:（）()【】\[\]{}]+'))
        .where((s) => s.length >= 2)
        .toList();

    final results = <_Match>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      final ext = entity.path.split('.').last.toLowerCase();
      if (!['txt', 'md', 'markdown', 'log', 'rst', 'org'].contains(ext)) continue;

      try {
        final content = await entity.readAsString();
        final lowerContent = content.toLowerCase();
        final lowerTitle = taskTitle.toLowerCase();
        var score = 0;

        // Full title match
        if (lowerContent.contains(lowerTitle)) score += 10;
        // Keyword matches
        for (final kw in keywords) {
          if (kw.length >= 2 && lowerContent.contains(kw.toLowerCase())) score += 3;
        }
        // Filename match
        final fname = entity.uri.pathSegments.last.toLowerCase();
        for (final kw in keywords) {
          if (kw.length >= 2 && fname.contains(kw.toLowerCase())) score += 5;
        }

        if (score > 0) {
          results.add(_Match(entity.path, score));
        }
      } catch (_) {}
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).map((m) => m.path).toList();
  }
}

class _Match {
  final String path;
  final int score;
  const _Match(this.path, this.score);
}
