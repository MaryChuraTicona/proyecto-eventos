// lib/features/admin/widgets/session_list.dart
import 'package:flutter/material.dart';

import '../models/admin_event_model.dart';
import '../models/admin_session_model.dart';
import '../services/admin_event_service.dart';
import '../services/admin_session_service.dart';

import '../../../common/ui.dart';
import '../forms/session_form.dart';

class SessionList extends StatefulWidget {
  const SessionList({super.key});
  @override
  State<SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  String? _eventoId;
  final _eventSvc = AdminEventService();
  final _sesSvc = AdminSessionService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _eventSelector(),
        const SizedBox(height: 12),
        if (_eventoId == null)
          const Expanded(child: Center(child: Text('Selecciona un evento')))
        else
          Expanded(
            child: StreamBuilder<List<AdminSessionModel>>(
              stream: _sesSvc.streamByEvent(_eventoId!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return const Center(child: Text('Sin ponencias para este evento'));
                }
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
                        s.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "${s.modalidad} • ${s.dia} • ${s.ponenteNombre} • ${s.cuposDisponibles}/${s.aforo}",
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            // Abrir dialog de edición
                            // ignore: use_build_context_synchronously
                            showDialog(
                              context: context,
                              builder: (_) => SessionFormDialog(existing: s),
                            );
                          } else if (v == 'del') {
                            try {
                              await _sesSvc.delete(s.eventoId, s.id);
                              if (context.mounted) {
                                Ui.showSnack(context, 'Ponencia eliminada');
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
            ),
          ),
      ],
    );
  }

  Widget _eventSelector() {
    return StreamBuilder<List<AdminEventModel>>(
      stream: _eventSvc.streamAll(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return DropdownButtonFormField<String>(
          value: _eventoId,
          isExpanded: true,
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.id,
                  child: Text(e.nombre),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _eventoId = v),
          decoration: const InputDecoration(
            labelText: 'Evento',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
