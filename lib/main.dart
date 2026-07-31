import 'package:flutter/material.dart';

void main() {
  runApp(const ActivityTrackerApp());
}

class ActivityTrackerApp extends StatelessWidget {
  const ActivityTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Activity Tracker'),
        ),
      ),
    );
  }
}
