import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import 'package:pedometer/pedometer.dart';
// import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime d) {
  return d.toString().substring(0, 19);
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('logs');
  runApp(MyApp(isDarkTheme: false));
}

// ignore: must_be_immutable
class MyApp extends StatelessWidget {
  bool isDarkTheme = false;
  MyApp({required this.isDarkTheme});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.light,
        primaryColor: Colors.lightBlue[800],
        hintColor: Colors.cyan[600],
      ),
      darkTheme: ThemeData(
        // Define the default brightness and colors for the dark theme.
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey[900],
        hintColor: Colors.cyan[600],
      ),
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Position? _currentPosition;
  String speed = '0.0 min/mile';
  String cadence = '0 spm';
  double totalDistanceCovered = 0.0;
  String distance = '0.0 miles';
  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;
  String _status = '?', _steps = '?';
  // late Stream<StepCount> _stepCountStream;
  int stepCount = 0;
  bool isTracking = false;
  List<String> logs = [];
  @override
  void initState() {
    super.initState();
    getLocation();
    initPlatformState();
    final box = Hive.box<String>('logs');
    logs = box.values.toList();
  }

  @override
  void dispose() {
    Hive.box('logs').close();
    super.dispose();
  }
  // late Stream<StepCount> _stepCountStream;
  // late Stream<PedestrianStatus> _pedestrianStatusStream;

  /// Handle step count changed
  // void onStepCount(StepCount event) {
  //   int steps = event.steps;
  //   DateTime timeStamp = event.timeStamp;
  // }

  /// Handle status changed
  ///
  ///
  int? initialStepCount;

  void onStepCount(StepCount event) {
    print('$event event steps');
    if (initialStepCount == null) {
      initialStepCount = event.steps;
    }
    setState(() {
      if (isTracking) {
        _steps = (event.steps - initialStepCount!).toString();
        cadence = '$_steps spm';
      }
    });
  }

  void onPedestrianStatusChanged(PedestrianStatus event) {
    print('$event evemt status');
    setState(() {
      _status = event.status;
    });
  }

  void onPedestrianStatusError(error) {
    print('onPedestrianStatusError: $error');
    setState(() {
      _status = 'error';
    });
    print(_status);
  }

  bool _isDarkTheme = false;
  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
    runApp(MyApp(isDarkTheme: _isDarkTheme));
  }

  void onStepCountError(error) {
    print('onStepCountError: $error');
    setState(() {
      _steps = 'Step Count not available';
    });
  }

  void initPlatformState() async {
    await Permission.activityRecognition.request() ;
    if (await Permission.activityRecognition.request().isGranted) {
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
      _pedestrianStatusStream
          .listen(onPedestrianStatusChanged)
          .onError(onPedestrianStatusError);

      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(onStepCount).onError(onStepCountError);
    } else {
      print('Permission denied');
    }
    if (!mounted) return;
  }
  // void _initPedometer() {
  //   _stepCountStream = Pedometer.stepCountStream;
  //   _stepCountStream.listen(
  //     (StepCount event) {
  //       setState(() {
  //          print('Step count: $stepCount');
  //          print('Cadence: $cadence');
  //         stepCount = event.steps;
  //         cadence = '$stepCount spm';
  //       });
  //     },
  //     onError: (error) {
  //       debugPrint('Pedometer error: $error');
  //     },
  //   );
  // }

  void getLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low);
  }

  void _getLocation() {
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    ).then((Position position) {
      setState(() {
        _currentPosition = position;
      });
    }).catchError((error) {
      debugPrint('Geolocator error: $error');
    });
  }

  void _startTracking() async {
    if (isTracking) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracking ended')),
      );
      String currentTime = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
      logs.add('Time: $currentTime, Speed: $speed, Cadence: $cadence, Distance: $distance');
      final box = Hive.box<String>('logs');
      await box.add('Time: $currentTime, Speed: $speed, Cadence: $cadence, Distance: $distance');
      setState(() {
        isTracking = false;
        // Reset tracking data
        speed = '0.0 min/mile';
        cadence = '0 spm';
        distance = '0.0 miles';
        stepCount = 0;
      });

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracking started')),
      );
      LocationSettings locationSettings = LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: const Duration(minutes: 30),
          distanceFilter: 1);

      Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        if (_currentPosition != null) {
          double distanceCovered = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          totalDistanceCovered += distanceCovered;
          double totalDistanceCoveredInMeters = totalDistanceCovered;
          double totalDistanceCoveredInMiles = totalDistanceCovered / 1609.34;
          double speedInMetersPerSecond = position.speed;
          double speedInMinPerMile = 26.8224 / speedInMetersPerSecond;

          setState(() {
            if(isTracking){
            speed = '${speedInMinPerMile.toStringAsFixed(2)} min/mile';
            distance =
                '${totalDistanceCoveredInMiles.toStringAsFixed(2)} miles (${totalDistanceCoveredInMeters.toStringAsFixed(2)} m)';
            }
          });
        }

        _currentPosition = position;
      });

      setState(() {
        isTracking = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ExerciseMonitoring'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_isDarkTheme ? Icons.brightness_7 : Icons.brightness_3),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Align children at the start of the column
          children: [
            ListTile(
              leading: Icon(Icons.speed_rounded),
              title: Text('Speed'),
              subtitle: Text(speed),
            ),
            ListTile(
              leading: Icon(Icons.directions_walk_rounded),
              title: Text('Cadence'),
              subtitle: Text(cadence),
            ),
            ListTile(
              leading: Icon(Icons.directions_run_rounded),
              title: Text('Distance'),
              subtitle: Text(distance),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.history_rounded),
                    title: Text('Previous Session'),
                    subtitle: Text(logs[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startTracking,
        tooltip: 'Start',
        child: Icon(isTracking ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
