import 'dart:math';
import 'package:flutter/material.dart';

/// Renders weather-themed particle effects overlaid on the background.
/// Rain: falling streaks. Snow: drifting dots. Clear: subtle float.
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
    if (code == null || code == 'clear') return const SizedBox.shrink();

    final count = code == 'rain' ? 40 : (code == 'snow' ? 25 : 0);
    if (count == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          size: Size.infinite,
          painter: code == 'rain' ? _RainPainter(t, _random, count)
                                  : _SnowPainter(t, _random, count),
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final double t;
  final Random random;
  final int count;

  _RainPainter(this.t, this.random, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF818cf8).withOpacity(0.12)
      ..strokeWidth = 1.0;

    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.4;
      final y = ((random.nextDouble() + t) * speed % 1.0) * size.height;
      final len = 8.0 + random.nextDouble() * 14;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.5, y - len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t;
}

class _SnowPainter extends CustomPainter {
  final double t;
  final Random random;
  final int count;

  _SnowPainter(this.t, this.random, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15);

    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final drift = sin(t * 2 * pi + i) * 10;
      final speed = 0.3 + random.nextDouble() * 0.5;
      final y = ((random.nextDouble() + t * speed) % 1.0) * size.height;
      final r = 1.5 + random.nextDouble() * 2.5;

      canvas.drawCircle(Offset(x + drift, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => old.t != t;
}
