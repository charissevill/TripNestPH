import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_exception.dart';

/// Attached to the root `MaterialApp` so [launchSafely] can show a message
/// from code that has no `BuildContext` (e.g. the static `MapsLauncher`).
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// `launchUrl` throws a `PlatformException` (or quietly returns false) when
/// nothing on the device can handle the link — no browser, no phone app, no
/// Maps. Left unhandled that is a dead tap plus an uncaught async error, so
/// this reports it as a plain-language snackbar instead. Returns whether the
/// link was actually opened.
Future<bool> launchSafely(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
  String failureMessage = 'Couldn\'t open that link. Please try again.',
}) async {
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: mode);
  } catch (e) {
    logTechnicalError(e);
  }
  if (!launched) {
    appMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failureMessage)));
  }
  return launched;
}

/// Opens the phone dialer for [number], with a friendly fallback message
/// (including the number, so the traveler can dial it by hand) if the device
/// can't place calls.
Future<bool> callNumber(String number) => launchSafely(
  Uri(scheme: 'tel', path: number),
  failureMessage: 'Couldn\'t open the phone app. You can dial $number manually.',
);
