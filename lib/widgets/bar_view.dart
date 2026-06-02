import 'dart:async';
import 'package:flutter/material.dart';

class BarView extends StatefulWidget {
  final bool clockOnly;
  const BarView({super.key, this.clockOnly = false});

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
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF818cf8), Color(0xFFc084fc)],
          ).createShader(bounds),
          child: Text(
            '$h:$m',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w200,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
