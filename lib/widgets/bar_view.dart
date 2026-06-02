import 'dart:async';
import 'package:flutter/material.dart';

class BarView extends StatefulWidget {
  final int taskCount;
  const BarView({super.key, this.taskCount = 0});

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

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xDD0f0c29), Color(0xDD302b63), Color(0xDD24243e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // Aurora dot indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF818cf8).withOpacity(0.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF818cf8).withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Clock with seconds
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF818cf8), Color(0xFFc084fc)],
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
                color: const Color(0xFFc084fc).withOpacity(0.8),
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
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
