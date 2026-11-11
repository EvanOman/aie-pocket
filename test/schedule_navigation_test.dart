import 'package:aie_watch/models/schedule_navigation.dart';
import 'package:aie_watch/models/talk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Talk talk(String id, String start, String end) => Talk(
    id: id,
    title: id,
    presenter: '',
    location: '',
    day: '2026-11-10',
    startIso: '2026-11-10T$start:00-08:00',
    endIso: '2026-11-10T$end:00-08:00',
    track: '',
  );
  final talks = [
    talk('registration', '08:00', '17:30'),
    talk('workshop', '16:30', '17:30'),
    talk('reception', '17:30', '20:30'),
  ];
  test('conference date uses PST even after UTC midnight', () {
    expect(conferenceDay(DateTime.parse('2026-11-11T00:45:00Z')), '2026-11-10');
  });
  test(
    'jump chooses current session, exclusive end, and out-of-range edges',
    () {
      expect(
        currentOrNextTalk(talks, DateTime.parse('2026-11-11T00:45:00Z'))!.id,
        'workshop',
      );
      expect(
        currentOrNextTalk(
          talks,
          DateTime.parse('2026-11-10T17:30:00-08:00'),
        )!.id,
        'reception',
      );
      expect(
        currentOrNextTalk(talks, DateTime.parse('2026-11-09T00:00:00Z'))!.id,
        'registration',
      );
      expect(
        currentOrNextTalk(talks, DateTime.parse('2026-11-13T00:00:00Z'))!.id,
        'reception',
      );
      expect(currentOrNextTalk([], DateTime.now()), isNull);
    },
  );
}
