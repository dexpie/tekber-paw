import 'package:flutter/material.dart';

void main() {
  runApp(const PawMapApp());
}

class PawMapApp extends StatelessWidget {
  const PawMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PawMap',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('PawMap'))),
    );
  }
}
