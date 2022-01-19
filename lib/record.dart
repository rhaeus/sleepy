import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utils.dart';

class Record {
  const Record(
      {required this.start,
      required this.end,
      required this.duration,
      required this.filePrefix});

  final DateTime start;
  final DateTime end;
  final Duration duration;
  // final String dateString;

  // final String durationString;
  final String filePrefix;

  @override
  String toString() {
    return formatDate(start) + " " + formatDuration(duration);
  }

  static Record parseFromCsv(String csv) {
    var items = csv.split(";");
    String startDate =
        items[0].split(" ")[0]; // get date of date and time string
    String startTime =
        items[0].split(" ")[1]; // get time of date and time string

    String filePrefix = startDate + "-" + startTime.replaceAll(":", "-");

    var start = DateFormat('yyyy-MM-dd HH:mm:ss').parse(items[0]);
    var end = DateFormat('yyyy-MM-dd HH:mm:ss').parse(items[1]);
    var dur = parseDuration(items[2]);
    return Record(
        start: start, end: end, duration: dur, filePrefix: filePrefix);
  }
}
