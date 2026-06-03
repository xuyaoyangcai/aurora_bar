import 'package:flutter/material.dart';

enum Mood { calm, focused, energetic, tired, creative }

/// Produces a dynamic color palette based on time of day, weather, and mood.
class AuroraPalette {
  final Color primary;
  final Color secondary;
  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color accent1;
  final Color accent2;

  const AuroraPalette({
    required this.primary,
    required this.secondary,
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.accent1,
    required this.accent2,
  });
}

class ThemeEngine {
  Mood _mood = Mood.calm;
  String? _weatherCode; // 'clear', 'cloudy', 'rain', 'snow', 'fog'
  String? _prevWeatherCode;
  double _weatherIntensity = 0.0;

  /// Current weather code (for shader mapping).
  String? get weatherCode => _weatherCode;

  /// Slowly ramps 0→1 while same weather persists; resets on change.
  double get weatherIntensity => _weatherIntensity;

  void setMood(Mood mood) => _mood = mood;
  void setWeather(String? code) => _weatherCode = code;

  AuroraPalette compute(DateTime now) {
    final hour = now.hour + now.minute / 60.0;

    // Base palettes for key times
    final dawn = _dawnPalette();
    final noon = _noonPalette();
    final dusk = _duskPalette();
    final midnight = _midnightPalette();

    AuroraPalette base;
    if (hour < 6) {
      base = midnight;
    } else if (hour < 8) {
      base = _blendPalettes(midnight, dawn, (hour - 6) / 2);
    } else if (hour < 12) {
      base = _blendPalettes(dawn, noon, (hour - 8) / 4);
    } else if (hour < 17) {
      base = noon;
    } else if (hour < 19) {
      base = _blendPalettes(noon, dusk, (hour - 17) / 2);
    } else if (hour < 22) {
      base = _blendPalettes(dusk, midnight, (hour - 19) / 3);
    } else {
      base = midnight;
    }

    base = _applyWeather(base);
    base = _applyMood(base);

    // Ramp weather intensity: up when same non-clear weather persists, reset on change
    if (_weatherCode != null && _weatherCode != 'clear' && _weatherCode == _prevWeatherCode) {
      _weatherIntensity = (_weatherIntensity + 0.0004).clamp(0.0, 1.0);
    } else {
      _weatherIntensity = 0.0;
    }
    _prevWeatherCode = _weatherCode;

    return base;
  }

  AuroraPalette _dawnPalette() => const AuroraPalette(
    primary: Color(0xFF818cf8), secondary: Color(0xFFc084fc),
    backgroundStart: Color(0xFF1a1a3e), backgroundMid: Color(0xFF2d2b55),
    backgroundEnd: Color(0xFF3b2a4a),
    accent1: Color(0xFFa78bfa), accent2: Color(0xFFf9a8d4),
  );

  AuroraPalette _noonPalette() => const AuroraPalette(
    primary: Color(0xFF60a5fa), secondary: Color(0xFF34d399),
    backgroundStart: Color(0xFF1e3a5f), backgroundMid: Color(0xFF2563a0),
    backgroundEnd: Color(0xFF1e4d6b),
    accent1: Color(0xFF38bdf8), accent2: Color(0xFF4ade80),
  );

  AuroraPalette _duskPalette() => const AuroraPalette(
    primary: Color(0xFFf59e0b), secondary: Color(0xFFef4444),
    backgroundStart: Color(0xFF3d1e1e), backgroundMid: Color(0xFF5c2a2a),
    backgroundEnd: Color(0xFF3d1020),
    accent1: Color(0xFFfb923c), accent2: Color(0xFFf87171),
  );

  AuroraPalette _midnightPalette() => const AuroraPalette(
    primary: Color(0xFF6366f1), secondary: Color(0xFF8b5cf6),
    backgroundStart: Color(0xFF0f0c29), backgroundMid: Color(0xFF1a1040),
    backgroundEnd: Color(0xFF0d0a1a),
    accent1: Color(0xFF818cf8), accent2: Color(0xFFa78bfa),
  );

  AuroraPalette _blendPalettes(AuroraPalette a, AuroraPalette b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return AuroraPalette(
      primary: Color.lerp(a.primary, b.primary, tt)!,
      secondary: Color.lerp(a.secondary, b.secondary, tt)!,
      backgroundStart: Color.lerp(a.backgroundStart, b.backgroundStart, tt)!,
      backgroundMid: Color.lerp(a.backgroundMid, b.backgroundMid, tt)!,
      backgroundEnd: Color.lerp(a.backgroundEnd, b.backgroundEnd, tt)!,
      accent1: Color.lerp(a.accent1, b.accent1, tt)!,
      accent2: Color.lerp(a.accent2, b.accent2, tt)!,
    );
  }

  AuroraPalette _applyWeather(AuroraPalette p) {
    switch (_weatherCode) {
      case 'rain':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF1a2332), 0.3)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF2a3348), 0.3)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF1a1e2e), 0.3)!,
          accent1: Color.lerp(p.accent1, const Color(0xFF6b7fa8), 0.4)!,
          accent2: Color.lerp(p.accent2, const Color(0xFF5b6e8e), 0.4)!,
        );
      case 'snow':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFFe8eef5), 0.4)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFFdce4f0), 0.4)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFFcfd8e8), 0.4)!,
          accent1: Color.lerp(p.accent1, const Color(0xFFb0c4de), 0.5)!,
          accent2: Color.lerp(p.accent2, const Color(0xFFc8d8e8), 0.5)!,
        );
      case 'cloudy':
        return AuroraPalette(
          primary: p.primary, secondary: p.secondary,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF252536), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF35354a), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF2a2a3c), 0.2)!,
          accent1: p.accent1, accent2: p.accent2,
        );
      default: return p;
    }
  }

  AuroraPalette _applyMood(AuroraPalette p) {
    switch (_mood) {
      case Mood.focused:
        return AuroraPalette(
          primary: const Color(0xFF60a5fa), secondary: const Color(0xFF3b82f6),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF0f2027), 0.25)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF1a3545), 0.25)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF0f2535), 0.25)!,
          accent1: const Color(0xFF38bdf8), accent2: const Color(0xFF818cf8),
        );
      case Mood.energetic:
        return AuroraPalette(
          primary: const Color(0xFFf59e0b), secondary: const Color(0xFFef4444),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF3d1e10), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF553010), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF3d1510), 0.2)!,
          accent1: const Color(0xFFfb923c), accent2: const Color(0xFFf87171),
        );
      case Mood.tired:
        return AuroraPalette(
          primary: Color.lerp(p.primary, const Color(0xFF6b7280), 0.35)!,
          secondary: Color.lerp(p.secondary, const Color(0xFF4b5563), 0.35)!,
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF1a1a1a), 0.3)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF2a2a2a), 0.3)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF1a1a1a), 0.3)!,
          accent1: const Color(0xFF9ca3af), accent2: const Color(0xFF6b7280),
        );
      case Mood.creative:
        return AuroraPalette(
          primary: const Color(0xFFc084fc), secondary: const Color(0xFFf472b6),
          backgroundStart: Color.lerp(p.backgroundStart, const Color(0xFF2d1040), 0.2)!,
          backgroundMid: Color.lerp(p.backgroundMid, const Color(0xFF3d1855), 0.2)!,
          backgroundEnd: Color.lerp(p.backgroundEnd, const Color(0xFF301040), 0.2)!,
          accent1: const Color(0xFFe879f9), accent2: const Color(0xFFf9a8d4),
        );
      default: return p; // Mood.calm
    }
  }
}
