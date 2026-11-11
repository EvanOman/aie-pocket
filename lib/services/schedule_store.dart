import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredSchedule {
  StoredSchedule({required List<String> selectedIds, required this.revision})
    : selectedIds = List.unmodifiable(selectedIds);

  final List<String> selectedIds;
  final int revision;
}

abstract class ScheduleStore {
  Future<StoredSchedule?> load();
  Future<void> save(StoredSchedule schedule);
}

/// Selection and revision share one persisted value, so they cannot diverge.
class PreferencesScheduleStore implements ScheduleStore {
  PreferencesScheduleStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'aie_watch.schedule.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<StoredSchedule?> load() async {
    final value = await _preferences.getString(key);
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported saved schedule version.');
    }
    return StoredSchedule(
      selectedIds: List<String>.from(json['selectedIds'] as List<Object?>),
      revision: json['revision'] as int,
    );
  }

  @override
  Future<void> save(StoredSchedule schedule) => _preferences.setString(
    key,
    jsonEncode({
      'version': 1,
      'selectedIds': schedule.selectedIds,
      'revision': schedule.revision,
    }),
  );
}
