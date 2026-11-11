import 'dart:convert';

import 'package:flutter/services.dart';

import 'talk.dart';

class EventDay {
  const EventDay({required this.id, required this.label, required this.date});

  factory EventDay.fromJson(Map<String, dynamic> json) => EventDay(
    id: json['id'] as String,
    label: json['label'] as String,
    date: json['date'] as String,
  );

  final String id;
  final String label;
  final String date;
}

class ScheduleEvent {
  const ScheduleEvent({
    required this.name,
    required this.subtitle,
    required this.timezone,
    required this.sourceUrl,
    required this.days,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
    name: json['name'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    timezone: json['timezone'] as String,
    sourceUrl: json['sourceUrl'] as String,
    days: List.unmodifiable(
      (json['days'] as List<Object?>).map(
        (day) => EventDay.fromJson(
          Map<String, dynamic>.from(day as Map<Object?, Object?>),
        ),
      ),
    ),
  );

  final String name;
  final String subtitle;
  final String timezone;
  final String sourceUrl;
  final List<EventDay> days;
}

class ScheduleCatalog {
  ScheduleCatalog({
    required this.event,
    required List<Talk> talks,
    required Set<String> recommendedIds,
  }) : talks = List.unmodifiable(talks),
       recommendedIds = Set.unmodifiable(recommendedIds) {
    if (talks.map((talk) => talk.id).toSet().length != talks.length) {
      throw const FormatException('The schedule contains duplicate talk IDs.');
    }
  }

  factory ScheduleCatalog.fromJson(Map<String, dynamic> json) =>
      ScheduleCatalog(
        event: ScheduleEvent.fromJson(
          Map<String, dynamic>.from(json['event'] as Map<Object?, Object?>),
        ),
        talks: (json['talks'] as List<Object?>)
            .map(
              (talk) => Talk.fromJson(
                Map<String, dynamic>.from(talk as Map<Object?, Object?>),
              ),
            )
            .toList(),
        recommendedIds: Set<String>.from(
          json['recommendedIds'] as List<Object?>? ?? [],
        ),
      );

  static Future<ScheduleCatalog> load() async => ScheduleCatalog.fromJson(
    jsonDecode(await rootBundle.loadString('assets/schedule.json'))
        as Map<String, dynamic>,
  );

  final ScheduleEvent event;
  final List<Talk> talks;
  final Set<String> recommendedIds;

  String get name => event.name;
  String get subtitle => event.subtitle;
  String get timezone => event.timezone;
  String get sourceUrl => event.sourceUrl;
  List<EventDay> get days => event.days;
}
