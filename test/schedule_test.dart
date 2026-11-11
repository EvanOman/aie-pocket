import 'dart:async';
import 'dart:convert';

import 'package:aie_watch/models/schedule_catalog.dart';
import 'package:aie_watch/models/talk.dart';
import 'package:aie_watch/schedule_controller.dart';
import 'package:aie_watch/services/schedule_store.dart';
import 'package:aie_watch/services/watch_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> talkJson(
  String id, {
  String start = '2026-11-10T09:00:00-08:00',
  String end = '2026-11-10T09:30:00-08:00',
}) => {
  'id': id,
  'title': 'Talk $id',
  'presenter': 'Presenter $id',
  'location': 'Room $id',
  'day': '2026-11-10',
  'start': start,
  'end': end,
  'track': 'Engineering',
  'description': 'Description $id',
  'url': 'https://example.com/talk/$id',
};

ScheduleCatalog fixtureCatalog() => ScheduleCatalog.fromJson({
  'event': {
    'name': 'Conference',
    'subtitle': 'San Francisco',
    'timezone': 'America/Los_Angeles',
    'sourceUrl': 'https://example.com/schedule',
    'days': [
      {'id': '2026-11-10', 'label': 'Tuesday', 'date': '2026-11-10'},
    ],
  },
  'talks': [
    talkJson('early'),
    talkJson(
      'late',
      start: '2026-11-10T10:00:00-08:00',
      end: '2026-11-10T10:30:00-08:00',
    ),
    talkJson(
      'overlap',
      start: '2026-11-10T09:15:00-08:00',
      end: '2026-11-10T09:45:00-08:00',
    ),
  ],
  'recommendedIds': ['early', 'late'],
});

class FakeStore implements ScheduleStore {
  FakeStore({this.stored});

  StoredSchedule? stored;
  bool failSave = false;
  bool failLoad = false;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();
  final saves = <StoredSchedule>[];
  int activeSaves = 0;
  int maximumActiveSaves = 0;

  @override
  Future<StoredSchedule?> load() async {
    if (failLoad) throw StateError('Storage unavailable');
    return stored;
  }

  @override
  Future<void> save(StoredSchedule schedule) async {
    saves.add(schedule);
    activeSaves++;
    maximumActiveSaves = activeSaves > maximumActiveSaves
        ? activeSaves
        : maximumActiveSaves;
    if (!saveStarted.isCompleted) saveStarted.complete();
    try {
      final gate = saveGate;
      saveGate = null;
      if (gate != null) await gate.future;
      if (failSave) throw StateError('Storage unavailable');
      stored = schedule;
    } finally {
      activeSaves--;
    }
  }
}

class FakeBridge implements WatchBridge {
  bool failPublish = false;
  final snapshots = <Map<String, dynamic>>[];

  @override
  Future<WatchSyncStatus> status() async => const WatchSyncStatus(
    state: 'queued',
    message: 'Ready to queue for watch',
  );

  @override
  Future<WatchSyncStatus> publish(String snapshot) async {
    if (failPublish) throw StateError('Watch transfer unavailable');
    snapshots.add(jsonDecode(snapshot) as Map<String, dynamic>);
    return const WatchSyncStatus(state: 'queued', message: 'Queued for watch');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformWatchBridge', () {
    const channel = MethodChannel('aie_watch/schedule');

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'iOS forwards the JSON string and keeps queued status honest',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return {'state': 'queued', 'message': 'Queued for watch'};
            });
        final bridge = PlatformWatchBridge();
        const snapshot = '{"schemaVersion":1,"talks":[]}';

        final status = await bridge.publish(snapshot);
        await bridge.status();

        expect(calls.map((call) => call.method), ['publishSchedule', 'status']);
        expect(calls.first.arguments, snapshot);
        expect(calls.first.arguments, isA<String>());
        expect(status.state, 'queued');
      },
    );

    test('non-iOS is a preview and never attempts native sync', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            called = true;
            return null;
          });
      final bridge = PlatformWatchBridge();

      expect((await bridge.publish('{}')).state, 'preview');
      expect((await bridge.status()).state, 'preview');
      expect(called, isFalse);
    });

    test('a missing native response is unavailable, never delivered', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      final bridge = PlatformWatchBridge();

      for (final status in [
        await bridge.status(),
        await bridge.publish('{"schemaVersion":1,"talks":[]}'),
      ]) {
        expect(status.state, 'unavailable');
        expect(status.message, 'Watch status is unavailable.');
      }
    });

    test(
      'missing plugin leaves the companion usable and choices saved',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final catalog = fixtureCatalog();
        final store = FakeStore();
        final controller = ScheduleController(
          catalog: catalog,
          store: store,
          bridge: PlatformWatchBridge(),
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        expect(controller.isLoaded, isTrue);
        expect(controller.syncStatus.state, 'error');
        await controller.toggle(catalog.talks.first);

        expect(store.stored!.selectedIds, ['early']);
        expect(controller.selectedIds, {'early'});
        expect(controller.error, contains('Saved on this phone'));
        expect(controller.isSaving, isFalse);
      },
    );

    test(
      'malformed native status preserves choices and retry recovers',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        var malformed = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'publishSchedule' && malformed) {
                return {'state': 7, 'message': 'Invalid response'};
              }
              return {'state': 'queued', 'message': 'Queued for watch'};
            });
        final catalog = fixtureCatalog();
        final store = FakeStore();
        final controller = ScheduleController(
          catalog: catalog,
          store: store,
          bridge: PlatformWatchBridge(),
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        await controller.toggle(catalog.talks.first);

        expect(store.stored!.selectedIds, ['early']);
        expect(controller.error, contains('Watch sync failed'));
        expect(controller.syncStatus.state, 'error');
        malformed = false;
        await controller.sync();
        expect(controller.error, isNull);
        expect(controller.selectedIds, {'early'});
        expect(controller.syncStatus.state, 'queued');
      },
    );

    test(
      'a native error result is shown without discarding durable choices',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => {
                'state': 'error',
                'message': 'Watch is not paired.',
              },
            );
        final catalog = fixtureCatalog();
        final store = FakeStore();
        final controller = ScheduleController(
          catalog: catalog,
          store: store,
          bridge: PlatformWatchBridge(),
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        await controller.toggle(catalog.talks.first);

        expect(controller.error, 'Watch is not paired.');
        expect(controller.syncStatus.state, 'error');
        expect(store.stored!.selectedIds, ['early']);
        expect(controller.selectedIds, {'early'});
      },
    );
  });

  group('Talk', () {
    test('compares instants but displays the conference wall clock', () {
      final talk = Talk.fromJson(talkJson('early'));

      expect(talk.start, DateTime.utc(2026, 11, 10, 17));
      expect(talk.end, DateTime.utc(2026, 11, 10, 17, 30));
      expect(talk.startIso, '2026-11-10T09:00:00-08:00');
      expect(talk.timeLabel, contains('9:00'));
      expect(talk.timeLabel, contains('9:30'));
      expect(talk.timeLabel, isNot(contains('17:')));
      expect(talk.dayLabel, contains('Nov 10'));
    });

    test('adjacent intervals do not conflict, overlaps do', () {
      final first = Talk.fromJson(talkJson('first'));
      final adjacent = Talk.fromJson(
        talkJson(
          'adjacent',
          start: '2026-11-10T09:30:00-08:00',
          end: '2026-11-10T10:00:00-08:00',
        ),
      );
      final overlap = Talk.fromJson(
        talkJson(
          'overlap',
          start: '2026-11-10T09:29:00-08:00',
          end: '2026-11-10T10:00:00-08:00',
        ),
      );

      expect(first.conflictsWith(adjacent), isFalse);
      expect(adjacent.conflictsWith(first), isFalse);
      expect(first.conflictsWith(overlap), isTrue);
      expect(overlap.conflictsWith(first), isTrue);
      expect(first.conflictsWith(first), isFalse);
    });

    test('rejects ambiguous timezone and non-positive duration', () {
      expect(
        () => Talk.fromJson(
          talkJson('missing-offset', start: '2026-11-10T09:00:00'),
        ),
        throwsFormatException,
      );
      for (final end in [
        '2026-11-10T09:00:00-08:00',
        '2026-11-10T08:59:00-08:00',
      ]) {
        expect(
          () => Talk.fromJson(talkJson('invalid-duration', end: end)),
          throwsFormatException,
        );
      }
    });

    test('labels midnight and noon without leaking device timezone', () {
      final midnight = Talk.fromJson(
        talkJson(
          'midnight',
          start: '2026-11-10T00:00:00-08:00',
          end: '2026-11-10T00:30:00-08:00',
        ),
      );
      final noon = Talk.fromJson(
        talkJson(
          'noon',
          start: '2026-11-10T11:45:00-08:00',
          end: '2026-11-10T12:15:00-08:00',
        ),
      );

      expect(midnight.timeLabel, '12:00–12:30 AM');
      expect(noon.timeLabel, '11:45 AM–12:15 PM');
    });
  });

  test(
    'catalogue rejects duplicate source IDs before selections can collide',
    () {
      final catalog = fixtureCatalog();
      expect(
        () => ScheduleCatalog(
          event: catalog.event,
          talks: [catalog.talks.first, catalog.talks.first],
          recommendedIds: {},
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'bundled catalogue recommendations produce a valid watch snapshot',
    () async {
      final catalog = await ScheduleCatalog.load();
      final knownIds = catalog.talks.map((talk) => talk.id).toSet();
      expect(catalog.talks, isNotEmpty);
      expect(catalog.recommendedIds, isNotEmpty);
      expect(catalog.recommendedIds.difference(knownIds), isEmpty);
      expect(knownIds, hasLength(catalog.talks.length));

      final bridge = FakeBridge();
      final controller = ScheduleController(
        catalog: catalog,
        store: FakeStore(),
        bridge: bridge,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.useRecommended();

      final snapshot = bridge.snapshots.single;
      expect(snapshot['schemaVersion'], 1);
      expect(snapshot['revision'], isA<int>());
      expect(snapshot['eventName'], catalog.name);
      expect(snapshot['timezone'], catalog.timezone);
      expect(DateTime.tryParse(snapshot['generatedAt'] as String), isNotNull);
      final watchTalks = snapshot['talks'] as List<dynamic>;
      expect(watchTalks, hasLength(catalog.recommendedIds.length));
      final offset = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
      for (final dynamic value in watchTalks) {
        final talk = value as Map<String, dynamic>;
        for (final field in [
          'id',
          'title',
          'presenter',
          'location',
          'day',
          'start',
          'end',
          'track',
        ]) {
          expect(talk[field], isA<String>(), reason: 'Missing $field in $talk');
        }
        expect(knownIds.contains(talk['id']), isTrue);
        expect(talk['title'] as String, isNotEmpty);
        expect(offset.hasMatch(talk['start'] as String), isTrue);
        expect(offset.hasMatch(talk['end'] as String), isTrue);
        final start = DateTime.parse(talk['start'] as String);
        final end = DateTime.parse(talk['end'] as String);
        expect(end.isAfter(start), isTrue);
      }
      final instants = watchTalks
          .map((dynamic talk) => DateTime.parse(talk['start'] as String))
          .toList();
      for (var index = 1; index < instants.length; index++) {
        expect(instants[index].isBefore(instants[index - 1]), isFalse);
      }
    },
  );

  group('ScheduleController', () {
    late ScheduleCatalog catalog;
    late FakeStore store;
    late FakeBridge bridge;
    late ScheduleController controller;

    setUp(() {
      catalog = fixtureCatalog();
      store = FakeStore();
      bridge = FakeBridge();
      controller = ScheduleController(
        catalog: catalog,
        store: store,
        bridge: bridge,
        now: () => DateTime.utc(2026, 11, 10, 16),
      );
    });

    tearDown(() => controller.dispose());

    Talk talk(String id) => catalog.talks.firstWhere((talk) => talk.id == id);

    test(
      'edits before loading and unknown source IDs do not persist or publish',
      () async {
        await controller.toggle(talk('early'));
        await controller.useRecommended();
        await controller.clear();
        await controller.sync();
        expect(store.saves, isEmpty);
        expect(bridge.snapshots, isEmpty);

        await controller.initialize();
        await controller.toggle(Talk.fromJson(talkJson('unknown')));
        expect(controller.selected, isEmpty);
        expect(store.saves, isEmpty);
        expect(bridge.snapshots, isEmpty);
      },
    );

    test(
      'restoring only removed IDs sends an empty replacement to the watch',
      () async {
        store.stored = StoredSchedule(
          selectedIds: ['removed-talk'],
          revision: 44,
        );

        await controller.initialize();

        expect(controller.selected, isEmpty);
        expect(store.stored!.selectedIds, isEmpty);
        expect(bridge.snapshots.single['talks'], isEmpty);
        expect(bridge.snapshots.single['revision'] as int, greaterThan(44));
      },
    );

    test(
      'failed initialization can be retried after storage recovers',
      () async {
        store.failLoad = true;
        await controller.initialize();
        expect(controller.isLoaded, isFalse);
        expect(controller.error, isNotNull);

        store.failLoad = false;
        await controller.initialize();
        expect(controller.isLoaded, isTrue);
        expect(controller.error, isNull);
      },
    );

    test(
      'first launch stays empty until recommendations are requested',
      () async {
        await controller.initialize();

        expect(controller.isLoaded, isTrue);
        expect(controller.selected, isEmpty);
        expect(store.saves, isEmpty);
        expect(bridge.snapshots, isEmpty);

        await controller.useRecommended();
        expect(controller.selectedIds, {'early', 'late'});
        expect(store.stored!.selectedIds.toSet(), {'early', 'late'});
      },
    );

    test(
      'an explicitly saved empty selection survives restart and clears watch',
      () async {
        store.stored = StoredSchedule(selectedIds: [], revision: 44);
        await controller.initialize();

        expect(controller.selected, isEmpty);
        expect(bridge.snapshots, isNotEmpty);
        expect(bridge.snapshots.last['talks'], isEmpty);
      },
    );

    test('restore ignores IDs missing from the current catalogue', () async {
      store.stored = StoredSchedule(
        selectedIds: ['late', 'removed-talk', 'early'],
        revision: 44,
      );
      await controller.initialize();

      expect(controller.selected.map((talk) => talk.id), ['early', 'late']);
      expect(controller.selectedIds, {'early', 'late'});
      final watchTalks = bridge.snapshots.last['talks'] as List<dynamic>;
      expect(watchTalks.map((dynamic talk) => talk['id']), ['early', 'late']);
    });

    test(
      'selection, watch payload and persisted selection are coherent',
      () async {
        await controller.initialize();
        await controller.toggle(talk('late'));
        await controller.toggle(talk('early'));

        expect(controller.selected.map((talk) => talk.id), ['early', 'late']);
        final snapshot = bridge.snapshots.last;
        expect(snapshot['schemaVersion'], 1);
        expect(snapshot['eventName'], 'Conference');
        expect(snapshot['timezone'], 'America/Los_Angeles');
        expect(DateTime.tryParse(snapshot['generatedAt'] as String), isNotNull);
        final watchTalks = snapshot['talks'] as List<dynamic>;
        expect(watchTalks.map((dynamic talk) => talk['id']), ['early', 'late']);
        expect(watchTalks.first, containsPair('title', 'Talk early'));
        expect(watchTalks.first, containsPair('presenter', 'Presenter early'));
        expect(watchTalks.first, containsPair('location', 'Room early'));
        expect(
          watchTalks.first,
          containsPair('start', '2026-11-10T09:00:00-08:00'),
        );
        expect(controller.syncStatus.state, 'queued');
        expect(store.stored!.selectedIds.toSet(), {'early', 'late'});

        await controller.clear();
        expect(controller.selected, isEmpty);
        expect(store.stored!.selectedIds, isEmpty);
        expect(bridge.snapshots.last['talks'], isEmpty);
      },
    );

    test(
      'conflicts update as overlapping selections are added and removed',
      () async {
        await controller.initialize();
        await controller.toggle(talk('early'));
        expect(controller.hasConflicts, isFalse);
        expect(
          controller.conflictsFor(talk('overlap')).map((talk) => talk.id),
          ['early'],
        );

        await controller.toggle(talk('overlap'));
        expect(controller.hasConflicts, isTrue);
        await controller.toggle(talk('overlap'));
        expect(controller.hasConflicts, isFalse);
      },
    );

    test(
      'rapid edits serialize saves and assign increasing revisions',
      () async {
        await controller.initialize();
        final gate = Completer<void>();
        store.saveGate = gate;
        final first = controller.toggle(talk('late'));
        await store.saveStarted.future;
        final second = controller.toggle(talk('early'));
        final third = controller.clear();

        expect(controller.selected, isEmpty);
        expect(store.saves, hasLength(1));
        gate.complete();
        await Future.wait([first, second, third]);

        expect(store.maximumActiveSaves, 1);
        expect(store.stored!.selectedIds, isEmpty);
        expect(bridge.snapshots.last['talks'], isEmpty);
        final revisions = bridge.snapshots
            .map((snapshot) => snapshot['revision'] as int)
            .toList();
        expect(revisions, hasLength(3));
        expect(revisions[1], greaterThan(revisions[0]));
        expect(revisions[2], greaterThan(revisions[1]));
        expect(controller.isSaving, isFalse);
      },
    );

    test(
      'a persisted revision remains monotonic if the clock moves back',
      () async {
        final futureRevision = DateTime.utc(2027).millisecondsSinceEpoch;
        store.stored = StoredSchedule(
          selectedIds: ['late'],
          revision: futureRevision,
        );
        await controller.initialize();
        await controller.toggle(talk('early'));

        expect(
          bridge.snapshots.last['revision'] as int,
          greaterThan(futureRevision),
        );
      },
    );

    test(
      'failed storage never publishes an undurable snapshot and retry recovers',
      () async {
        await controller.initialize();
        store.failSave = true;
        await controller.toggle(talk('early'));

        expect(controller.error, isNotNull);
        expect(bridge.snapshots, isEmpty);
        expect(controller.isSaving, isFalse);
        expect(controller.selectedIds, {'early'});

        store.failSave = false;
        await controller.sync();
        expect(controller.error, isNull);
        expect(store.stored!.selectedIds, ['early']);
        expect(bridge.snapshots, hasLength(1));
      },
    );

    test(
      'watch transfer failure preserves choices and explicit retry recovers',
      () async {
        await controller.initialize();
        bridge.failPublish = true;
        await controller.toggle(talk('early'));

        expect(controller.error, isNotNull);
        expect(store.stored!.selectedIds, ['early']);
        expect(controller.selectedIds, {'early'});

        bridge.failPublish = false;
        await controller.sync();
        expect(controller.error, isNull);
        expect(bridge.snapshots, hasLength(1));
        expect(controller.syncStatus.state, 'queued');
      },
    );
  });
}
