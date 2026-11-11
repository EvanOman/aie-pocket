import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/talk.dart';
import 'schedule_screen.dart' show lime, muted, trackColor;

/// A companion preview of the native watch card, not a watchOS simulator.
class WatchPreview extends StatefulWidget {
  const WatchPreview({super.key, required this.talks});
  final List<Talk> talks;

  @override
  State<WatchPreview> createState() => _WatchPreviewState();
}

class _WatchPreviewState extends State<WatchPreview> {
  final pages = PageController();
  int index = 0;
  String get signature => widget.talks.map((t) => t.id).join(',');

  @override
  void didUpdateWidget(covariant WatchPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.talks.map((t) => t.id).join(',');
    if (oldIds != signature) {
      index = math.min(index, math.max(0, widget.talks.length - 1));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients) pages.jumpToPage(index);
      });
    }
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (widget.talks.isEmpty) return;
    final target = (index + delta).clamp(0, widget.talks.length - 1);
    pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Center(
        child: SizedBox(
          width: 270,
          height: 326,
          child: Stack(
            children: [
              Positioned(
                top: 82,
                right: 1,
                child: Container(
                  width: 10,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFF62676B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Positioned(
                top: 140,
                right: 2,
                child: Container(
                  width: 5,
                  height: 49,
                  decoration: BoxDecoration(
                    color: const Color(0xFF45494C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 9,
                top: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272C30),
                    borderRadius: BorderRadius.circular(58),
                    border: Border.all(
                      color: const Color(0xFF62696E),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(47),
                    child: Container(
                      color: Colors.black,
                      child: widget.talks.isEmpty
                          ? _empty()
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    16,
                                    22,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.blur_on_rounded,
                                        size: 16,
                                        color: lime,
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${index + 1}/${widget.talks.length}',
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: PageView.builder(
                                    controller: pages,
                                    itemCount: widget.talks.length,
                                    onPageChanged: (i) =>
                                        setState(() => index = i),
                                    itemBuilder: (context, i) =>
                                        _card(widget.talks[i]),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 13,
                                    top: 7,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      math.min(widget.talks.length, 7),
                                      (i) => Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: i == index % 7 ? 13 : 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: i == index % 7
                                              ? lime
                                              : const Color(0xFF333A40),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous watch card',
            onPressed: index > 0 ? () => move(-1) : null,
            icon: const Icon(Icons.chevron_left, size: 22),
          ),
          Flexible(
            child: Text(
              widget.talks.isEmpty
                  ? 'YOUR TALKS, AT A GLANCE'
                  : '${index + 1} OF ${widget.talks.length} TALKS',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 9,
                letterSpacing: 1.3,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next watch card',
            onPressed: index < widget.talks.length - 1 ? () => move(1) : null,
            icon: const Icon(Icons.chevron_right, size: 22),
          ),
        ],
      ),
      const Text(
        'Swipe cards · Scroll for the full title',
        style: TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );

  Widget _empty() => const Padding(
    padding: EdgeInsets.all(25),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bookmark_border_rounded, color: lime, size: 35),
        SizedBox(height: 19),
        Text(
          'A little space\nfor your big ideas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Choose a talk on your phone\nto see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
      ],
    ),
  );

  Widget _card(Talk talk) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          talk.dayLabel.toUpperCase(),
          style: const TextStyle(color: muted, fontSize: 8, letterSpacing: 1.2),
        ),
        const SizedBox(height: 5),
        Text(
          talk.timeLabel,
          style: TextStyle(
            color: trackColor(talk.track),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          talk.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 12),
        if (talk.presenter.isNotEmpty)
          Text(
            talk.presenter,
            style: const TextStyle(
              color: Color(0xFFC4CBD2),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2423),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, color: lime, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  talk.location,
                  style: const TextStyle(
                    color: lime,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
