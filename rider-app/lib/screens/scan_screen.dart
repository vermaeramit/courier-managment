import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Barcode / QR scanner. Returns the scanned value (a TrackingId) to the caller.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan package')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null && code.isNotEmpty) {
            _handled = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
