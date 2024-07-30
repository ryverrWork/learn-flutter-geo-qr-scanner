import 'package:flutter/material.dart';
import 'qr_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const QRScannerPage(), // Remove 'const' here
    );
  }
}
