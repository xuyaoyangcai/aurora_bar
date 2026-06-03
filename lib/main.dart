import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'state/app_state.dart';
import 'services/storage_service.dart';
import 'services/weather_service.dart';
import 'widgets/bar_view.dart';
import 'widgets/panel_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const collapsedSize = Size(360, 60);
  final display = await screenRetriever.getPrimaryDisplay();
  final workArea = display.visibleSize ?? display.size;
  final workOrigin = display.visiblePosition ?? Offset.zero;
  final screenRight = workOrigin.dx + workArea.width;

  final storage = StorageService();
  final config = await storage.loadConfig();
  final savedX = (config['x'] as num?)?.toDouble();
  final savedY = (config['y'] as num?)?.toDouble();
  final x = savedX ?? (screenRight - collapsedSize.width - 12);
  final y = savedY ?? (workOrigin.dy + workArea.height * 0.2);

  await windowManager.setAlwaysOnTop(true);
  await windowManager.setAsFrameless();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setSize(collapsedSize);
  await windowManager.setPosition(Offset(x, y));
  await windowManager.show();
  await windowManager.focus();

  final state = AppState();

  // First-run setup
  if (config['autoStart'] == null) {
    final exePath = Platform.resolvedExecutable;
    await _createStartupShortcut(exePath);
    await _createDesktopShortcut(exePath);
    await storage.saveConfig({...config, 'autoStart': true});
  }

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.transparent,
    ),
    home: AuroraApp(
      state: state,
      collapsedOrigin: Offset(x, y),
      screenRight: screenRight,
    ),
  ));
}

Future<void> _createStartupShortcut(String exePath) async {
  try {
    final appData =
        Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? '.';
    final dir = Directory(
        '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup');
    if (!await dir.exists()) await dir.create(recursive: true);
    final vbs = File('${dir.path}\\AuroraBar.vbs');
    await vbs.writeAsString(
      'CreateObject("WScript.Shell").Run """$exePath""", 0, False',
    );
  } catch (_) {}
}

Future<void> _createDesktopShortcut(String exePath) async {
  try {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ?? '.';
    final desktop = '$home\\Desktop';
    if (!Directory(desktop).existsSync()) return;

    final lnkPath = '$desktop\\Aurora.lnk';
    // Skip if already exists
    if (File(lnkPath).existsSync()) return;

    // Write temp PowerShell script and execute synchronously
    final psFile = File('$desktop\\_aurora_setup.ps1');
    await psFile.writeAsString('''
\$ws = New-Object -ComObject WScript.Shell
\$sc = \$ws.CreateShortcut('$lnkPath')
\$sc.TargetPath = '$exePath'
\$sc.WorkingDirectory = '${Directory(exePath).parent.path}'
\$sc.Description = 'Aurora'
\$sc.WindowStyle = 7
\$sc.Save()
''');
    await Process.run(
      'powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psFile.path],
    );
    // Cleanup
    psFile.deleteSync();
    final oldVbs = File('$desktop\\AuroraBar.vbs');
    if (oldVbs.existsSync()) oldVbs.deleteSync();
  } catch (_) {}
}

class AuroraApp extends StatefulWidget {
  final AppState state;
  final Offset collapsedOrigin;
  final double screenRight;
  const AuroraApp({
    super.key,
    required this.state,
    required this.collapsedOrigin,
    required this.screenRight,
  });

  @override
  State<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends State<AuroraApp> {
  bool _ready = false;
  final WeatherService _weather = WeatherService();
  String? _weatherCode;
  late Offset _currentOrigin;
  Offset? _prePeekOrigin; // frozen snapshot before peek, never overwritten by drag

  @override
  void initState() {
    super.initState();
    _currentOrigin = widget.collapsedOrigin;
    widget.state.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
    _updateWeather();
  }

  Future<void> _updateWeather() async {
    final code = await _weather.fetch();
    if (mounted && code != _weatherCode) {
      setState(() => _weatherCode = code);
      widget.state.themeEngine.setWeather(code);
    }
  }

  Future<void> _savePosition() async {
    final pos = await windowManager.getPosition();
    _currentOrigin = pos;
    widget.state.saveConfig({'x': pos.dx, 'y': pos.dy});
  }

  Future<void> _expand() async {
    await _savePosition();
    await windowManager.setSize(const Size(360, 420));
    final newY = _currentOrigin.dy - 180;
    await windowManager.setPosition(
        Offset(_currentOrigin.dx, newY.clamp(0, 9999)));
    widget.state.toggleExpanded();
  }

  Future<void> _collapse() async {
    final pos = await windowManager.getPosition();
    _currentOrigin = Offset(pos.dx, pos.dy + 180);
    widget.state.saveConfig({'x': _currentOrigin.dx, 'y': _currentOrigin.dy});

    await windowManager.setSize(const Size(360, 60));
    await windowManager.setPosition(_currentOrigin);
    widget.state.toggleExpanded();
  }

  Future<void> _peek() async {
    // Freeze the bar position BEFORE resizing to peek
    _prePeekOrigin = await windowManager.getPosition();
    widget.state.saveConfig({'x': _prePeekOrigin!.dx, 'y': _prePeekOrigin!.dy});
    const peekWidth = 28.0;
    final peekX = widget.screenRight - peekWidth;
    await windowManager.setSize(const Size(peekWidth, 60));
    await windowManager.setPosition(Offset(peekX, _prePeekOrigin!.dy));
    widget.state.togglePeek();
  }

  Future<void> _unpeek() async {
    final origin = _prePeekOrigin ?? _currentOrigin;
    // Clamp X so the bar stays fully on screen
    final clampedX = origin.dx.clamp(0.0, widget.screenRight - 360);
    await windowManager.setSize(const Size(360, 60));
    await windowManager.setPosition(Offset(clampedX, origin.dy));
    _currentOrigin = Offset(clampedX, origin.dy);
    widget.state.saveConfig({'x': _currentOrigin.dx, 'y': _currentOrigin.dy});
    _prePeekOrigin = null;
    widget.state.togglePeek();
  }

  void _quitApp() {
    windowManager.destroy().then((_) => exit(0));
    Future.delayed(const Duration(milliseconds: 500), () => exit(0));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final loadingPalette = widget.state.themeEngine.compute(DateTime.now());
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: BarView(palette: loadingPalette),
      );
    }
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final palette = widget.state.themeEngine.compute(DateTime.now());
        if (widget.state.isExpanded) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: PanelView(
              state: widget.state,
              onCollapse: _collapse,
              palette: palette,
              weatherCode: _weatherCode,
            ),
          );
        }
        if (widget.state.isPeeking) {
          return GestureDetector(
            onTap: _unpeek,
            onPanStart: (_) => windowManager.startDragging(),
            onPanEnd: (_) => _savePosition(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.accent1.withOpacity(0.6), palette.backgroundStart.withOpacity(0.8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1), width: 0.5),
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome,
                      size: 10, color: palette.accent1),
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () { _expand(); _updateWeather(); },
          onPanStart: (_) => windowManager.startDragging(),
          onPanEnd: (_) => _savePosition(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: BarView(
              taskCount: widget.state.activeCount,
              onPeek: _peek,
              onQuit: _quitApp,
              palette: palette,
              weatherCode: _weatherCode,
            ),
          ),
        );
      },
    );
  }
}
