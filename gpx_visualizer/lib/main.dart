import 'package:flutter/material.dart';
import 'package:gpx_visualizer/screens/map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Uygulamanın kök widget'ını oluşturur.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPX Görselleştirici',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
