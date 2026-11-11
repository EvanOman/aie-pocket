import 'talk.dart';

/// The bundled November conference is entirely in PST (UTC−8).
String conferenceDay(DateTime now) => now
    .toUtc()
    .subtract(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);

/// Prefer the most recently started ongoing session, then the next start.
/// End times are exclusive. After the conference, return the final session.
Talk? currentOrNextTalk(List<Talk> talks, DateTime now) {
  if (talks.isEmpty) return null;
  final ordered = [...talks]..sort((a, b) => a.start.compareTo(b.start));
  final ongoing = ordered.where(
    (t) => !t.start.isAfter(now) && t.end.isAfter(now),
  );
  if (ongoing.isNotEmpty) return ongoing.last;
  return ordered.where((t) => t.start.isAfter(now)).firstOrNull ?? ordered.last;
}
