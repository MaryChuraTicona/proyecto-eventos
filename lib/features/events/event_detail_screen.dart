// lib/features/events/event_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../registrations/register_button.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({required this.eventId, super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _svc = EventService();
  EventModel? _event;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _svc.porId(widget.eventId);
    if (!mounted) return;
    setState(() => _event = e);
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    if (e == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Datos del evento
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((e.description ?? '').isNotEmpty) ...[
                    Text(e.description!),
                    const SizedBox(height: 8),
                  ],
                  Text('Cuándo: ${_fmtDateTime(e.startAt)}'
                      '${e.endAt != null ? ' — ${_fmtDateTime(e.endAt)}' : ''}'),
                  Text('Dónde: ${e.venue ?? '—'}'),
                  Text('Estado: ${e.status}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Ponencias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          // Lista de sesiones del evento
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('eventos')          // si usas 'events', cambia aquí
                .doc(widget.eventId)
                .collection('sesiones')        // si usas 'sessions', cambia aquí
                .orderBy('horaInicio')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No hay ponencias registradas para este evento.');
              }

              return Column(
                children: [
                  for (final d in docs) _SessionTile(
                    eventId: e.id,
                    sessionId: d.id,
                    data: d.data(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$mi';
  }
}

class _SessionTile extends StatelessWidget {
  final String eventId;
  final String sessionId;
  final Map<String, dynamic> data;

  const _SessionTile({
    required this.eventId,
    required this.sessionId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = (data['titulo'] ?? '').toString();
    final ponente = (data['ponenteNombre'] ?? '').toString();
    final dia = (data['dia'] ?? '').toString();
    final hi = data['horaInicio'] as Timestamp?;
    final hf = data['horaFin'] as Timestamp?;
    final rango = '${_hm(hi)} – ${_hm(hf)}';
    final modalidad = (data['modalidad'] ?? '').toString();

    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (ponente.isNotEmpty) ponente,
          if (modalidad.isNotEmpty) modalidad,
          if (dia.isNotEmpty) dia,
          if (rango.trim().isNotEmpty) rango,
        ].where((e) => e.isNotEmpty).join(' • ')),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        trailing: SizedBox(
          width: 140,
          child: RegisterButton(
            eventId: eventId,
            sessionId: sessionId,        // <<< parámetro requerido
          ),
        ),
      ),
    );
  }

  String _hm(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
