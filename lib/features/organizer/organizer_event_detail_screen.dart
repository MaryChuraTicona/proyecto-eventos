import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../admin/forms/session_form.dart';
import '../admin/forms/speaker_form.dart';
import '../admin/models/admin_event_model.dart';
import '../admin/models/admin_session_model.dart';
import '../admin/models/admin_speaker_model.dart';
import '../admin/services/admin_session_service.dart';
import '../admin/services/admin_speaker_service.dart';
import '../../services/certificate_service.dart';
import '../../services/attendance_service.dart';
import 'qr/organizer_qr_scanner_screen.dart';
import 'services/organizer_event_service.dart';

class OrganizerEventDetailScreen extends StatefulWidget {
  final String eventId;
  const OrganizerEventDetailScreen({super.key, required this.eventId});

  @override
  State<OrganizerEventDetailScreen> createState() => _OrganizerEventDetailScreenState();
}

class _OrganizerEventDetailScreenState extends State<OrganizerEventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  final _eventSvc = OrganizerEventService();

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminEventModel?>(
      stream: _eventSvc.watchEvent(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final event = snapshot.data;
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('El evento ya no está disponible.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(event.nombre),
            bottom: TabBar(
              controller: _controller,
              tabs: const [
                Tab(icon: Icon(Icons.schedule), text: 'Ponencias'),
                Tab(icon: Icon(Icons.mic), text: 'Ponentes'),
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'Asistencia'),
              ],
            ),
          ),
          floatingActionButton: _buildFab(context, event),
          body: TabBarView(
            controller: _controller,
            children: [
              OrganizerSessionsTab(event: event),
              OrganizerSpeakersTab(event: event),
              OrganizerAttendanceTab(event: event),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildFab(BuildContext context, AdminEventModel event) {
    switch (_controller.index) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'add-session',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => SessionFormDialog(
                existing: null,
                preselectedEventId: event.id,
                preselectedEventName: event.nombre,
                allowEventChange: false,
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Nueva ponencia'),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'add-speaker',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const SpeakerFormDialog(),
            );
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Registrar ponente'),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'scan-attendance',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrganizerQrScannerScreen(
                  eventId: event.id,
                  eventName: event.nombre,
                ),
              ),
            );
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear QR'),
        );
      default:
        return null;
    }
  }
}

class OrganizerSessionsTab extends StatelessWidget {
  final AdminEventModel event;
  const OrganizerSessionsTab({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminSessionModel>>(
      stream: AdminSessionService().streamByEvent(event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data ?? const [];
        if (sessions.isEmpty) {
          return const Center(
            child: Text('Aún no hay ponencias registradas. Agrega la primera.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return _SessionCard(event: event, session: session);
          },
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AdminEventModel event;
  final AdminSessionModel session;
  const _SessionCard({required this.event, required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => SessionFormDialog(
              existing: session,
              preselectedEventId: event.id,
              preselectedEventName: event.nombre,
              allowEventChange: false,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Ponente: ${session.ponenteNombre.isEmpty ? 'Por definir' : session.ponenteNombre}'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.event_available, size: 16),
                    label: Text(session.dia),
                  ),
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(
                        '${_fmtTime(session.horaInicio)} - ${_fmtTime(session.horaFin)}'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.location_on_outlined, size: 16),
                    label: Text(session.sala ?? 'Lugar por definir'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.accessibility_new, size: 16),
                    label: Text('Aforo ${session.aforo}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(Timestamp ts) {
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class OrganizerSpeakersTab extends StatelessWidget {
  final AdminEventModel event;
  const OrganizerSpeakersTab({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminSpeakerModel>>(
      stream: AdminSpeakerService().streamAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final speakers = snapshot.data ?? const [];
        if (speakers.isEmpty) {
          return const Center(
            child: Text('Todavía no hay ponentes registrados. Usa el botón para agregar.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: speakers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final speaker = speakers[index];
            return _SpeakerCard(event: event, speaker: speaker);
          },
        );
      },
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  final AdminEventModel event;
  final AdminSpeakerModel speaker;
  const _SpeakerCard({required this.event, required this.speaker});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(speaker.nombre),
        subtitle: Text([
          if (speaker.institucion.isNotEmpty) speaker.institucion,
          if (speaker.emailCertificado.isNotEmpty) speaker.emailCertificado,
        ].join(' • ')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              showDialog(
                context: context,
                builder: (_) => SpeakerFormDialog(existing: speaker),
              );
            } else if (value == 'certificate') {
              if (speaker.emailCertificado.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registra un correo de certificado para el ponente.')),
                );
                return;
              }
              try {
                await CertificateService().issueSpeakerCertificate(
                  eventId: event.id,
                  speakerId: speaker.id,
                  speakerName: speaker.nombre,
                  email: speaker.emailCertificado,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Certificado solicitado para ${speaker.nombre}.'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo emitir: $e')),
                );
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar ponente')),
            PopupMenuItem(value: 'certificate', child: Text('Enviar certificado')),
          ],
        ),
      ),
    );
  }
}

class OrganizerAttendanceTab extends StatelessWidget {
  final AdminEventModel event;
  const OrganizerAttendanceTab({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AttendanceService().watchEventAttendance(event.id),
      builder: (context, attendanceSnap) {
        final attendance = attendanceSnap.data ?? const [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('eventos')
              .doc(event.id)
              .collection('sesiones')
              .orderBy('horaInicio')
              .snapshots(),
          builder: (context, sessionSnap) {
            if (sessionSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = sessionSnap.data?.docs ?? const [];
            final totalPresent = attendance
                .where((a) => (a['present'] ?? true) == true)
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.insights),
                    title: Text('Asistencias registradas: $totalPresent'),
                    subtitle: Text(
                        '${sessions.length} ponencias programadas • ${event.organizers.length} organizadores'),
                  ),
                ),
                const SizedBox(height: 12),
                for (final session in sessions)
                  _AttendanceSessionTile(
                    sessionDoc: session,
                    attendance: attendance,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AttendanceSessionTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> sessionDoc;
  final List<Map<String, dynamic>> attendance;
  const _AttendanceSessionTile({
    required this.sessionDoc,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final data = sessionDoc.data();
    final sessionId = sessionDoc.id;
    final present = attendance.where((a) => a['sessionId'] == sessionId).length;
    final title = (data['titulo'] ?? '').toString();
    final ponente = (data['ponenteNombre'] ?? '').toString();
    final horaInicio = data['horaInicio'] is Timestamp
        ? (data['horaInicio'] as Timestamp).toDate()
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(present.toString()),
        ),
        title: Text(title.isEmpty ? 'Ponencia sin título' : title),
        subtitle: Text([
          if (ponente.isNotEmpty) 'Ponente: $ponente',
          if (horaInicio != null)
            'Inicio: ${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}',
        ].join(' • ')),
      ),
    );
  }
}