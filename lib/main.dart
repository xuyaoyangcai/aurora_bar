import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'state/app_state.dart';
import 'widgets/bar_view.dart';
import 'widgets/panel_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const collapsedSize = Size(360, 60);
  final display = await screenRetriever.getPrimaryDisplay();
  final workArea = display.visibleSize ?? display.size;
  final workOrigin = display.visiblePosition ?? Offset.zero;
  final x = workOrigin.dx + workArea.width - collapsedSize.width - 12;
  final y = workOrigin.dy + workArea.height * 0.2;

  await windowManager.setAlwaysOnTop(true);
  await windowManager.setAsFrameless();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setSize(collapsedSize);
  await windowManager.setPosition(Offset(x, y));
  await windowManager.show();
  await windowManager.focus();

  final state = AppState();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.transparent,
    ),
    home: AuroraApp(state: state, collapsedOrigin: Offset(x, y)),
  ));
}

class AuroraApp extends StatefulWidget {
  final AppState state;
  final Offset collapsedOrigin;
  const AuroraApp({super.key, required this.state, required this.collapsedOrigin});

  @override
  State<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends State<AuroraApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.state.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _expand() async {
    await windowManager.setSize(const Size(360, 420));
    final newY = widget.collapsedOrigin.dy - 180;
    await windowManager.setPosition(
        Offset(widget.collapsedOrigin.dx, newY.clamp(0, 9999)));
    widget.state.toggleExpanded();
  }

  Future<void> _collapse() async {
    await windowManager.setSize(const Size(360, 60));
    await windowManager.setPosition(widget.collapsedOrigin);
    widget.state.toggleExpanded();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: BarView(),
      );
    }
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        if (!widget.state.isExpanded) {
          return GestureDetector(
            onTap: _expand,
            onPanStart: (_) => windowManager.startDragging(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: BarView(taskCount: widget.state.activeCount),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: PanelView(
            state: widget.state,
            onCollapse: _collapse,
          ),
        );
      },
    );
  }
}
