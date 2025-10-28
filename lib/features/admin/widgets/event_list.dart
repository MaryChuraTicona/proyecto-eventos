import 'package:flutter/material.dart';
import '../../../common/ui.dart';

import '../services/admin_event_service.dart';
import '../models/admin_event_model.dart';
import '../forms/event_form.dart';

class EventList extends StatelessWidget {
  const EventList({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AdminEventService();
    return StreamBuilder<List<AdminEventModel>>(
      stream: svc.streamAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) return const Center(child: Text('Sin eventos'));

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = items[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              title: Text(
                e.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text("${e.tipo} • ${e.estado} • ${e.dias.length} día(s)"),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => EventFormDialog(existing: e),
                    );
                  } else if (v == 'del') {
                    try {
                      await svc.delete(e.id);
                      if (context.mounted) {
                        Ui.showSnack(context, 'Evento eliminado');
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
