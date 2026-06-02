import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWindow();
  runApp(const AuroraBar());
}

Future<void> _initWindow() async {
  await windowManager.ensureInitialized();

  const barSize = Size(360, 60);

  // Get screen size from platform dispatcher
  final view = PlatformDispatcher.instance.views.first;
  final screenSize = view.physicalSize / view.devicePixelRatio;

  final x = screenSize.width - barSize.width;
  final y = screenSize.height / 2 - barSize.height / 2;

  await windowManager.setSize(barSize);
  await windowManager.setPosition(Offset(x, y));
  await windowManager.setAsFrameless();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setSkipTaskbar(false);
  await windowManager.show();
  await windowManager.focus();
}

class AuroraBar extends StatelessWidget {
  const AuroraBar({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const BarWidget(),
    );
  }
}

class BarWidget extends StatefulWidget {
  const BarWidget({super.key});

  @override
  State<BarWidget> createState() => _BarWidgetState();
}

class _BarWidgetState extends State<BarWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanUpdate: (details) {},
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xCC1a1a2e),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Aurora',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
