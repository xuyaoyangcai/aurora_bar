import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setAsFrameless();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setSize(const Size(360, 60));
  await windowManager.setSkipTaskbar(true);
  await windowManager.show();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(backgroundColor: Colors.transparent,
      body: Center(child: Text('test', style: TextStyle(color: Colors.white)))),
  ));
}
