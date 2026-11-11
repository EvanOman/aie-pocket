import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/talk.dart';
import '../models/schedule_navigation.dart';
import '../schedule_controller.dart';
import 'watch_preview.dart';

const ink = Color(0xFF0B0E12);
const panel = Color(0xFF14191F);
const muted = Color(0xFF9DA7B4);
const lime = Color(0xFFC7F78C);
const line = Color(0xFF293139);

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.controller,
    this.now = DateTime.now,
  });
  final ScheduleController controller;
  final DateTime Function() now;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final search = TextEditingController();
  String? day;
  bool initializedDay = false;
  String? highlightedId;
  final talkKeys = <String, GlobalKey>{};

  void _jumpToNow() {
    final source = tab == 1 ? c.selected : c.catalog!.talks;
    final target = currentOrNextTalk(source, widget.now());
    if (target == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      day = target.day;
      search.clear();
      track = 'All tracks';
      highlightedId = target.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = talkKeys[target.id]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: .12,
          duration: const Duration(milliseconds: 350),
        );
      }
    });
  }

  String track = 'All tracks';
  int tab = 0;
  ScheduleController get c => widget.controller;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear your schedule?'),
        content: const Text(
          'All chosen talks will be removed from this device and the next schedule sent to your watch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep talks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear schedule'),
          ),
        ],
      ),
    );
    if (confirmed == true) await c.clear();
  }

  void _details(Talk talk) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                talk.track.toUpperCase(),
                style: const TextStyle(
                  color: lime,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                talk.title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              if (talk.presenter.isNotEmpty)
                _detailRow(Icons.person_outline, talk.presenter),
              _detailRow(Icons.place_outlined, talk.location),
              _detailRow(
                Icons.schedule,
                '${talk.dayLabel} · ${talk.timeLabel} PST',
              ),
              if (talk.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  talk.description,
                  style: const TextStyle(
                    color: muted,
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (talk.url.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: talk.url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event link copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Copy event link'),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    c.toggle(talk);
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    c.selectedIds.contains(talk.id) ? Icons.remove : Icons.add,
                  ),
                  label: Text(
                    c.selectedIds.contains(talk.id)
                        ? 'Remove from my schedule'
                        : 'Add to my schedule',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      if (!c.isLoaded) {
        return Scaffold(
          body: Center(
            child: c.error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.error!),
                      TextButton(
                        onPressed: c.initialize,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
          ),
        );
      }
      final catalogue = c.catalog!;
      if (!initializedDay) {
        initializedDay = true;
        final today = conferenceDay(widget.now());
        day = catalogue.days.any((d) => d.date == today)
            ? today
            : catalogue.days.first.date;
      }
      final wide = MediaQuery.sizeOf(context).width >= 960;
      final compact = MediaQuery.sizeOf(context).width < 600;
      final query = search.text.toLowerCase().trim();
      final source = tab == 1 ? c.selected : catalogue.talks;
      final talks =
          source
              .where(
                (t) =>
                    (day == null || t.day == day) &&
                    (track == 'All tracks' || t.track == track) &&
                    (query.isEmpty ||
                        '${t.title} ${t.presenter} ${t.location} ${t.track}'
                            .toLowerCase()
                            .contains(query)),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      final tracks = catalogue.talks.map((t) => t.track).toSet().toList()
        ..sort();
      return Scaffold(
        floatingActionButton: tab == 2
            ? null
            : FloatingActionButton.extended(
                onPressed: (tab == 1 && c.selected.isEmpty) ? null : _jumpToNow,
                icon: const Icon(Icons.schedule),
                label: const Text('Jump to now'),
              ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(compact),
                    const Divider(color: line, height: 1),
                    Padding(
                      padding: EdgeInsets.only(
                        top: compact ? 18 : 45,
                        bottom: compact ? 18 : 38,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI ENGINEER CODE 2026',
                                  style: TextStyle(
                                    color: lime,
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  compact
                                      ? 'Your conference, day by day.'
                                      : 'Your next talk.\nOne glance away.',
                                  style: TextStyle(
                                    fontSize: compact ? 28 : 53,
                                    fontWeight: FontWeight.w700,
                                    height: 1.06,
                                    letterSpacing: -1.8,
                                  ),
                                ),
                                const SizedBox(height: 19),
                                const Text(
                                  'Build your day here. Take it with you on your wrist.',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 10,
                                  children: [
                                    _meta(
                                      Icons.calendar_today_outlined,
                                      'NOV 10—12',
                                    ),
                                    _meta(
                                      Icons.place_outlined,
                                      'Hilton Union Square',
                                    ),
                                    _meta(Icons.public, 'Pacific time'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (wide)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: lime,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              width: 216,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.watch_outlined,
                                    color: ink,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    '${c.selected.length.toString().padLeft(2, '0')} talks',
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 31,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'YOUR POCKET SCHEDULE',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dayTabs(
                                catalogue.days
                                    .map((d) => (d.date, d.label))
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              _tabs(compact),
                              const SizedBox(height: 22),
                              if (tab == 2) ...[
                                WatchPreview(talks: c.selected),
                                const SizedBox(height: 20),
                                _syncPanel(),
                              ] else ...[
                                if (c.selected.isEmpty && search.text.isEmpty)
                                  _starter(),
                                if (c.error != null)
                                  _notice(
                                    c.error!,
                                    Icons.error_outline,
                                    const Color(0xFFF5AB89),
                                  ),
                                if (tab == 1 && c.hasConflicts)
                                  _notice(
                                    'Some talks overlap. Keep your options, or remove one to make room.',
                                    Icons.warning_amber_rounded,
                                    const Color(0xFFF5AB89),
                                  ),
                                _filters(
                                  catalogue.days
                                      .map((d) => (d.date, d.label))
                                      .toList(),
                                  tracks,
                                  compact,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      '${talks.length} ${tab == 1 ? 'chosen ' : ''}talks',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (tab == 1 && c.selected.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: _clear,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 15,
                                        ),
                                        label: const Text(
                                          'Clear',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    if (tab == 0)
                                      const Text(
                                        'ALL TIMES PST',
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 10,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (talks.isEmpty)
                                  _empty(tab == 1 && c.selected.isEmpty),
                                ..._timeline(talks, compact),
                              ],
                            ],
                          ),
                        ),
                        if (wide && tab != 2) ...[
                          const SizedBox(width: 36),
                          SizedBox(
                            width: 320,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: panel,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.watch_outlined,
                                            size: 18,
                                            color: lime,
                                          ),
                                          SizedBox(width: 9),
                                          Text(
                                            'ON YOUR WRIST',
                                            style: TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 1.7,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      WatchPreview(talks: c.selected),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _syncPanel(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 90),
                    const Divider(color: line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'AIE POCKET',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              color: muted,
                            ),
                          ),
                          Text(
                            'Nov 10 snapshot · ${catalogue.talks.length} sessions · Pacific time',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _header(bool compact) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.blur_on_rounded, color: ink, size: 25),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'aie pocket',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
        ),
        if (!compact)
          const Text(
            'LESS PHONE. MORE CONFERENCE.',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.6),
          ),
        if (compact)
          Text(
            '${c.selected.length} chosen',
            style: const TextStyle(color: lime, fontSize: 12),
          ),
      ],
    ),
  );

  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: muted),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ],
  );

  Widget _tabs(bool compact) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        for (final item in [
          (0, 'Explore'),
          (1, compact ? 'My talks' : 'My schedule'),
          (2, 'Watch preview'),
        ])
          Expanded(
            child: Semantics(
              selected: tab == item.$1,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  tab = item.$1;
                  track = 'All tracks';
                  search.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == item.$1 ? lime : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: tab == item.$1 ? lime : muted,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _starter() => Container(
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1B241D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF354631)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A good place to start.',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 7),
        const Text(
          'Choose your own talks, or start with the field guide’s suggested path.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.useRecommended,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Use suggested path'),
        ),
      ],
    ),
  );

  Widget _filters(
    List<(String, String)> days,
    List<String> tracks,
    bool compact,
  ) => Column(
    key: const ValueKey('schedule-filters'),
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Find a talk, speaker, or room',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(search.clear),
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            SizedBox(width: 170, child: _trackMenu(tracks)),
          ],
        ],
      ),
      const SizedBox(height: 12),
      if (compact) ...[const SizedBox(height: 12), _trackMenu(tracks)],
    ],
  );

  Widget _dayTabs(List<(String, String)> days) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: ValueKey('day-${d.$1}'),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final part in d.$2.split(', ')) Text(part)],
                  ),
                  selected: day == d.$1,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    day = d.$1;
                    highlightedId = null;
                  }),
                ),
              ),
            ),
        ],
      ),
      TextButton(
        onPressed: () => setState(() {
          day = null;
          highlightedId = null;
        }),
        child: Text(day == null ? 'Showing all days' : 'View all days'),
      ),
    ],
  );

  List<Widget> _timeline(List<Talk> talks, bool compact) {
    final items = <Widget>[];
    String? previousDay;
    DateTime? previousStart;
    for (final talk in talks) {
      if (previousDay != talk.day) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              talk.dayLabel,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
          ),
        );
        previousDay = talk.day;
        previousStart = null;
      }
      if (previousStart != talk.start) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Row(
              children: [
                Text(
                  talk.startTimeLabel,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Divider(color: line)),
              ],
            ),
          ),
        );
        previousStart = talk.start;
      }
      items.add(
        Padding(
          key: talkKeys.putIfAbsent(talk.id, GlobalKey.new),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlightedId == talk.id)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    talk.end.isAfter(widget.now())
                        ? (talk.start.isAfter(widget.now())
                              ? 'UP NEXT'
                              : 'HAPPENING NOW')
                        : 'FINAL SESSION · CONFERENCE ENDED',
                    style: const TextStyle(
                      color: lime,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              _talkCard(talk, compact),
            ],
          ),
        ),
      );
    }
    return items;
  }

  Widget _trackMenu(List<String> tracks) => DropdownButtonFormField<String>(
    initialValue: track,
    key: ValueKey(track),
    isExpanded: true,
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    items: ['All tracks', ...tracks]
        .map(
          (t) => DropdownMenuItem(
            value: t,
            child: Text(
              t,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => track = v ?? 'All tracks'),
  );

  Widget _talkCard(Talk talk, bool compact) {
    final selected = c.selectedIds.contains(talk.id);
    final conflicts = selected ? c.conflictsFor(talk) : <Talk>[];
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF172018) : panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlightedId == talk.id
              ? lime
              : selected
              ? const Color(0xFF68834B)
              : line,
          width: highlightedId == talk.id ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _details(talk),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.all(compact ? 18 : 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                SizedBox(
                  width: 91,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        talk.startIso.substring(11, 16),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5,
                          color: selected ? lime : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        talk.dayLabel,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 82, color: line),
                const SizedBox(width: 22),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            talk.track.toUpperCase(),
                            style: TextStyle(
                              color: trackColor(talk.track),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'CHOSEN',
                              style: TextStyle(
                                color: lime,
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      talk.title,
                      style: TextStyle(
                        fontSize: compact ? 18 : 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      talk.presenter,
                      style: const TextStyle(
                        color: Color(0xFFC1C8D0),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            talk.location,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${compact ? '${talk.dayLabel} · ' : ''}${talk.timeLabel} PST',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    if (conflicts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Overlaps with ${conflicts.length} chosen ${conflicts.length == 1 ? 'talk' : 'talks'}',
                          style: const TextStyle(
                            color: Color(0xFFF5AB89),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '${selected ? 'Remove' : 'Choose'} ${talk.title}',
                onPressed: () => c.toggle(talk),
                style: IconButton.styleFrom(
                  backgroundColor: selected ? lime : const Color(0xFF242D35),
                  foregroundColor: selected ? ink : Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                icon: Icon(selected ? Icons.check : Icons.add, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _empty(bool nothingChosen) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(
          nothingChosen ? Icons.bookmark_border : Icons.search_off,
          color: muted,
          size: 30,
        ),
        const SizedBox(height: 15),
        Text(
          nothingChosen ? 'Your day is yours to build.' : 'No matching talks.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          nothingChosen
              ? 'Tap + on a talk to add it to your watch.'
              : 'Try another speaker, day, or track.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 13),
        ),
        if (!nothingChosen)
          TextButton(
            onPressed: () => setState(() {
              search.clear();
              day = null;
              track = 'All tracks';
            }),
            child: const Text('Reset filters'),
          ),
      ],
    ),
  );

  Widget _syncPanel() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              kIsWeb ? Icons.devices_outlined : Icons.sync,
              size: 17,
              color: lime,
            ),
            const SizedBox(width: 9),
            Text(
              kIsWeb ? 'Companion preview' : 'Apple Watch',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          c.syncStatus.message,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Picks save in this browser. The installed iPhone app sends them to Apple Watch.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ),
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton.icon(
              onPressed: c.sync,
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Sync schedule'),
            ),
          ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(Icons.offline_pin_outlined, size: 14, color: muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Available offline on your watch after transfer.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Color trackColor(String track) {
  const colors = [
    Color(0xFFA6C9FF),
    Color(0xFFC7F78C),
    Color(0xFFEEB89C),
    Color(0xFFC4B5FD),
    Color(0xFF87DCD0),
  ];
  return colors[track.codeUnits.fold(0, (int a, b) => a + b) % colors.length];
}
