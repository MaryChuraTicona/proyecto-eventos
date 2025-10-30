// lib/features/student/student_event_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/event_service.dart';          // define EventView y SessionView
import '../../services/registration_service.dart';
import '../../services/attendance_service.dart';
import 'widgets/certificate_status_card.dart';
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
    final email = FirebaseAuth.instance.currentUser?.email;
    
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
            if (ev.organizers.isNotEmpty) ...[
              const SizedBox(height: 8),
              _OrganizerStrip(organizers: ev.organizers),
            ],
            const SizedBox(height: 12),
             EventRegistrationGate(
              eventId: eventId,
              eventName: ev.name,
              uid: uid,
              email: email,
            ),
            const SizedBox(height: 12),
            CertificateStatusCard(
              eventId: eventId,
              eventName: ev.name,
              uid: uid,
              email: email,
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
class _OrganizerStrip extends StatelessWidget {
  final List<EventOrganizerView> organizers;
  const _OrganizerStrip({required this.organizers});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Organizadores estudiantiles',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: organizers
                  .map(
                    (org) => Chip(
                      avatar: const CircleAvatar(
                        child: Icon(Icons.person_outline, size: 16),
                      ),
                      label: Text(org.displayName.isNotEmpty
                          ? org.displayName
                          : org.email),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
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
 Future<void> _handleRemoteAttendance() async {
    if (widget.uid == null) return;

    final controller = TextEditingController();
    final location = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar asistencia remota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '¿Desde dónde te conectas?',
            hintText: 'Ciudad, institución, país…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Registrar')),
        ],
      ),
    );

    if (location == null || location.trim().isEmpty) {
      controller.dispose();
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await AttendanceService().markIfInWindow(
        uid: widget.uid!,
        eventId: widget.eventId,
        sessionId: widget.s.id,
        start: widget.s.horaInicio.toDate(),
        end: widget.s.horaFin.toDate(),
        extra: {
          'mode': 'remote',
          'remoteLocation': location.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Asistencia remota registrada' : '⚠️ Fuera del horario permitido'),
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
      controller.dispose();
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

     final registrationSvc = RegistrationService();
    
    return StreamBuilder<bool>(
      stream: widget.uid != null
       ? registrationSvc.watchRegistrationStatus(widget.uid!, widget.eventId)
           : Stream.value(false),
      builder: (context, eventSnap) {
      final hasEventRegistration = eventSnap.data ?? false;
        return StreamBuilder<bool>(
          stream: widget.uid != null
          ? registrationSvc.watchRegistrationStatus(widget.uid!, widget.eventId, widget.s.id)
               : Stream.value(false),
          builder: (context, regSnapshot) {
           final registered = regSnapshot.data ?? false;
           return StreamBuilder<bool>(
              stream: widget.uid != null
                  ? AttendanceService().watchAttendanceStatus(widget.eventId, widget.uid!, widget.s.id)
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
                     
                        Text(
                         widget.s.titulo.isEmpty ? '(Sin título)' : widget.s.titulo,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.s.ponenteNombre.isEmpty
                              ? 'Sin ponente asignado'
                              : 'Ponente: ${widget.s.ponenteNombre}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                     
                        Text(
                          '${widget.s.dia} • ${_hm(widget.s.horaInicio)} – ${_hm(widget.s.horaFin)}',
                         style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                  const SizedBox(height: 12),
                       if (!hasEventRegistration)
                          Text(
                            'Completa la inscripción general para habilitar las acciones de esta ponencia.',
                            style: TextStyle(color: cs.error),
                    
                    
                          ),
                           Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!registered)
                              FilledButton(
                                onPressed: (widget.uid == null || _loading || !hasEventRegistration)
                                    ? null
                                    : _handleRegister,
                                child: Text(_loading ? 'Inscribiendo…' : 'Inscribirme'),
                              ),
                            if (registered && !attended)
                              FilledButton(
                                onPressed: _loading ? null : _handleUnregister,
                                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Inscrito'),
                              ),
                            if (attended)
                              FilledButton(
                                onPressed: null,
                                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                                child: const Text('Asistido'),
                              ),
                            if (registered)
                              OutlinedButton(
                                onPressed: (widget.uid == null || _loading)
                                    ? null
                                    : _showQRCode,
                                child: const Text('Ver QR'),
                              ),
                            if (registered && !attended && _inWindow())
                              FilledButton.tonal(
                                onPressed: (widget.uid == null || _loading)
                                    ? null
                                    : _handleMarkAttendance,
                                child: const Text('Marcar asistencia presencial'),
                              ),
                            if (registered && !attended)
                              OutlinedButton(
                                onPressed: (widget.uid == null || _loading)
                                    ? null
                                    : _handleRemoteAttendance,
                                child: const Text('Registrar asistencia remota'),
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
class EventRegistrationGate extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String? uid;
  final String? email;

  const EventRegistrationGate({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.uid,
    required this.email,
  });

  bool get _isInstitutional => (email ?? '').toLowerCase().endsWith('@virtual.upt.pe');

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
          child: Text('Inicia sesión con tu correo institucional para inscribirte al evento.'),
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: RegistrationService().watchRegistrationStatus(uid!, eventId),
      builder: (context, snap) {
        final registered = snap.data ?? false;

        if (registered) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(Icons.check_circle, color: cs.primary),
              title: const Text('Inscripción general completada'),
              subtitle: Text('Ya puedes gestionar tus ponencias y asistencia de "$eventName".'),
            ),
          );
        }

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
                Text(
                  'Completa tu inscripción general',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Responde una sola vez preguntas de ocupación, institución, edad y ciclo académico. '
                  'Esto habilita tus registros a las ponencias del evento.',
                ),
                const SizedBox(height: 12),
                              FilledButton(
                  onPressed: () async {
                    final answers = await showEventQuestionnaireSheet(
                      context,
                      isInstitutional: _isInstitutional,
                      email: email ?? '',
                    );
                    if (answers == null) return;
                    try {
                      await RegistrationService().register(uid!, eventId, null, answers);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Inscripción general completada.')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al registrar: $e')),
                      );
                    }
                  },
                  child: const Text('Responder formulario'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<Map<String, dynamic>?> showEventQuestionnaireSheet(
  BuildContext context, {
  required bool isInstitutional,
  required String email,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuestionnaireSheet(
      isInstitutional: isInstitutional,
      email: email,
    ),
  );
}

class _QuestionnaireSheet extends StatefulWidget {
  final bool isInstitutional;
  final String email;

  const _QuestionnaireSheet({
    required this.isInstitutional,
    required this.email,
  });

  @override
  State<_QuestionnaireSheet> createState() => _QuestionnaireSheetState();
}

class _QuestionnaireSheetState extends State<_QuestionnaireSheet> {
  final _form = GlobalKey<FormState>();
  final _institucion = TextEditingController();
  final _edad = TextEditingController();
  String _ocupacion = 'Estudiante EPIS';
  String _ciclo = 'I';

  @override
  void initState() {
    super.initState();
    if (widget.isInstitutional) {
      _ocupacion = 'Estudiante EPIS';
      _institucion.text = 'Universidad Privada de Tacna - EPIS';
    }
  }

  @override
  void dispose() {
    _institucion.dispose();
    _edad.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inscripción al evento', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ocupacion,
              decoration: const InputDecoration(labelText: 'Ocupación'),
              items: const [
                DropdownMenuItem(value: 'Estudiante EPIS', child: Text('Estudiante EPIS')),
                DropdownMenuItem(value: 'Estudiante externo', child: Text('Estudiante externo')),
                DropdownMenuItem(value: 'Docente', child: Text('Docente')),
                DropdownMenuItem(value: 'Profesional', child: Text('Profesional')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _ocupacion = value ?? _ocupacion),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _institucion,
              decoration: const InputDecoration(labelText: 'Institución de procedencia'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _edad,
              decoration: const InputDecoration(labelText: 'Edad'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Requerido';
                final n = int.tryParse(value.trim());
                if (n == null || n <= 0) return 'Edad no válida';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ciclo,
              decoration: const InputDecoration(labelText: 'Ciclo académico'),
            items: const [
                DropdownMenuItem(value: 'I', child: Text('I')),
                DropdownMenuItem(value: 'II', child: Text('II')),
                DropdownMenuItem(value: 'III', child: Text('III')),
                DropdownMenuItem(value: 'IV', child: Text('IV')),
                DropdownMenuItem(value: 'V', child: Text('V')),
                DropdownMenuItem(value: 'VI', child: Text('VI')),
                DropdownMenuItem(value: 'VII', child: Text('VII')),
                DropdownMenuItem(value: 'VIII', child: Text('VIII')),
                DropdownMenuItem(value: 'IX', child: Text('IX')),
                DropdownMenuItem(value: 'X', child: Text('X')),
                DropdownMenuItem(value: 'Egresado', child: Text('Egresado')),
                DropdownMenuItem(value: 'No estudio', child: Text('No estudio')),
              ],
              onChanged: (value) => setState(() => _ciclo = value ?? _ciclo),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final edad = int.parse(_edad.text.trim());
                      Navigator.pop(context, {
                        'ocupacion': _ocupacion,
                        'institucion': _institucion.text.trim(),
                        'edad': edad,
                        'ciclo': _ciclo,
                        'email': widget.email,
                        'isInstitutional': widget.isInstitutional,
                      });
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
