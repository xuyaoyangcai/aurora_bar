import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/theme_engine.dart';

/// Maps weather code string to shader float: 0=clear, 1=cloud/fog, 2=rain, 3=snow
double _weatherType(String? code) {
  switch (code) {
    case 'cloudy':
    case 'fog':
      return 1.0;
    case 'rain':
      return 2.0;
    case 'snow':
      return 3.0;
    default:
      return 0.0;
  }
}

/// Renders a dynamic background combining:
/// - Animated gradient from ThemeEngine palette
/// - GPU aurora shader overlay with weather distortion
class DynamicBackground extends StatefulWidget {
  final AuroraPalette palette;
  final bool showAurora;
  final Widget? child;
  final String? weatherCode;
  final double weatherIntensity;

  const DynamicBackground({
    super.key,
    required this.palette,
    this.showAurora = true,
    this.child,
    this.weatherCode,
    this.weatherIntensity = 0.0,
  });

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static ui.FragmentProgram? _auroraProgram;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _preloadShader();
  }

  static Future<void> _preloadShader() async {
    if (_auroraProgram != null) return;
    try {
      _auroraProgram = await ui.FragmentProgram.fromAsset('lib/shaders/aurora.frag');
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.palette;
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pal.backgroundStart, pal.backgroundMid, pal.backgroundEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (widget.showAurora && _auroraProgram != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(
                    program: _auroraProgram!,
                    time: _controller.value * 60,
                    palette: pal,
                    weatherType: _weatherType(widget.weatherCode),
                    weatherIntensity: widget.weatherIntensity,
                  ),
                ),
              ),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final AuroraPalette palette;
  final double weatherType;
  final double weatherIntensity;

  _AuroraPainter({
    required this.program,
    required this.time,
    required this.palette,
    this.weatherType = 0.0,
    this.weatherIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, palette.accent1.red / 255.0)
      ..setFloat(4, palette.accent1.green / 255.0)
      ..setFloat(5, palette.accent1.blue / 255.0)
      ..setFloat(6, palette.accent2.red / 255.0)
      ..setFloat(7, palette.accent2.green / 255.0)
      ..setFloat(8, palette.accent2.blue / 255.0)
      ..setFloat(9, palette.backgroundStart.red / 255.0)
      ..setFloat(10, palette.backgroundStart.green / 255.0)
      ..setFloat(11, palette.backgroundStart.blue / 255.0)
      ..setFloat(12, weatherType)
      ..setFloat(13, weatherIntensity);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.time != time ||
      old.palette != palette ||
      old.weatherType != weatherType ||
      old.weatherIntensity != weatherIntensity;
}
