import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'schedule_controller.dart';
import 'ui/schedule_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep web controls exposed to keyboard users and browser automation.
  SemanticsBinding.instance.ensureSemantics();
  runApp(const AiePocketApp());
}

class AiePocketApp extends StatefulWidget {
  const AiePocketApp({super.key, this.controller, this.now = DateTime.now});
  final ScheduleController? controller;
  final DateTime Function() now;

  @override
  State<AiePocketApp> createState() => _AiePocketAppState();
}

class _AiePocketAppState extends State<AiePocketApp> {
  late final ScheduleController controller =
      widget.controller ?? ScheduleController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIE Pocket — Your talks, at a glance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E12),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC7F78C),
          brightness: Brightness.dark,
          primary: const Color(0xFFC7F78C),
          surface: const Color(0xFF14191F),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF14191F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: ScheduleScreen(controller: controller, now: widget.now),
    );
  }
}
