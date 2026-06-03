import 'dart:math';
import 'package:flutter/material.dart';

/// Renders weather-themed particle effects with glow and blend modes.
class WeatherParticle extends StatefulWidget {
  final String? weatherCode;
  final double intensity; // 0.0 → 1.0 from ThemeEngine

  const WeatherParticle({super.key, this.weatherCode, this.intensity = 0.0});

  @override
  State<WeatherParticle> createState() => _WeatherParticleState();
}

class _WeatherParticleState extends State<WeatherParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(
            _controller.value,
            _random,
            widget.weatherCode,
            widget.intensity,
          ),
        );
      },
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final double t;
  final Random random;
  final String? weatherCode;
  final double intensity;

  _WeatherPainter(this.t, this.random, this.weatherCode, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    switch (weatherCode) {
      case 'rain':
        _drawRain(canvas, size);
        _drawAccumulation(canvas, size);
        break;
      case 'snow':
        _drawSnow(canvas, size);
        _drawAccumulation(canvas, size);
        break;
      case 'fog':
      case 'cloudy':
        _drawClouds(canvas, size);
        _drawAccumulation(canvas, size);
        break;
      default:
        _drawShimmer(canvas, size);
        break;
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    // Glow layer via saveLayer with Screen blend
    final glowPaint = Paint()
      ..color = const Color(0xFF818cf8).withOpacity(0.25)
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final corePaint = Paint()
      ..color = const Color(0xFFa5b4fc).withOpacity(0.35)
      ..strokeWidth = 1.0;

    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.screen);
    for (var i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.5;
      final y = ((random.nextDouble() + t) * speed % 1.0) * size.height;
      final len = 10.0 + random.nextDouble() * 22; // longer, more varied
      final offset = Offset(x - 2.0, y);
      final end = Offset(x - 2.0, y - len);
      // Glow pass
      canvas.drawLine(offset, end, glowPaint);
      // Core pass
      canvas.drawLine(offset, end, corePaint);
    }
    canvas.restore();
  }

  void _drawSnow(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.35);

    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.screen);
    for (var i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      // Wider drift amplitude
      final drift = sin(t * 2.5 * pi + i * 1.3) * (12.0 + random.nextDouble() * 8);
      final speed = 0.25 + random.nextDouble() * 0.45;
      final y = ((random.nextDouble() + t * speed) % 1.0) * size.height;
      final r = 1.8 + random.nextDouble() * 3.0;
      final center = Offset(x + drift, y);
      canvas.drawCircle(center, r + 1.0, glowPaint);
      canvas.drawCircle(center, r, corePaint);
    }
    canvas.restore();
  }

  void _drawClouds(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.06);

    for (var i = 0; i < 10; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height * 0.5;
      final drift = t * (20 + random.nextDouble() * 50);
      final x = (baseX + drift) % (size.width + 80) - 40;
      final r = 25 + random.nextDouble() * 35;
      final center = Offset(x, baseY);
      canvas.drawCircle(center, r + 6, glowPaint);
      canvas.drawCircle(center, r, corePaint);
      canvas.drawCircle(
        Offset(x + r * 0.6, baseY - r * 0.3), r * 0.7 + 4, glowPaint);
      canvas.drawCircle(
        Offset(x + r * 0.6, baseY - r * 0.3), r * 0.7, corePaint);
    }
  }

  void _drawShimmer(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFc084fc).withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (var i = 0; i < 8; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final drift = sin(t * pi + i * 1.7) * 18;
      final r = 4 + random.nextDouble() * 5;
      canvas.drawCircle(Offset(baseX + drift, baseY), r, paint);
    }
  }

  /// Top-edge accumulation: snow buildup / water line / fog band.
  void _drawAccumulation(Canvas canvas, Size size) {
    if (intensity <= 0.01) return;
    final w = size.width;
    final thickness = intensity * 18.0; // grows 0→18px

    switch (weatherCode) {
      case 'snow':
        // Snow buildup: layered white RRect, blurred
        final snowPaint = Paint()
          ..color = Colors.white.withOpacity(0.15 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        for (var layer = 0; layer < 3; layer++) {
          final yOff = layer * 4.0;
          final h = (thickness - yOff).clamp(0.0, thickness);
          canvas.drawRRect(
            RRect.fromLTRBR(0, -4 + yOff, w, h, const Radius.circular(2)),
            snowPaint,
          );
        }
        // Bright highlight rim
        final rimPaint = Paint()
          ..color = Colors.white.withOpacity(0.3 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawRRect(
          RRect.fromLTRBR(0, -2, w, thickness * 0.4, const Radius.circular(1)),
          rimPaint,
        );
        break;

      case 'rain':
        // Water / wet line: dark blurry band at top
        final waterPaint = Paint()
          ..color = const Color(0xFF4a6fa5).withOpacity(0.10 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawRRect(
          RRect.fromLTRBR(0, -2, w, thickness, const Radius.circular(3)),
          waterPaint,
        );
        // Thin drip highlights
        final dripPaint = Paint()
          ..color = const Color(0xFFa0b8d8).withOpacity(0.08 * intensity)
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
        for (var i = 0; i < 6; i++) {
          final dx = random.nextDouble() * w;
          final dripLen = 4.0 + random.nextDouble() * thickness * 0.7;
          canvas.drawLine(
            Offset(dx, 0),
            Offset(dx + random.nextDouble() * 2 - 1, dripLen),
            dripPaint,
          );
        }
        break;

      case 'fog':
      case 'cloudy':
        // Mist band at top
        final mistPaint = Paint()
          ..color = Colors.white.withOpacity(0.04 * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        canvas.drawRRect(
          RRect.fromLTRBR(-10, -10, w + 10, thickness * 2.5, const Radius.circular(12)),
          mistPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.t != t ||
      old.weatherCode != weatherCode ||
      old.intensity != intensity;
}
