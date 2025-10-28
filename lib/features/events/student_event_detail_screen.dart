// lib/features/student/student_event_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/event_service.dart';          // define EventView y SessionView
import '../../services/registration_service.dart';
import '../../services/attendance_service.dart';

class StudentEventDetailScreen extends StatelessWidget {
  final String eventId;
  const StudentEventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de evento')),
      body: _EventDetailBody(eventId: eventId),
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  final String eventId;
  const _EventDetailBody({required this.eventId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<EventView>(
      stream: EventService().watchEventWithSessions(eventId),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) {
          return const Center(child: Text('Evento no encontrado'));
        }
        final ev = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Card(
              elevation: 0,
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  ev.name.isEmpty ? '(Sin nombre)' : ev.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${_dmy(ev.start)} – ${_dmy(ev.end)}${ev.venue != null && ev.venue!.isNotEmpty ? ' • ${ev.venue}' : ''}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Ponencias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (ev.sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Aún no hay ponencias para este evento.'),
              ),
            for (final s in ev.sessions)
              _SessionTile(eventId: eventId, s: s, uid: uid),
          ],
        );
      },
    );
  }

  String _dmy(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$mi';
  }
}

class _SessionTile extends StatefulWidget {
  final String eventId;
  final SessionView s;
  final String? uid;
  const _SessionTile({required this.eventId, required this.s, required this.uid});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _loading = false;

  bool _inWindow() {
    final now = DateTime.now();
    final start = widget.s.horaInicio.toDate().subtract(const Duration(minutes: 15));
    final end = widget.s.horaFin.toDate().add(const Duration(minutes: 30));
    return now.isAfter(start) && now.isBefore(end);
  }

  Future<void> _handleRegister() async {
    if (widget.uid == null) return;
    
    setState(() => _loading = true);
    try {
      await RegistrationService().register(widget.uid!, widget.eventId, widget.s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Te inscribiste correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUnregister() async {
    if (widget.uid == null) return;
    
    setState(() => _loading = true);
    try {
      await RegistrationService().unregister(widget.uid!, widget.eventId, widget.s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Inscripción cancelada'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleMarkAttendance() async {
    if (widget.uid == null) return;
    
    setState(() => _loading = true);
    try {
      final ok = await AttendanceService().markIfInWindow(
        uid: widget.uid!,
        eventId: widget.eventId,
        sessionId: widget.s.id,
        start: widget.s.horaInicio.toDate(),
        end: widget.s.horaFin.toDate(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Asistencia marcada' : '⚠️ Fuera de ventana de tiempo'),
          backgroundColor: ok ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showQRCode() {
    if (widget.uid == null) return;
    
    final exp = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    final payload = 'ev:${widget.eventId};se:${widget.s.id};u:${widget.uid};exp:$exp';
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2),
            const SizedBox(width: 12),
            const Expanded(child: Text('Tu QR de asistencia')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: payload, size: 240),
            const SizedBox(height: 16),
            Text(
              'Muestra este código al organizador',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Usar StreamBuilder para actualizaciones en tiempo real
    return StreamBuilder<bool>(
      stream: widget.uid != null
          ? RegistrationService().watchRegistrationStatus(
              widget.uid!, widget.eventId, widget.s.id)
          : Stream.value(false),
      builder: (context, regSnapshot) {
        final registered = regSnapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: widget.uid != null
              ? AttendanceService().watchAttendanceStatus(
                  widget.eventId, widget.uid!, widget.s.id)
              : Stream.value(false),
          builder: (context, attSnapshot) {
            final attended = attSnapshot.data ?? false;

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
                  children: [
                    // Título y ponente
                    Text(
                      widget.s.titulo.isEmpty ? '(Sin título)' : widget.s.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Información
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.s.ponenteNombre.isEmpty 
                                ? 'Sin ponente' 
                                : widget.s.ponenteNombre,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.s.dia} • ${_hm(widget.s.horaInicio)} – ${_hm(widget.s.horaFin)}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Botones de acción
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Botón de inscripción / des-inscripción
                        if (!registered)
                          FilledButton.icon(
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_circle_outline),
                            label: Text(_loading ? 'Inscribiendo...' : 'Inscribirme'),
                            onPressed: (widget.uid == null || _loading)
                                ? null
                                : _handleRegister,
                          ),
                        
                        if (registered && !attended)
                          FilledButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Inscrito'),
                            onPressed: _loading ? null : _handleUnregister,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        
                        if (attended)
                          FilledButton.icon(
                            icon: const Icon(Icons.verified),
                            label: const Text('Asistido'),
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                            ),
                          ),
                        
                        // Botón de QR (solo si está inscrito)
                        if (registered)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Ver QR'),
                            onPressed: (widget.uid == null || _loading)
                                ? null
                                : _showQRCode,
                          ),
                        
                        // Botón de marcar asistencia (solo si está inscrito y no ha asistido)
                        if (registered && !attended && _inWindow())
                          FilledButton.tonalIcon(
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Marcar asistencia'),
                            onPressed: (widget.uid == null || _loading)
                                ? null
                                : _handleMarkAttendance,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _hm(Timestamp ts) {
    final d = ts.toDate();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
