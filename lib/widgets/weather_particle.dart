import 'dart:math';
import 'package:flutter/material.dart';

/// Renders weather-themed particle effects overlaid on the background.
class WeatherParticle extends StatefulWidget {
  final String? weatherCode;

  const WeatherParticle({super.key, this.weatherCode});

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
    final code = widget.weatherCode;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(t, _random, code),
        );
      },
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final double t;
  final Random random;
  final String? weatherCode;

  _WeatherPainter(this.t, this.random, this.weatherCode);

  @override
  void paint(Canvas canvas, Size size) {
    switch (weatherCode) {
      case 'rain':
        _drawRain(canvas, size);
        break;
      case 'snow':
        _drawSnow(canvas, size);
        break;
      case 'fog':
      case 'cloudy':
        _drawClouds(canvas, size);
        break;
      default:
        _drawShimmer(canvas, size);
        break;
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF818cf8).withOpacity(0.12)
      ..strokeWidth = 1.0;

    for (var i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.4;
      final y = ((random.nextDouble() + t) * speed % 1.0) * size.height;
      final len = 8.0 + random.nextDouble() * 14;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y - len), paint);
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15);

    for (var i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final drift = sin(t * 2 * pi + i) * 10;
      final speed = 0.3 + random.nextDouble() * 0.5;
      final y = ((random.nextDouble() + t * speed) % 1.0) * size.height;
      final r = 1.5 + random.nextDouble() * 2.5;
      canvas.drawCircle(Offset(x + drift, y), r, paint);
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04);

    for (var i = 0; i < 8; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height * 0.4;
      final drift = t * (20 + random.nextDouble() * 40);
      final x = (baseX + drift) % (size.width + 60) - 30;
      final r = 20 + random.nextDouble() * 30;
      canvas.drawCircle(Offset(x, baseY), r, paint);
      canvas.drawCircle(Offset(x + r * 0.6, baseY - r * 0.3), r * 0.7, paint);
    }
  }

  void _drawShimmer(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFc084fc).withOpacity(0.03);

    for (var i = 0; i < 6; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final drift = sin(t * pi + i * 1.7) * 15;
      final r = 3 + random.nextDouble() * 4;
      canvas.drawCircle(Offset(baseX + drift, baseY), r, paint);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.t != t || old.weatherCode != weatherCode;
}
