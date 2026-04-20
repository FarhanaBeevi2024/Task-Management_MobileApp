import 'package:flutter/material.dart';

import '../errors/error_message.dart';

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(friendlyErrorMessage(error, fallback: fallback)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

