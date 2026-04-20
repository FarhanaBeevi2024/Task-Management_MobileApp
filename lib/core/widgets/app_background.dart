import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF4D7FF), // soft lavender
      Color(0xFFFFE6D6), // warm peach
      Color(0xFFE2F0FF), // light sky
    ],
    stops: [0.05, 0.55, 1.0],
  );

  static const _darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF140A2B), // deep purple
      Color(0xFF0B1B2F), // deep blue
      Color(0xFF2A0E22), // deep magenta
    ],
    stops: [0.0, 0.55, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: brightness == Brightness.dark ? _darkGradient : _lightGradient,
      ),
      child: child,
    );
  }
}

