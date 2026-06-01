import 'package:flutter/material.dart';

import '../errors/error_message.dart';

/// Short floating toast built on [SnackBar] (no extra packages).
enum AppToastVariant {
  success,
  error,
}

/// Shows a compact rounded toast above the bottom of the screen.
///
/// [AppToastVariant.success] uses a solid green; [AppToastVariant.error] uses
/// [ColorScheme.error] / [ColorScheme.onError].
void showAppToast(
  BuildContext context,
  String message, {
  AppToastVariant variant = AppToastVariant.success,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final cs = Theme.of(context).colorScheme;

  messenger.hideCurrentSnackBar();

  final Color backgroundColor;
  final Color foregroundColor;
  switch (variant) {
    case AppToastVariant.success:
      backgroundColor = const Color(0xFF2E7D32);
      foregroundColor = Colors.white;
      break;
    case AppToastVariant.error:
      backgroundColor = cs.error;
      foregroundColor = cs.onError;
      break;
  }

  final bottomPad = MediaQuery.paddingOf(context).bottom + 72;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(24, 0, 24, bottomPad),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      elevation: 6,
    ),
  );
}

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final msg = friendlyErrorMessage(error, fallback: fallback);
  showAppToast(context, msg, variant: AppToastVariant.error);
}
