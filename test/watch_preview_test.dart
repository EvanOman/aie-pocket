import 'package:aie_watch/models/talk.dart';
import 'package:aie_watch/ui/watch_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Talk talk(String id) => Talk(
  id: id,
  title: 'Talk $id',
  presenter: 'Presenter $id',
  location: 'Room $id',
  day: '2026-11-10',
  startIso: '2026-11-10T09:00:00-08:00',
  endIso: '2026-11-10T09:30:00-08:00',
  track: 'workflow',
);

Widget preview(List<Talk> talks) => MaterialApp(
  home: Scaffold(body: WatchPreview(talks: talks)),
);

void main() {
  testWidgets('removing the last visible card clamps to a remaining talk', (
    tester,
  ) async {
    await tester.pumpWidget(preview([talk('a'), talk('b'), talk('c')]));
    await tester.tap(find.byTooltip('Next watch card'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next watch card'));
    await tester.pumpAndSettle();
    expect(find.text('3 OF 3 TALKS'), findsOneWidget);

    await tester.pumpWidget(preview([talk('a')]));
    await tester.pumpAndSettle();

    expect(find.text('1 OF 1 TALKS'), findsOneWidget);
    expect(find.text('Talk a'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clearing while on a later page and adding back starts at the first talk',
    (tester) async {
      await tester.pumpWidget(preview([talk('a'), talk('b')]));
      await tester.tap(find.byTooltip('Next watch card'));
      await tester.pumpAndSettle();
      expect(find.text('2 OF 2 TALKS'), findsOneWidget);

      await tester.pumpWidget(preview([]));
      await tester.pumpAndSettle();
      expect(find.text('YOUR TALKS, AT A GLANCE'), findsOneWidget);

      await tester.pumpWidget(preview([talk('replacement')]));
      await tester.pumpAndSettle();

      expect(find.text('1 OF 1 TALKS'), findsOneWidget);
      expect(find.text('Talk replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
