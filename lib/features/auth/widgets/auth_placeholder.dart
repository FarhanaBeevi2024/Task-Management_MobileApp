import 'package:flutter/material.dart';

/// Small reusable block when user is not signed in.
class AuthPlaceholder extends StatelessWidget {
  const AuthPlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
