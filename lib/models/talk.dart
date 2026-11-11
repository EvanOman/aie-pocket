/// A talk's source timestamps are retained for conference-local display.
/// Parsed timestamps are instants used only for ordering and overlap checks.
class Talk {
  Talk({
    required this.id,
    required this.title,
    required this.presenter,
    required this.location,
    required this.day,
    required this.startIso,
    required this.endIso,
    required this.track,
    this.description = '',
    this.url = '',
  }) : start = _parseTimestamp(startIso),
       end = _parseTimestamp(endIso) {
    if (!end.isAfter(start)) {
      throw FormatException('Talk $id must end after it starts.');
    }
  }

  factory Talk.fromJson(Map<String, dynamic> json) => Talk(
    id: json['id'] as String,
    title: json['title'] as String,
    presenter: json['presenter'] as String,
    location: json['location'] as String,
    day: json['day'] as String,
    startIso: json['start'] as String,
    endIso: json['end'] as String,
    track: json['track'] as String? ?? '',
    description: json['description'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  final String id;
  final String title;
  final String presenter;
  final String location;
  final String day;
  final String startIso;
  final String endIso;
  final String track;
  final String description;
  final String url;
  final DateTime start;
  final DateTime end;

  static DateTime _parseTimestamp(String value) {
    if (!RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}.*(Z|[+-]\d{2}:\d{2})$',
    ).hasMatch(value)) {
      throw FormatException(
        'Talk time requires an explicit UTC offset: $value',
      );
    }
    return DateTime.parse(value);
  }

  /// Adjacent talks do not overlap; selecting the same talk is not a conflict.
  bool conflictsWith(Talk other) =>
      id != other.id && start.isBefore(other.end) && end.isAfter(other.start);

  String get timeLabel {
    final startHour = int.parse(startIso.substring(11, 13));
    final endHour = int.parse(endIso.substring(11, 13));
    final samePeriod = (startHour < 12) == (endHour < 12);
    return '${_clock(startIso, includePeriod: !samePeriod)}–${_clock(endIso)}';
  }

  String get startTimeLabel => _clock(startIso);

  String get dayLabel {
    final date = DateTime.parse(day);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  static String _clock(String iso, {bool includePeriod = true}) {
    final hour = int.parse(iso.substring(11, 13));
    final minute = iso.substring(14, 16);
    final suffix = includePeriod ? (hour < 12 ? ' AM' : ' PM') : '';
    return '${hour % 12 == 0 ? 12 : hour % 12}:$minute$suffix';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'presenter': presenter,
    'location': location,
    'day': day,
    'start': startIso,
    'end': endIso,
    'track': track,
    'description': description,
    'url': url,
  };

  Map<String, dynamic> toWatchJson() => {
    'id': id,
    'title': title,
    'presenter': presenter,
    'location': location,
    'day': day,
    'start': startIso,
    'end': endIso,
    'track': track,
  };
}
