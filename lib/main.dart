import 'package:flutter/material.dart';

import 'tracking_tab.dart';

void main() {
  runApp(const TabBarApp());
}

class TabBarApp extends StatelessWidget {
  const TabBarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        // appBarTheme: AppBarTheme(
        //   color: const Color(0xFF303F9F),
        // ),
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,

        // primaryColor: Colors.green,
      ),
      // theme: ThemeData.dark(),

      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.bedtime_outlined)),
                Tab(icon: Icon(Icons.person)),
                // Tab(icon: Icon(Icons.directions_bike)),
              ],
            ),
            title: const Text('Sleepy'),
          ),
          body: const TabBarView(
            children: [
              // Icon(Icons.directions_car),
              TrackingTab(),
              // const MyHomePage(title: 'Flutter Demo Home Page'),
              Icon(Icons.directions_transit),
              // Icon(Icons.directions_bike),
            ],
          ),
        ),
      ),
    );
  }
}
