import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WatchSyncStatus {
  const WatchSyncStatus({required this.state, required this.message});

  factory WatchSyncStatus.fromMap(Map<dynamic, dynamic>? map) =>
      WatchSyncStatus(
        state: map?['state'] as String? ?? 'unavailable',
        message: map?['message'] as String? ?? 'Watch status is unavailable.',
      );

  final String state;
  final String message;
}

abstract class WatchBridge {
  Future<WatchSyncStatus> publish(String snapshot);
  Future<WatchSyncStatus> status();
}

class PlatformWatchBridge implements WatchBridge {
  static const _channel = MethodChannel('aie_watch/schedule');
  static const previewStatus = WatchSyncStatus(
    state: 'preview',
    message: 'Watch preview · Sync is available in the iPhone app.',
  );

  bool get _isPhone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<WatchSyncStatus> publish(String snapshot) async {
    if (!_isPhone) return previewStatus;
    return WatchSyncStatus.fromMap(
      await _channel.invokeMapMethod<String, dynamic>(
        'publishSchedule',
        snapshot,
      ),
    );
  }

  @override
  Future<WatchSyncStatus> status() async {
    if (!_isPhone) return previewStatus;
    return WatchSyncStatus.fromMap(
      await _channel.invokeMapMethod<String, dynamic>('status'),
    );
  }
}
