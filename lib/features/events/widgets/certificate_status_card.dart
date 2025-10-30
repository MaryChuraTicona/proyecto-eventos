import 'package:flutter/material.dart';

import '../../../services/certificate_service.dart';

class CertificateStatusCard extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String? uid;
  final String? email;

  const CertificateStatusCard({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.uid,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (uid == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Inicia sesión para ver el progreso de tu certificado.'),
        ),
      );
    }

    return StreamBuilder<CertificateProgress>(
      stream: CertificateService().watchProgress(uid!, eventId),
      builder: (context, snapshot) {
        final progress = snapshot.data ??
            const CertificateProgress(
              totalSessions: 0,
              attendedSessions: 0,
              percentage: 0,
              issued: false,
              issuedAt: null,
              downloadUrl: null,
            );

        final ratio = progress.totalSessions == 0
            ? 0.0
            : progress.attendedSessions / progress.totalSessions;

        final percentageText = (ratio * 100).toStringAsFixed(0);
        final emailLabel = (email == null || email!.isEmpty)
            ? 'tu correo registrado'
            : email!;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Certificación por asistencia',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress.totalSessions == 0 ? 0 : ratio.clamp(0.0, 1.0),
                  backgroundColor: cs.surfaceVariant,
                  color: cs.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.attendedSessions} de ${progress.totalSessions} ponencias registradas • $percentageText%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (progress.issued)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Certificado emitido el ${_formatDate(progress.issuedAt)}. Revisa $emailLabel o descárgalo desde aquí cuando esté disponible.',
                          ),
                        ),
                      ],
                    ),
                  )
                else if (progress.canIssue)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: email == null || email!.isEmpty
                          ? null
                          : () async {
                              try {
                                await CertificateService().issueCertificate(
                                  uid: uid!,
                                  eventId: eventId,
                                  email: email!,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Certificado generado para "$eventName". Lo encontrarás en tu bandeja.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('No se pudo emitir: $e')),
                                );
                              }
                            },
                      child: const Text('Emitir certificado'),
                    ),
                  )
                else if (email == null || email!.isEmpty)
                  Text(
                    'Actualiza tu correo de contacto para poder recibir el certificado de "$eventName".',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  )
                else
                  Text(
                    progress.totalSessions == 0
                        ? 'Aún no hay ponencias registradas para calcular tu certificado.'
                        : 'Necesitas al menos el 80% de asistencia para emitir tu certificado.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.error),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'recientemente';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }
}