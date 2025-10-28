// lib/features/admin/widgets/speaker_list.dart
import 'package:flutter/material.dart';

import '../../../common/ui.dart';
import '../services/admin_speaker_service.dart';
import '../models/admin_speaker_model.dart';
import '../forms/speaker_form.dart';

class SpeakerList extends StatelessWidget {
  const SpeakerList({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AdminSpeakerService();

    return StreamBuilder<List<AdminSpeakerModel>>(
      stream: svc.streamAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <AdminSpeakerModel>[];
        if (items.isEmpty) return const Center(child: Text('Sin ponentes'));

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = items[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              title: Text(
                s.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
             subtitle: Text(
                [
                  if (s.institucion.isNotEmpty) s.institucion,
                  s.emailCertificado,
                ].where((value) => value.isNotEmpty).join(' • '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => SpeakerFormDialog(existing: s),
                    );
                  } else if (v == 'del') {
                    try {
                      await svc.delete(s.id);
                      if (context.mounted) {
                        Ui.showSnack(context, 'Ponente eliminado');
                      }
                    } catch (err) {
                      if (context.mounted) {
                        Ui.showSnack(context, 'Error: $err');
                      }
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'del', child: Text('Eliminar')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
