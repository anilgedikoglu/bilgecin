import 'package:flutter/services.dart';
import '../models/thing_entry.dart';

class ThingsDataService {
  static List<ThingEntry>? _cache;

  static Future<List<ThingEntry>> loadThings() async {
    if (_cache != null) return _cache!;
    final raw   = await rootBundle.loadString('assets/things_dataset.csv');
    final lines = raw.split('\n');
    final result = <ThingEntry>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final cols = _parseCsvLine(line);
        if (cols.length >= 169) result.add(ThingEntry.fromCsvRow(cols));
      } catch (_) {}
    }
    _cache = result;
    return result;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"'); i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString()); sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString());
    return result;
  }
}
