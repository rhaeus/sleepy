import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatDuration(Duration duration) {
  return "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60).toString().padLeft(2, '0'))}";
}

Duration parseDuration(String duration) {
  // HH:MM:SS
  var parts = duration.split(":");
  // TODO sanity check
  int hour = int.parse(parts[0]);
  int minutes = int.parse(parts[1]);
  int seconds = int.parse(parts[2]);
  return Duration(hours: hour, minutes: minutes, seconds: seconds);
}

String formatDate(DateTime dt) {
  final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  return dateFormat.format(dt);
}

String formatTime(DateTime dt) {
  final DateFormat dateFormat = DateFormat('HH:mm:ss');
  return dateFormat.format(dt);
}

void showMessage(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
  ));
}
