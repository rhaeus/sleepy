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
  final String _logDir = '/storage/emulated/0/Documents/sleepy/log/';

  @override
  void initState() {
    loadHRData();
  }

  void loadHRData() async {
    File hrFile = File(_logDir + widget.record.filePrefix + "_hr.csv");
    var ex = await hrFile.exists();

    if (ex) {
      log("exist");
      // log(len.toString());
    } else {
      log("not exist");
    }
    await hrFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      log(line);
      if (!line.startsWith("timestamp")) {
        setState(() {
          hrList.add(TimeSeriesData.parseFromCsv(line));
        });
      }
    });

    setState(() {
      _fillHRSeries();
    });
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
                        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                            day: charts.TimeFormatterSpec(
                                format: 'MM/d', transitionFormat: 'MM/dd'))),
                    primaryMeasureAxis: const charts.NumericAxisSpec(
                        renderSpec: charts.GridlineRendererSpec(

                            // Tick and Label styling here.
                            labelStyle: charts.TextStyleSpec(
                                fontSize: 15, // size in Pts.
                                color: charts.MaterialPalette.white),

                            // Change the line colors to match text color.
                            lineStyle: charts.LineStyleSpec(
                                color: charts.MaterialPalette.white))),

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
  final int value;

  TimeSeriesData({required this.timestamp, required this.value});

  static TimeSeriesData parseFromCsv(String csv) {
    var items = csv.split(";");
    String startDate =
        items[0].split(" ")[0]; // get date of date and time string
    String startTime =
        items[0].split(" ")[1]; // get time of date and time string

    var timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(items[0]);

    var value = int.parse(items[2]);
    return TimeSeriesData(timestamp: timestamp, value: value);
  }
}
