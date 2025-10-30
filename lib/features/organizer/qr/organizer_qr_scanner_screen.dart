import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../services/attendance_service.dart';

class OrganizerQrScannerScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const OrganizerQrScannerScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<OrganizerQrScannerScreen> createState() => _OrganizerQrScannerScreenState();
}

class _OrganizerQrScannerScreenState extends State<OrganizerQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_processing) return;
    final barcode = capture.barcodes.isEmpty ? null : capture.barcodes.first;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _processing = true;
      _statusMessage = 'Validando código…';
      _statusColor = null;
    });

    _processPayload(raw).whenComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _processing = false;
            });
          }
        });
      }
    });
  }

  Future<void> _processPayload(String payload) async {
    try {
      final segments = payload.split(';');
      final map = <String, String>{};
      for (final seg in segments) {
        final parts = seg.split(':');
        if (parts.length == 2) {
          map[parts[0]] = parts[1];
        }
      }

      final eventId = map['ev'];
      final sessionId = map['se'];
      final userId = map['u'];
      final expMs = int.tryParse(map['exp'] ?? '');

      if (eventId == null || sessionId == null || userId == null) {
        _setStatus('QR inválido', Colors.red);
        return;
      }
      if (eventId != widget.eventId) {
        _setStatus('Este código pertenece a otro evento.', Colors.orange);
        return;
      }
      if (expMs != null && DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(expMs))) {
        _setStatus('El código expiró. Solicita al estudiante generar uno nuevo.', Colors.orange);
        return;
      }

      final organizerId = FirebaseAuth.instance.currentUser?.uid;
      final extra = {
        'mode': 'qr',
        'scannedBy': organizerId,
        'scannedAt': FieldValue.serverTimestamp(),
      };

      await AttendanceService().mark(widget.eventId, userId, sessionId, extra);
      _setStatus('Asistencia registrada ✅', Colors.green);
    } catch (e) {
      _setStatus('Error al registrar asistencia: $e', Colors.red);
    }
  }

  void _setStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear asistencia – ${widget.eventName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleCapture,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: cs.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Escanea el QR de los estudiantes al ingresar a la ponencia. El código expira en pocos minutos para evitar fraudes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_statusMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_statusColor ?? cs.primaryContainer).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _statusColor ?? cs.primaryContainer),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusColor ?? cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}