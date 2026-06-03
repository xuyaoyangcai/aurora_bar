import 'dart:async';
import 'package:flutter/material.dart';
import '../services/theme_engine.dart';
import 'dynamic_background.dart';
import 'weather_particle.dart';

class BarView extends StatefulWidget {
  final int taskCount;
  final VoidCallback? onPeek;
  final VoidCallback? onQuit;
  final AuroraPalette palette;
  final String? weatherCode;

  const BarView({
    super.key,
    this.taskCount = 0,
    this.onPeek,
    this.onQuit,
    required this.palette,
    this.weatherCode,
  });

  @override
  State<BarView> createState() => _BarViewState();
}

class _BarViewState extends State<BarView> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DynamicBackground(
        palette: widget.palette,
        showAurora: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: WeatherParticle(weatherCode: widget.weatherCode),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.palette.accent1.withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: widget.palette.accent1.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [widget.palette.accent1, widget.palette.accent2],
                    ).createShader(bounds),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$h:$m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          ':$s',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Task count badge
                  if (widget.taskCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.palette.accent2.withOpacity(0.8),
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  const SizedBox(width: 10),
                  // Peek arrow button
                  if (widget.onPeek != null)
                    GestureDetector(
                      onTap: widget.onPeek,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.chevron_right,
                            size: 14, color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Quit button
                  if (widget.onQuit != null)
                    GestureDetector(
                      onTap: widget.onQuit,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.power_settings_new,
                            size: 12, color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
