import 'package:flutter/material.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:spotify_sdk/models/player_state.dart';

import 'package:spotify_sdk/spotify_sdk.dart';
import 'dart:developer';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:duration_picker/duration_picker.dart';

import 'dart:async';
import 'dart:collection';
import 'package:volume/volume.dart';
import 'dart:math' as math;

import 'spotify_config.dart' as spotify_config;

import 'utils.dart';

class TrackingTab extends StatefulWidget {
  const TrackingTab({Key? key}) : super(key: key);

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab>
    with AutomaticKeepAliveClientMixin<TrackingTab> {
  int _motionThreshold = 4;
  int _hrOffsetThreshold = 10;

  bool _spotifyConnected = false;

  String _cosinussStatus = "Tap bluetooth icon to connect to Cosinuss";
  bool _cosinussConnected = false;

  bool _cosinussFound = false;

  bool _trackingStarted = false;
  String _trackingButtonText = "Start";

  final String _logDir = '/storage/emulated/0/Documents/sleepy/log/';
  late File _logFileHR;
  late File _logFileAcc;
  late File _logFileDur;
  late File _logFileMotion;

  String _spotifyTrack = "Tap music icon to connect to Spotify";
  Icon _spotifyPlayPauseIcon = const Icon(Icons.play_arrow);
  bool _spotifyIsPaused = true;

  Duration _sleepTimerDuration = const Duration(minutes: 30);
  String _sleepTimerDurationDisplay = "00:30:00";
  bool _useSleepTimer = true;

  int _restingHeartRate = 70;

  final Stopwatch _trackingStopwatch = Stopwatch();
  String _trackingDuration = "00:00:00";
  late Timer _trackingDurationUpdateTimer;

  int _heartRate = 0;
  int _motion = 0;

  // Queue<int> _heartRateQueue = Queue();
  Queue<List<int>> _motionQueue = Queue();

  int _startingVolume = 0;
  int _currentVolume = 0;

  Timer? _sleepTimer;

  late DateTime _startTime;

  @override
  bool get wantKeepAlive => true;

  _TrackingTabState() {
    _connectCosinuss();
    _connectSpotify();
  }

  Future<void> _writeFile(File file, String text) async {
    await file.writeAsString(text, mode: FileMode.append, flush: true);
  }

  void _toggleTracking() async {
    if (_trackingStarted) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    if (_trackingStarted) {
      log("TrackingTab already started");
      return;
    }

    Volume.controlVolume(AudioManager.STREAM_MUSIC);
    _startingVolume = await Volume.getVol;
    _currentVolume = _startingVolume;

    var format = DateFormat('yyyy-MM-dd-HH-mm-ss');
    String timestamp = format.format(DateTime.now());

    // String filename = _logDir + timestamp + "_hr.csv";
    // log("filename:" + filename);

    _logFileHR = File(_logDir + timestamp + "_hr.csv");
    _logFileAcc = File(_logDir + timestamp + "_acc.csv");
    _logFileMotion = File(_logDir + timestamp + "_motion.csv");
    _logFileDur = File(_logDir + "durations.csv");

    await _writeFile(_logFileHR, "timestamp;timestamp raw;heart rate(bpm);\n");
    await _writeFile(_logFileMotion, "timestamp;timestamp raw;motion score;\n");
    await _writeFile(
        _logFileAcc, "timestamp;timestamp raw;acc x;acc y;acc z;\n");

    var durExists = await _logFileDur.exists();
    if (!durExists) {
      await _writeFile(_logFileDur, "start;stop;duration;\n");
    }

    _trackingStopwatch.reset();
    _trackingStopwatch.start();
    _trackingDurationUpdateTimer = Timer.periodic(
        const Duration(seconds: 1),
        (Timer t) => setState(() {
              _trackingDuration = formatDuration(_trackingStopwatch.elapsed);
            }));

    _startSleepTimer();

    _startTime = DateTime.now();

    setState(() {
      _trackingStarted = true;
      _trackingButtonText = "Stop";
    });
    log("TrackingTab started");
  }

  void _startSleepTimer() {
    _sleepTimer?.cancel();
    if (_useSleepTimer) {
      _sleepTimer = Timer(_sleepTimerDuration, () {
        log("sleep timer triggered");
        _sleepDetected();
      });
    }
  }

  void _stopTracking() async {
    await _pauseSpotify();
    // Volume.setVol(_startingVolume);
    if (!_trackingStarted) {
      log("TrackingTab already stopped");
      return;
    }
    _pauseSpotify();
    // Volume.setVol(_startingVolume);

    _trackingStopwatch.stop();

    _trackingDurationUpdateTimer.cancel();
    setState(() {
      _trackingStarted = false;
      _trackingButtonText = "Start";
    });

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    var now = DateTime.now();
    String timestamp = dateFormat.format(now);

    String csv = dateFormat.format(_startTime) +
        ";" +
        dateFormat.format(DateTime.now()) +
        ";" +
        _trackingDuration +
        ";\n";
    await _writeFile(_logFileDur, csv);

    log("TrackingTab stopped");
  }

  void _cosinusConnectionStateChanged() {
    log("cosinuss connection state changed");
    setState(() {
      _cosinussStatus = (_cosinussConnected)
          ? "Connected to Cosinuss One"
          : "Tap bluetooth icon to connect to Cosinuss";
    });
  }

  Future<void> updateHeartRate(rawData) async {
    Uint8List bytes = Uint8List.fromList(rawData);

    // based on GATT standard
    var bpm = bytes[1];
    if (!((bytes[0] & 0x01) == 0)) {
      bpm = (((bpm >> 8) & 0xFF) | ((bpm << 8) & 0xFF00));
    }

    if (_trackingStarted) {
      final DateFormat format = DateFormat('yyyy-MM-dd HH:mm:ss');
      var now = DateTime.now();
      String timestamp = format.format(now);

      String csv = timestamp +
          ";" +
          now.millisecondsSinceEpoch.toString() +
          ";" +
          bpm.toString() +
          ";\n";

      _writeFile(_logFileHR, csv);

      // var bpmLabel = "- bpm";
      // if (bpm != 0) {
      //   bpmLabel = bpm.toString() + " bpm";
      // }
      if (_hrBaselineMeasure) {
        _hrForBaseline.add(bpm);
      }

      setState(() {
        _heartRate = bpm;
      });

      if (bpm < _restingHeartRate - _hrOffsetThreshold) {
        _possiblyAsleep();
      }
    }
  }

  Queue<List<int>> _accDiffQueue = Queue();
  List<int> _currentMotion = [];
  final int _accWindowSize = 10;

  Future<void> updateAccelerometer(rawData) async {
    Int8List bytes = Int8List.fromList(rawData);

    // description based on placing the earable into your right ear canal
    int accX = bytes[14];
    int accY = bytes[16];
    int accZ = bytes[18];

    if (_trackingStarted) {
      final DateFormat format = DateFormat('yyyy-MM-dd HH:mm:ss');
      var now = DateTime.now();
      String timestamp = format.format(now);

      String csv = timestamp +
          ";" +
          now.millisecondsSinceEpoch.toString() +
          ";" +
          accX.toString() +
          ";" +
          accY.toString() +
          ";" +
          accZ.toString() +
          ";\n";

      _writeFile(_logFileAcc, csv);

      // motion eval, root mean square of differential of acc signal
      // differentiate signal
      // square
      // average
      // root
      if (_accDiffQueue.isNotEmpty) {
        var oldest = _accDiffQueue.first;
        List<int> newestDiff = [];
        newestDiff.add(accX - _accDiffQueue.last[0]);
        newestDiff.add(accY - _accDiffQueue.last[1]);
        newestDiff.add(accZ - _accDiffQueue.last[2]);

        for (int i = 0; i < 3; ++i) {
          _currentMotion[i] = (_currentMotion[i] +
                  newestDiff[i] * newestDiff[i] / _accWindowSize -
                  oldest[i] * oldest[i] / _accWindowSize)
              .round();
        }

        // remove oldes sample from queue
        _accDiffQueue.removeFirst();

        // add newest sample to queue
        _accDiffQueue.add(newestDiff);

        // motion value is average of rms
        _motion = ((math.sqrt(_currentMotion[0]) +
                    math.sqrt(_currentMotion[1]) +
                    math.sqrt(_currentMotion[2])) /
                3)
            .round();

        if (_motion > _motionThreshold) {
          _motionDetected();
        }

        csv = timestamp +
            ";" +
            now.millisecondsSinceEpoch.toString() +
            ";" +
            _motion.toString() +
            ";\n";

        _writeFile(_logFileMotion, csv);
      }

      // setState(() {
      //   _accX = accX.toString() + " (unknown unit)";
      //   _accY = accY.toString() + " (unknown unit)";
      //   _accZ = accZ.toString() + " (unknown unit)";
      // });
    }
  }

  void _setSpotifyPlayPauseIcon(bool isPaused) {
    setState(() {
      if (isPaused) {
        _spotifyPlayPauseIcon = const Icon(Icons.play_arrow);
      } else {
        _spotifyPlayPauseIcon = const Icon(Icons.pause);
      }
    });
  }

  void _displaySpotifyTrack(PlayerState state) {
    setState(() {
      var trackname = state.track?.name;
      var artistname = state.track?.artist.name;
      if (trackname != null && artistname != null) {
        _spotifyTrack = trackname + " - " + artistname;
      }
    });
  }

  void _connectCosinuss() {
    // setState(() {
    //   _cosinussStatus = "Searching for Cosinuss One";
    // });

    FlutterBlue flutterBlue = FlutterBlue.instance;

    // start scanning
    flutterBlue.startScan(timeout: const Duration(seconds: 4));

    // listen to scan results
    flutterBlue.scanResults.listen((results) async {
      // do something with scan results
      for (ScanResult r in results) {
        if (r.device.name == "earconnect" && !_cosinussFound) {
          // avoid multiple connects attempts to same device
          _cosinussFound = true;
          log("Cosinuss found.");

          await flutterBlue.stopScan();

          r.device.state.listen((state) {
            // listen for connection state changes
            setState(() {
              _cosinussConnected = state == BluetoothDeviceState.connected;
              _cosinusConnectionStateChanged();
            });
          });

          await r.device.connect();

          var services = await r.device.discoverServices();

          for (var service in services) {
            // iterate over services
            for (var characteristic in service.characteristics) {
              // iterate over characterstics
              switch (characteristic.uuid.toString()) {
                case "0000a001-1212-efde-1523-785feabcd123":
                  // print("Starting sampling ...");
                  await characteristic.write([
                    0x32,
                    0x31,
                    0x39,
                    0x32,
                    0x37,
                    0x34,
                    0x31,
                    0x30,
                    0x35,
                    0x39,
                    0x35,
                    0x35,
                    0x30,
                    0x32,
                    0x34,
                    0x35
                  ]);
                  await Future.delayed(const Duration(
                      seconds:
                          2)); // short delay before next bluetooth operation otherwise BLE crashes
                  characteristic.value
                      .listen((rawData) => {updateAccelerometer(rawData)});
                  await characteristic.setNotifyValue(true);
                  await Future.delayed(const Duration(seconds: 2));
                  break;

                case "00002a37-0000-1000-8000-00805f9b34fb":
                  // _hrCharacteristic = characteristic;
                  characteristic.value
                      .listen((rawData) => {updateHeartRate(rawData)});
                  await characteristic.setNotifyValue(true);
                  await Future.delayed(const Duration(
                      seconds:
                          2)); // short delay before next bluetooth operation otherwise BLE crashes
                  break;

                // case "00002a1c-0000-1000-8000-00805f9b34fb":
                //   characteristic.value
                //       .listen((rawData) => {updateBodyTemperature(rawData)});
                //   await characteristic.setNotifyValue(true);
                //   await Future.delayed(new Duration(
                //       seconds:
                //           2)); // short delay before next bluetooth operation otherwise BLE crashes
                //   break;
              }
            }
          }
        }
      }
      // setState(() {
      //   _cosinussStatus = "Tap bluetooth icon to connect to Cosinuss One";
      // });
    });
  }

  Future<bool> _connectSpotify() async {
    log('connect to spotify');
    _spotifyConnected = await SpotifySdk.connectToSpotifyRemote(
        clientId: spotify_config.clientId,
        redirectUrl: spotify_config.redirectUrl);

    SpotifySdk.subscribePlayerState().listen((event) {
      _spotifyIsPaused = event.isPaused;
      _setSpotifyPlayPauseIcon(_spotifyIsPaused);
      _displaySpotifyTrack(event);
    });

    var state = await SpotifySdk.getPlayerState();

    setState(() {
      if (state != null) {
        _spotifyIsPaused = state.isPaused;
        _setSpotifyPlayPauseIcon(_spotifyIsPaused);
        _displaySpotifyTrack(state);
      }
    });
    return _spotifyConnected;
  }

  Future<void> _resumeSpotify() async {
    await SpotifySdk.resume();
    setState(() {
      _spotifyIsPaused = false;
      _spotifyPlayPauseIcon = const Icon(Icons.pause);
    });
  }

  Future<void> _pauseSpotify() async {
    await SpotifySdk.pause();
    setState(() {
      _spotifyIsPaused = true;
      _spotifyPlayPauseIcon = const Icon(Icons.play_arrow);
    });
  }

  void _toggleSpotify() {
    if (_spotifyIsPaused) {
      _resumeSpotify();
    } else {
      _pauseSpotify();
    }
  }

  void _pickSleepTimer() async {
    var duration = await showDurationPicker(
      context: context,
      initialTime: _sleepTimerDuration,
    );

    setState(() {
      if (duration != null) {
        _sleepTimerDuration = duration;
        _sleepTimerDurationDisplay = formatDuration(duration);
      }
    });
  }

  Timer? _possiblyAsleepTimer;
  void _possiblyAsleep() {
    _possiblyAsleepTimer?.cancel();
    _possiblyAsleepTimer = Timer(const Duration(minutes: 2), () {
      _sleepDetected();
    });
  }

  Timer? _motionTimer;
  void _checkForMotion(Duration duration) {
    _motionTimer = Timer(duration, () {
      // if timer triggers no motion was detected
      // we stop tracking
      log("no motion detected -> stop tracking");
      _stopTracking();
    });
  }

  Timer? _hrBaseLineTimer;
  bool _hrBaselineMeasure = false;
  List<int> _hrForBaseline = [];
  void _measureHRBaseline(Duration duration) {
    _hrForBaseline.clear();
    _hrBaselineMeasure = true;

    showMessage(
        context,
        "Please wait " +
            duration.inSeconds.toString() +
            " seconds for measurement to complete");

    _hrBaseLineTimer = Timer(duration, () {
      showMessage(context, "Measurement complete");
      log("HR baseline measurement done");
      _hrBaselineMeasure = false;
      setState(() {
        if (_hrForBaseline.isNotEmpty) {
          int sum =
              _hrForBaseline.fold(0, (previous, current) => previous + current);
          _restingHeartRate = (sum / _hrForBaseline.length).round();
        } else {
          _restingHeartRate = 0;
        }
        log("resting HR: " + _restingHeartRate.toString());
      });
    });
  }

  Timer? _volumeRampTimer;
  void _rampVolume(int endVol, int secondsBetween) {
    _volumeRampTimer?.cancel();
    _volumeRampTimer = Timer.periodic(
        Duration(seconds: secondsBetween),
        (Timer t) => setState(() {
              if (_currentVolume == endVol) {
                _volumeRampTimer!.cancel();
              } else if (endVol < _currentVolume) {
                // ramp down
                --_currentVolume;
                Volume.setVol(_currentVolume);
              } else {
                // ramp up
                ++_currentVolume;
                Volume.setVol(_currentVolume);
              }
            }));
  }

  void _sleepDetected() async {
    log("sleep detetcted");
    _currentVolume = await Volume.getVol;
    _startingVolume = _currentVolume;
    _rampVolume(2, 1);
    _checkForMotion(const Duration(minutes: 5));
  }

  void _motionDetected() {
    log("motion detected");
    _motionTimer?.cancel();
    _possiblyAsleepTimer?.cancel();
    _rampVolume(_startingVolume, 1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      // backgroundColor: Colors.grey[800],

      body: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            children: [
              Card(
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    color: Colors.grey,
                    disabledColor: Colors.teal,
                    onPressed: !_cosinussConnected ? _connectCosinuss : null,
                    icon: const Icon(Icons.bluetooth_audio),
                  ),
                  Text(_cosinussStatus, style: const TextStyle(fontSize: 15)),
                ],
              )),
              Card(
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    color: Colors.grey,
                    disabledColor: Colors.teal,
                    onPressed: !_spotifyConnected ? _connectSpotify : null,
                    icon: const Icon(Icons.music_note),
                  ),
                  IconButton(
                    iconSize: 40,
                    onPressed: _spotifyConnected ? _toggleSpotify : null,
                    icon: _spotifyPlayPauseIcon,
                  ),
                  Text(
                    _spotifyTrack,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              )),
              Card(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    IconButton(
                      iconSize: 40,
                      onPressed: _useSleepTimer ? _pickSleepTimer : null,
                      icon: const Icon(Icons.access_time),
                    ),
                    Text(
                      "Sleep Timer: " + _sleepTimerDurationDisplay,
                      style: TextStyle(
                          fontSize: 15,
                          color: _useSleepTimer ? Colors.white : Colors.grey),
                    ),
                    Expanded(
                        child: Align(
                      alignment: Alignment.centerRight,
                      child: Switch(
                          value: _useSleepTimer,
                          onChanged: (bool value) {
                            setState(() {
                              _useSleepTimer = value;
                            });
                          }),
                    )),
                  ])),
              Card(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    const IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      disabledColor: Colors.white,
                      onPressed: null,
                      icon: Icon(Icons.favorite),
                    ),
                    Text(
                      "Heart rate base line: " +
                          _restingHeartRate.toString() +
                          " bpm",
                      style: TextStyle(
                          fontSize: 15,
                          color: _useSleepTimer ? Colors.white : Colors.grey),
                    ),
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: ElevatedButton(
                                  onPressed: () {
                                    _measureHRBaseline(
                                        const Duration(seconds: 5));
                                  },
                                  child: const Text(
                                    "Measure",
                                    style: TextStyle(fontSize: 15),
                                  ),
                                )))),
                  ])),
              Expanded(
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      "Heart Rate",
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    Text(
                                      "$_heartRate",
                                      style: const TextStyle(fontSize: 100),
                                    ),
                                    const Text(
                                      "bpm",
                                      style: TextStyle(fontSize: 15),
                                    )
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      "Motion",
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    Text(
                                      "$_motion",
                                      style: const TextStyle(fontSize: 100),
                                    ),
                                    const Text(
                                      "%",
                                      style: TextStyle(fontSize: 15),
                                    )
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 30,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      "Duration",
                                      style: TextStyle(fontSize: 15),
                                    ),
                                    Text(
                                      _trackingDuration,
                                      style: const TextStyle(fontSize: 100),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            Row(
                              children: [
                                // Text("$_currentVolume"),
                                ElevatedButton(
                                    onPressed: () async {
                                      // _rampVolume(
                                      //     0,
                                      //     Math.max(
                                      //         (5 / _currentVolume).round(), 1));
                                      _sleepDetected();
                                    },
                                    child: const Text("sleep detect")),
                                ElevatedButton(
                                    onPressed: () {
                                      _motionDetected();
                                    },
                                    child: const Text("motion"))
                              ],
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                    width: double.infinity,
                                    height: 80,
                                    child: ElevatedButton(
                                        onPressed: _trackingStarted
                                            ? _stopTracking
                                            : _startTracking,
                                        child: Text(
                                          _trackingButtonText,
                                          style: const TextStyle(fontSize: 25),
                                        ))),
                              ),
                            )
                          ],
                        ))),
              ),
            ],
          )),
    );
  }
}
