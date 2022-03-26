import 'package:flutter/material.dart';

import 'package:charts_flutter/flutter.dart' as charts;

import 'record.dart';
import 'utils.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer';

class RecordDetailPage extends StatefulWidget {
  final Record record;

  // RecordDetailPage({Key? key, required this.record}) : super(key: key);
  RecordDetailPage(this.record);

  @override
  State<RecordDetailPage> createState() => _StatsRecordDetailPage();
}

class _StatsRecordDetailPage extends State<RecordDetailPage> {
// class RecordDetailPage extends StatelessWidget {
  // final Record record;

  // _StatsRecordDetailPage() {}

  List<charts.Series<TimeSeriesData, DateTime>> hrSeries = [];
  List<TimeSeriesData> hrList = [];

  List<charts.Series<TimeSeriesData, DateTime>> motionSeries = [];
  List<TimeSeriesData> motionList = [];

  final String _logDir = '/storage/emulated/0/Documents/sleepy/log/';

  double _minHr = 500;
  double _maxHR = -1;

  double _minMotion = 500;
  double _maxMotion = -1;

  @override
  void initState() {
    loadHRData();
    loadMotionData();
  }

  Future<void> loadMotionData() async {
    File motionFile = File(_logDir + widget.record.filePrefix + "_motion.csv");
    _minMotion = 500;
    _maxMotion = -1;

    await motionFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      log(line);
      if (!line.startsWith("timestamp") && line.isNotEmpty) {
        setState(() {
          var motion = TimeSeriesData.parseFromCsv(line);
          if (motion != null) {
            motionList.add(motion);
            if (motion.value < _minMotion) {
              _minMotion = motion.value;
            }

            if (motion.value > _maxMotion) {
              _maxMotion = motion.value;
            }
          }
        });
      }
    });

    setState(() {
      _fillMotionSeries();
    });
  }

  void loadHRData() async {
    File hrFile = File(_logDir + widget.record.filePrefix + "_hr.csv");

    await hrFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      log(line);
      if (!line.startsWith("timestamp") && line.isNotEmpty) {
        setState(() {
          var hr = TimeSeriesData.parseFromCsv(line);
          if (hr != null) {
            hrList.add(hr);
            if (hr.value < _minHr) {
              _minHr = hr.value;
            } else if (hr.value > _maxHR) {
              _maxHR = hr.value;
            }
          }
        });
      }
    });

    setState(() {
      _fillHRSeries();
    });
  }

  void _fillMotionSeries() {
    motionSeries = [
      charts.Series<TimeSeriesData, DateTime>(
          id: 'Motion',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesData data, _) => data.timestamp,
          measureFn: (TimeSeriesData data, _) => data.value,
          data: motionList,
          displayName: 'Motion')
    ];
  }

  void _fillHRSeries() {
    hrSeries = [
      charts.Series<TimeSeriesData, DateTime>(
          id: 'HeartRate',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesData data, _) => data.timestamp,
          measureFn: (TimeSeriesData data, _) => data.value,
          data: hrList,
          displayName: 'HeartRate')
    ];
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle textStyle = TextStyle(fontSize: 15);

    return Scaffold(
        appBar: AppBar(
          title: const Text("Record Details"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            children: [
              // Text(record.filePrefix),
              const SizedBox(
                height: 20,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Row(
                  children: [
                    const Text("Start: ", style: textStyle),
                    Text(formatTime(widget.record.start), style: textStyle),
                  ],
                ),
                Row(
                  children: [
                    const Text("End: ", style: textStyle),
                    Text(formatTime(widget.record.end), style: textStyle),
                  ],
                ),
                Row(
                  children: [
                    const Text("Duration: ", style: textStyle),
                    Text(formatDuration(widget.record.duration),
                        style: textStyle),
                  ],
                )
              ]),
              const SizedBox(
                height: 20,
              ),
              const Text(
                "Heart Rate",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                height: 200,
                child: charts.TimeSeriesChart(hrSeries,
                    animate: true,
                    domainAxis: const charts.DateTimeAxisSpec(
                        renderSpec: charts.SmallTickRendererSpec(
                            labelStyle: charts.TextStyleSpec(
                          fontSize: 15,
                          color: charts.MaterialPalette.white,
                        )),
                        // tickProviderSpec:
                        //     charts.DayTickProviderSpec(increments: [1]),
                        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                            minute: charts.TimeFormatterSpec(
                                format: 'HH:mm', transitionFormat: 'HH:mm'))),
                    primaryMeasureAxis: charts.NumericAxisSpec(
                      tickProviderSpec:
                          const charts.BasicNumericTickProviderSpec(
                              desiredTickCount: 15),
                      renderSpec: charts.GridlineRendererSpec(

                          // Tick and Label styling here.
                          labelStyle: const charts.TextStyleSpec(
                              fontSize: 15, // size in Pts.
                              color: charts.MaterialPalette.white),

                          // Change the line colors to match text color.
                          lineStyle: charts.LineStyleSpec(
                              color: charts.Color.fromHex(code: "#808080"))),
                      viewport: charts.NumericExtents(_minHr - 5, _maxHR + 5),
                      // tickProviderSpec:
                      //     charts.BasicNumericTickProviderSpec(zeroBound: false),
                    ),

                    // Optionally pass in a [DateTimeFactory] used by the chart. The factory
                    // should create the same type of [DateTime] as the data provided. If none
                    // specified, the default creates local date time.
                    dateTimeFactory: const charts.LocalDateTimeFactory()),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                "Motion",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                height: 200,
                child: charts.TimeSeriesChart(motionSeries,
                    animate: true,
                    domainAxis: const charts.DateTimeAxisSpec(
                        renderSpec: charts.SmallTickRendererSpec(
                            labelStyle: charts.TextStyleSpec(
                          fontSize: 15,
                          color: charts.MaterialPalette.white,
                        )),
                        // tickProviderSpec:
                        //     charts.DayTickProviderSpec(increments: [1]),
                        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                            minute: charts.TimeFormatterSpec(
                                format: 'HH:mm', transitionFormat: 'HH:mm'))),
                    primaryMeasureAxis: charts.NumericAxisSpec(
                      tickProviderSpec:
                          const charts.BasicNumericTickProviderSpec(
                              desiredTickCount: 15),
                      renderSpec: charts.GridlineRendererSpec(

                          // Tick and Label styling here.
                          labelStyle: const charts.TextStyleSpec(
                              fontSize: 15, // size in Pts.
                              color: charts.MaterialPalette.white),

                          // Change the line colors to match text color.
                          lineStyle: charts.LineStyleSpec(
                              color: charts.Color.fromHex(code: "#808080"))),
                      viewport: charts.NumericExtents(_minMotion, _maxMotion),
                      // tickProviderSpec:
                      //     charts.BasicNumericTickProviderSpec(zeroBound: false),
                    ),

                    // Optionally pass in a [DateTimeFactory] used by the chart. The factory
                    // should create the same type of [DateTime] as the data provided. If none
                    // specified, the default creates local date time.
                    dateTimeFactory: const charts.LocalDateTimeFactory()),
              ),
            ],
          ),
        ));
  }
}

class TimeSeriesData {
  final DateTime timestamp;
  final double value;

  TimeSeriesData({required this.timestamp, required this.value});

  static TimeSeriesData? parseFromCsv(String csv) {
    var items = csv.split(";");
    if (items.length < 3) {
      return null;
    }
    String startDate =
        items[0].split(" ")[0]; // get date of date and time string
    String startTime =
        items[0].split(" ")[1]; // get time of date and time string

    try {
      // var timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(items[0]);
      int milliseconds = int.parse(items[1]);
      var timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      var value = double.parse(items[2]);
      return TimeSeriesData(timestamp: timestamp, value: value);
    } catch (FormatException) {
      return null;
    }
  }
}
