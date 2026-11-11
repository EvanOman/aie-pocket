import 'dart:convert';

import 'package:aie_watch/services/schedule_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceMemory {
  final values = <String, String>{};
  final writes = <(String, String)>[];
  bool failWrite = false;
}

/// Only the storage boundary is faked; the app's encoding and decoding run unchanged.
class MemoryPreferences implements SharedPreferencesAsync {
  MemoryPreferences(this.memory);

  final PreferenceMemory memory;

  @override
  Future<String?> getString(String key) async => memory.values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (memory.failWrite) throw StateError('Storage unavailable');
    memory.writes.add((key, value));
    memory.values[key] = value;
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected preference API: ${invocation.memberName}',
  );
}

void main() {
  late PreferenceMemory memory;
  late MemoryPreferences preferences;
  late PreferencesScheduleStore store;

  setUp(() {
    memory = PreferenceMemory();
    preferences = MemoryPreferences(memory);
    store = PreferencesScheduleStore(preferences: preferences);
  });

  test(
    'no stored value is distinct from an explicitly cleared schedule',
    () async {
      expect(await store.load(), isNull);

      await store.save(StoredSchedule(selectedIds: [], revision: 12));
      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.selectedIds, isEmpty);
      expect(restored.revision, 12);
    },
  );

  test(
    'selection and revision round-trip in one versioned preference write',
    () async {
      await store.save(
        StoredSchedule(selectedIds: ['first', 'last'], revision: 42),
      );

      expect(memory.writes, hasLength(1));
      expect(memory.writes.single.$1, PreferencesScheduleStore.key);
      final persisted =
          jsonDecode(memory.writes.single.$2) as Map<String, dynamic>;
      expect(persisted, {
        'version': 1,
        'selectedIds': ['first', 'last'],
        'revision': 42,
      });
      final restored = await store.load();
      expect(restored!.selectedIds, ['first', 'last']);
      expect(restored.revision, 42);
    },
  );

  test(
    'clearing replaces a previous selection and preserves the new revision',
    () async {
      await store.save(StoredSchedule(selectedIds: ['old-talk'], revision: 42));
      await store.save(StoredSchedule(selectedIds: [], revision: 43));

      final restored = await PreferencesScheduleStore(
        preferences: preferences,
      ).load();

      expect(restored!.selectedIds, isEmpty);
      expect(restored.revision, 43);
      expect(memory.values, hasLength(1));
    },
  );

  test(
    'unsupported storage versions fail without overwriting saved data',
    () async {
      const saved = '{"version":2,"selectedIds":["saved-talk"],"revision":42}';
      memory.values[PreferencesScheduleStore.key] = saved;

      await expectLater(store.load(), throwsFormatException);

      expect(memory.values[PreferencesScheduleStore.key], saved);
      expect(memory.writes, isEmpty);
    },
  );

  test(
    'corrupt JSON is reported instead of silently resetting choices',
    () async {
      memory.values[PreferencesScheduleStore.key] = '{unfinished';

      await expectLater(store.load(), throwsFormatException);

      expect(memory.writes, isEmpty);
    },
  );

  test(
    'invalid saved IDs and revisions cannot be restored as valid state',
    () async {
      for (final saved in [
        {
          'version': 1,
          'selectedIds': [7],
          'revision': 42,
        },
        {
          'version': 1,
          'selectedIds': ['talk'],
          'revision': '42',
        },
        {
          'version': 1,
          'selectedIds': ['talk'],
        },
      ]) {
        memory.values[PreferencesScheduleStore.key] = jsonEncode(saved);
        await expectLater(store.load(), throwsA(anything));
      }
      expect(memory.writes, isEmpty);
    },
  );

  test(
    'a write failure propagates and leaves the durable selection intact',
    () async {
      await store.save(
        StoredSchedule(selectedIds: ['saved-talk'], revision: 42),
      );
      memory.failWrite = true;

      await expectLater(
        store.save(StoredSchedule(selectedIds: [], revision: 43)),
        throwsStateError,
      );

      final restored = await store.load();
      expect(restored!.selectedIds, ['saved-talk']);
      expect(restored.revision, 42);
    },
  );

  test(
    'a queued stored selection cannot change when the caller edits its list',
    () {
      final ids = ['chosen'];
      final schedule = StoredSchedule(selectedIds: ids, revision: 1);

      ids.clear();

      expect(schedule.selectedIds, ['chosen']);
      expect(() => schedule.selectedIds.add('later'), throwsUnsupportedError);
    },
  );
}
