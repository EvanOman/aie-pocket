import 'package:aie_watch/main.dart';
import 'package:aie_watch/models/schedule_catalog.dart';
import 'package:aie_watch/schedule_controller.dart';
import 'package:aie_watch/services/schedule_store.dart';
import 'package:aie_watch/services/watch_bridge.dart';
import 'package:aie_watch/ui/watch_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements ScheduleStore {
  StoredSchedule? value;
  @override
  Future<StoredSchedule?> load() async => value;
  @override
  Future<void> save(StoredSchedule schedule) async {
    value = schedule;
  }
}

class PreviewBridge implements WatchBridge {
  @override
  Future<WatchSyncStatus> status() async => PlatformWatchBridge.previewStatus;
  @override
  Future<WatchSyncStatus> publish(String snapshot) => status();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScheduleCatalog catalogue;
  setUpAll(() async {
    catalogue = await ScheduleCatalog.load();
  });
  testWidgets('choose, inspect and clear real talks at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    final controller = ScheduleController(
      catalog: catalogue,
      store: store,
      bridge: PreviewBridge(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AiePocketApp(
        controller: controller,
        now: () => DateTime.parse('2026-11-10T16:45:00-08:00'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.selected, isEmpty);
    await tester.ensureVisible(find.text('Use suggested path'));
    await tester.tap(find.text('Use suggested path'));
    await tester.pumpAndSettle();
    expect(controller.selected.length, 37);
    expect(store.value!.selectedIds.length, 37);
    await tester.ensureVisible(find.text('Watch preview'));
    await tester.tap(find.text('Watch preview'));
    await tester.pumpAndSettle();
    expect(find.byType(WatchPreview), findsOneWidget);
    expect(find.text('1 OF 37 TALKS'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next watch card'));
    await tester.tap(find.byTooltip('Next watch card'));
    await tester.pumpAndSettle();
    expect(find.text('2 OF 37 TALKS'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 OF 37 TALKS'), findsOneWidget);
    await tester.ensureVisible(find.text('My talks'));
    await tester.tap(find.text('My talks'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear schedule'));
    await tester.pumpAndSettle();
    expect(controller.selected, isEmpty);
    expect(store.value!.selectedIds, isEmpty);
  });

  testWidgets('phone search keeps focus when the starter panel changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScheduleController(
      catalog: catalogue,
      store: MemoryStore(),
      bridge: PreviewBridge(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AiePocketApp(
        controller: controller,
        now: () => DateTime.parse('2026-11-10T16:45:00-08:00'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use suggested path'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.ensureVisible(find.text('View all days'));
    await tester.tap(find.text('View all days'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));

    // Send separate keyboard edits without requesting focus again between them.
    tester.testTextInput.enterText('Y');
    await tester.pumpAndSettle();
    expect(find.text('Use suggested path'), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);

    tester.testTextInput.enterText('Your agent pays twice');
    await tester.pumpAndSettle();
    expect(find.text('1 talks'), findsOneWidget);
    expect(
      find.text(
        'Your agent pays twice for every search: how we cut token spend by 90+% with better accuracy',
      ),
      findsOneWidget,
    );

    tester.testTextInput.enterText('');
    await tester.pumpAndSettle();
    expect(find.text('Use suggested path'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('desktop search narrows actual catalogue and no layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScheduleController(
      catalog: catalogue,
      store: MemoryStore(),
      bridge: PreviewBridge(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AiePocketApp(
        controller: controller,
        now: () => DateTime.parse('2026-11-10T16:45:00-08:00'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no-matching-speaker-xyz');
    await tester.pumpAndSettle();
    expect(find.text('No matching talks.'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('112 talks'), findsOneWidget);
  });
  testWidgets(
    'jump switches from another day and search to the current session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScheduleController(
        catalog: catalogue,
        store: MemoryStore(),
        bridge: PreviewBridge(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AiePocketApp(
          controller: controller,
          now: () => DateTime.parse('2026-11-11T00:45:00Z'),
        ),
      );
      await tester.pumpAndSettle();
      final laterDay = find.byKey(ValueKey('day-${catalogue.days.last.date}'));
      await tester.ensureVisible(laterDay);
      await tester.tap(laterDay);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'no-matching-speaker-xyz');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jump to now'));
      await tester.pumpAndSettle();
      expect(find.text('HAPPENING NOW'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      final label = tester.getRect(find.text('HAPPENING NOW'));
      expect(label.top, greaterThanOrEqualTo(0));
      expect(label.bottom, lessThan(844));
      expect(tester.takeException(), isNull);
    },
  );
}
