import 'package:flutter/material.dart';

class SanchalanApp extends StatelessWidget {
  const SanchalanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sanchalan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      home: const Scaffold(body: Center(child: Text('Sanchalan'))),
    );
  }
}
