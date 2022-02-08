import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'details_page.dart';
import 'record.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'utils.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({Key? key}) : super(key: key);

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
// with AutomaticKeepAliveClientMixin<StatsTab>
{
  final String _logDir = '/storage/emulated/0/Documents/sleepy/log/';
  List<Record> recordList = [];
  List<charts.Series<Record, DateTime>> durationSeries = [];

  Duration _minDuration = Duration(hours: 1000);
  Duration _maxDuration = Duration();
  Duration _avgDuration = Duration();

  _StatsTabState() {
    // Future.delayed(Duration.zero, () async {
    //   //your async 'await' codes goes here
    //   await getRecords();
    // });
    // getRecords();
  }

  @override
  void initState() {
    getRecords();
  }

  Future<void> getRecords() async {
    File _logFileDur = File(_logDir + "durations.csv");
    await _logFileDur
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      if (!line.startsWith("start")) {
        // ignore csv header
        // log('line: $line');
        setState(() {
          var record = Record.parseFromCsv(line);
          recordList.add(record);

          if (record.duration < _minDuration) {
            _minDuration = record.duration;
          }
          if (record.duration > _maxDuration) {
            _maxDuration = record.duration;
          }

          _avgDuration += record.duration;
          // durationData.add()
        });
      }
    });
    setState(() {
      _fillDurationSeries();
      _avgDuration = Duration(
          seconds: (_avgDuration.inSeconds / recordList.length).round());
    });
  }

  void _fillDurationSeries() {
    durationSeries = [
      charts.Series<Record, DateTime>(
          id: 'Duration',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (Record record, _) => record.start,
          measureFn: (Record record, _) => record.duration.inMinutes,
          data: recordList,
          displayName: 'Duration')
    ];
  }

  // void getRecordsTest() {
  //   recordList.add(
  //       Record(date: "18.01.2022", duration: "00:14:00", filePrefix: "jhfk"));
  //   recordList.add(
  //       Record(date: "18.01.2022", duration: "00:14:00", filePrefix: "krhje"));
  // }

  // @override
  // bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // super.build(context);
    return Scaffold(
        body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(5),
            children: <Widget>[
          const Text(
            "Tracking Duration",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // ElevatedButton(onPressed: _fillDurationSeries, child: Text("fill")),
          Container(
            width: double.infinity,
            height: 200,
            child: charts.TimeSeriesChart(durationSeries,
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
                primaryMeasureAxis: charts.NumericAxisSpec(
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                      desiredTickCount: 10),
                  renderSpec: charts.GridlineRendererSpec(

                      // Tick and Label styling here.
                      labelStyle: const charts.TextStyleSpec(
                          fontSize: 15, // size in Pts.
                          color: charts.MaterialPalette.white),

                      // Change the line colors to match text color.
                      lineStyle: charts.LineStyleSpec(
                          color: charts.Color.fromHex(code: "#808080"))),
                  viewport: charts.NumericExtents(
                      _minDuration.inMinutes - 1, _maxDuration.inMinutes + 1),
                ),
                // lineStyle: charts.LineStyleSpec(
                //     color: charts.MaterialPalette.white))),

                // Optionally pass in a [DateTimeFactory] used by the chart. The factory
                // should create the same type of [DateTime] as the data provided. If none
                // specified, the default creates local date time.
                dateTimeFactory: const charts.LocalDateTimeFactory()),
          ),
          const SizedBox(
            height: 20,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Row(
              children: [
                const Text("Min: "),
                Text(formatDuration(_minDuration)),
              ],
            ),
            Row(
              children: [
                const Text("Max: "),
                Text(formatDuration(_maxDuration)),
              ],
            ),
            Row(
              children: [
                const Text("Avg: "),
                Text(formatDuration(_avgDuration)),
              ],
            )
          ]),
          const SizedBox(
            height: 20,
          ),
          ...List.generate(recordList.length, (index) {
            return Center(
              child: RecordCard(
                item: recordList[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            RecordDetailPage(recordList[index])),
                  );
                },
              ),
            );
          })
        ]));
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard(
      {Key? key,
      required this.onTap,
      required this.item,
      this.selected = false})
      : super(key: key);

  final VoidCallback onTap;
  final Record item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    TextStyle textStyle = const TextStyle(fontSize: 20);

    return InkWell(
      onTap: () {
        onTap();
      },
      child: Card(
          // color: Colors.white,
          child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(15.0),
              alignment: Alignment.centerLeft,
              child: Text(
                formatDateTime(item.start),
                style: textStyle,
              )),
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(15.0),
            alignment: Alignment.centerLeft,
            child: Text(
              formatDuration(item.duration),
              style: textStyle,
              textAlign: TextAlign.left,
            ),
          )),
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      )),
    );
  }
}

/// Sample time series data type.
class TimeSeriesSales {
  final DateTime time;
  final int sales;

  TimeSeriesSales(this.time, this.sales);
}
