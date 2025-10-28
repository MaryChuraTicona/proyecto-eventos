import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGeneratorWidget extends StatelessWidget {
  final String code;
  const QrGeneratorWidget({required this.code, super.key});
  @override
  Widget build(BuildContext context) => Center(child: QrImageView(data: code, size: 220));
}
