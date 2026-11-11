import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models/schedule_catalog.dart';
import 'models/talk.dart';
import 'services/schedule_store.dart';
import 'services/watch_bridge.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController({
    ScheduleCatalog? catalog,
    ScheduleStore? store,
    WatchBridge? bridge,
    DateTime Function()? now,
  }) : _catalog = catalog,
       _store = store ?? PreferencesScheduleStore(),
       _bridge = bridge ?? PlatformWatchBridge(),
       _now = now ?? DateTime.now;

  ScheduleCatalog? _catalog;
  final ScheduleStore _store;
  final WatchBridge _bridge;
  final DateTime Function() _now;
  Set<String> _selectedIds = {};
  int _revision = 0;
  int _pendingWrites = 0;
  bool _isLoaded = false;
  bool _disposed = false;
  Future<void>? _initialization;
  Future<void> _writeQueue = Future.value();
  String? _error;
  WatchSyncStatus _syncStatus = const WatchSyncStatus(
    state: 'loading',
    message: 'Loading your schedule…',
  );

  ScheduleCatalog? get catalog => _catalog;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get isLoaded => _isLoaded;
  bool get isSaving => _pendingWrites > 0;
  String? get error => _error;
  WatchSyncStatus get syncStatus => _syncStatus;

  List<Talk> get selected {
    final talks =
        _catalog?.talks
            .where((talk) => _selectedIds.contains(talk.id))
            .toList() ??
        <Talk>[];
    talks.sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return List.unmodifiable(talks);
  }

  List<Talk> conflictsFor(Talk talk) =>
      selected.where(talk.conflictsWith).toList(growable: false);

  bool get hasConflicts =>
      selected.any((talk) => conflictsFor(talk).isNotEmpty);

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _catalog ??= await ScheduleCatalog.load();
      final saved = await _store.load();
      final availableIds = _catalog!.talks.map((talk) => talk.id).toSet();
      if (saved != null) {
        _selectedIds = saved.selectedIds.toSet().intersection(availableIds);
        _revision = saved.revision;
      }
      _isLoaded = true;
      _error = null;
      try {
        _syncStatus = await _bridge.status();
      } catch (_) {
        _syncStatus = const WatchSyncStatus(
          state: 'error',
          message: 'Watch connection unavailable. You can retry sync.',
        );
      }
      _notify();
      // An explicitly saved empty schedule also has to clear the watch.
      if (saved != null) await sync();
    } catch (_) {
      _error = 'Could not load your saved schedule. Tap Retry to try again.';
      _syncStatus = const WatchSyncStatus(
        state: 'error',
        message: 'Your schedule could not be loaded.',
      );
      _initialization = null;
      _notify();
    }
  }

  Future<void> toggle(Talk talk) {
    if (!_isLoaded || !_catalog!.talks.any((item) => item.id == talk.id)) {
      return Future.value();
    }
    if (!_selectedIds.remove(talk.id)) _selectedIds.add(talk.id);
    return _queueCurrentSelection();
  }

  Future<void> useRecommended() {
    if (!_isLoaded) return Future.value();
    final availableIds = _catalog!.talks.map((talk) => talk.id).toSet();
    _selectedIds = _catalog!.recommendedIds.intersection(availableIds);
    return _queueCurrentSelection();
  }

  Future<void> clear() {
    if (!_isLoaded) return Future.value();
    _selectedIds.clear();
    return _queueCurrentSelection();
  }

  Future<void> sync() {
    if (!_isLoaded) return Future.value();
    return _queueCurrentSelection();
  }

  Future<void> _queueCurrentSelection() {
    final time = _now();
    final revision = _revision = max(
      _revision + 1,
      time.millisecondsSinceEpoch,
    );
    final talks = selected;
    final stored = StoredSchedule(
      selectedIds: talks.map((talk) => talk.id).toList(),
      revision: revision,
    );
    final payload = jsonEncode({
      'schemaVersion': 1,
      'revision': revision,
      'eventName': _catalog!.name,
      'timezone': _catalog!.timezone,
      'generatedAt': time.toUtc().toIso8601String(),
      'talks': talks.map((talk) => talk.toWatchJson()).toList(),
    });
    _pendingWrites++;
    _error = null;
    _notify();
    _writeQueue = _writeQueue.then((_) async {
      var saved = false;
      try {
        await _store.save(stored);
        saved = true;
        final status = await _bridge.publish(payload);
        if (revision == _revision) {
          _syncStatus = status;
          _error = status.state == 'error' ? status.message : null;
        }
      } catch (_) {
        if (revision == _revision) {
          _error = saved
              ? 'Saved on this phone. Watch sync failed; tap Retry sync.'
              : 'Could not save your choices. Tap Retry sync to try again.';
          _syncStatus = WatchSyncStatus(state: 'error', message: _error!);
        }
      } finally {
        _pendingWrites--;
        _notify();
      }
    });
    return _writeQueue;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
