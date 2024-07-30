import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey _qrKey = GlobalKey();
  QRViewController? _controller;
  bool _isScanning = true;
  String _coordinates = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.locationWhenInUse.request();

    if (cameraStatus.isDenied || locationStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please grant camera and location permissions.')),
        );
      }
    }
  }

  Future<void> _checkLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are not enabled.')),
        );
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (io.Platform.isIOS) {
      _controller?.pauseCamera();
    }
    _controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: Stack(
        children: <Widget>[
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),
          _buildAutofocusBox(),
          Positioned(
            bottom: 0,
            child: Container(
              color: Colors.black54,
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan a QR code',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coordinates: $_coordinates',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutofocusBox() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      if (_isScanning) {
        _isScanning = false;
        final qrCode = scanData.code;
        final registered = await _checkIfQRCodeRegistered(qrCode);

        if (!registered) {
          await _checkLocationServices();
          final hasLocationPermission =
              await Permission.locationWhenInUse.isGranted;

          if (hasLocationPermission) {
            // Check for airplane mode and provide a fallback message
            bool isAirplaneMode = await _isAirplaneModeEnabled();
            if (isAirplaneMode) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Airplane mode is enabled. Location may be limited.')),
              );
            }

            final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
            final coords = '${position.latitude}, ${position.longitude}';

            if (mounted) {
              setState(() {
                _coordinates = coords;
              });
              await _registerQRCode(qrCode, coords);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('QR code registered with location: $coords')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Location permission is required.')),
              );
            }
          }
        }
        _isScanning = true; // Reset scanning state
      }
    });
  }

  Future<bool> _checkIfQRCodeRegistered(String? qrCode) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = io.File('${directory.path}/qr_codes.json');
    if (!await file.exists()) {
      return false;
    }
    final contents = await file.readAsString();
    final List<dynamic> qrCodes = jsonDecode(contents);
    return qrCodes.any((item) => item['code'] == qrCode);
  }

  Future<void> _registerQRCode(String? qrCode, String coords) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = io.File('${directory.path}/qr_codes.json');
    List<Map<String, String>> qrCodes = [];
    if (await file.exists()) {
      final contents = await file.readAsString();
      qrCodes = List<Map<String, String>>.from(jsonDecode(contents));
    }
    qrCodes.add({'code': qrCode!, 'coords': coords});
    await file.writeAsString(jsonEncode(qrCodes));
  }

  Future<bool> _isAirplaneModeEnabled() async {
    // Placeholder method as Flutter doesn't provide direct API
    // This may need to be replaced with platform-specific code
    return false;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
