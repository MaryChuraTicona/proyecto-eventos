import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/attendance_service.dart';


class QrScannerScreen extends StatefulWidget {
final String eventId;
const QrScannerScreen({super.key, required this.eventId});


@override
State<QrScannerScreen> createState() => _QrScannerScreenState();
}


class _QrScannerScreenState extends State<QrScannerScreen> {
bool _busy = false;


@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('Escanear QR')),
body: MobileScanner(
onDetect: (capture) async {
if (_busy) return;
final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
if (code == null) return;
setState(() => _busy = true);
await AttendanceService().mark(widget.eventId, code); // aquí code=uid del usuario
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asistencia marcada')));
setState(() => _busy = false);
}
},
),
);
}
}