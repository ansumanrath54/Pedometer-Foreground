import 'dart:isolate';
import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pedometer_foreground/notificationservice.dart';

NotificationService _notificationService = NotificationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  _notificationService.initNotification();
  runApp(MyApp());
}

void startCallBack() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

void fireAlarm()  {
  _notificationService.showNotification(1, "title", "body");
  print('hello');
}

class ForegroundTaskHandler implements TaskHandler {

  int count =0;
  Stream<StepCount>? stepCount;
  String steps = '?' , yesterdaySteps = '0';


  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await FlutterForegroundTask.clearAllData();
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    count++;
    if(count<=1) {
      stepCount!.listen((event) {
        steps = event.steps.toString();
        FlutterForegroundTask.updateService(
          notificationTitle: "Pedometer",
          notificationText: "Total Steps: $steps     Yesterday Steps: $yesterdaySteps"
              "\nTime: ${DateFormat("dd-MM-yyyy – kk:mm:ss").format(timestamp)}",
          callback: null,
        );
      }, onError: (error) {
        steps = "Step Count not Available";
      },);
    }

    if((timestamp.hour == 00) && (timestamp.minute == 00) && (timestamp.second == 00)) {
      int tSteps = int.parse(steps) - int.parse(yesterdaySteps);
      yesterdaySteps = tSteps.toString();
      print("Total Steps in a Day: $yesterdaySteps");
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    stepCount = Pedometer.stepCountStream;
  }
}

class MyApp extends StatefulWidget {

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'Foreground Notification',
        channelDescription: 'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        interval: 1000,
        autoRunOnBoot: true,
      ),
      printDevLog: true,
    );
  }

  void _startForegroundTask() async {
    if(await FlutterForegroundTask.isRunningService) {
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Foreground Service is running',
      notificationText: 'Tap to return to the app',
      callback: startCallBack
    );
  }

  void _stopForegroundTask() {
    FlutterForegroundTask.stopService();
    AndroidAlarmManager.cancel(alarmId);
  }

  void initState() {
    super.initState();
    _initForegroundTask();
  }

  void dispose() {
    super.dispose();
  }

  bool isOn = false;
  int alarmId = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WithForegroundTask(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Foreground Task'),
            centerTitle: true,
          ),
          body: _buildContentView(),
        ),
      ),
    );
  }

  Widget _buildContentView() {
    final buttonBuilder = (String text, {VoidCallback? onPressed}) {
      return ElevatedButton(
        child: Text(text),
        onPressed: onPressed,
      );
    };


    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buttonBuilder('START', onPressed: _startForegroundTask),
          buttonBuilder('STOP', onPressed: _stopForegroundTask),
          buttonBuilder('NOTIFY', onPressed: () {
            AndroidAlarmManager.periodic(
              Duration(seconds: 60), alarmId, fireAlarm,
              startAt: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0),
            );
            print("Triggered");
            //fireAlarm();
          },),
        ],
      ),
    );
  }
}




