import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'image_detect_page.dart';

late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImageProcessPage(cameras: _cameras),
    );
  }
}
