// lib/features/student/student_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/registration_service.dart';
import 'student_event_detail_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Eventos EPIS'),
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
          actions: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              backgroundImage: user?.photoURL != null 
                  ? NetworkImage(user!.photoURL!) 
                  : null,
              child: user?.photoURL == null
                  ? Icon(
                      Icons.person,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: cs.onPrimaryContainer,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.event_available_rounded, size: 20),
                text: 'Eventos Disponibles',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Mis Inscripciones',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AvailableEventsTab(),
            _MyHistoryTab(),
          ],
        ),
        backgroundColor: cs.surface,
      ),
    );
  }
}

class _AvailableEventsTab extends StatelessWidget {
  const _AvailableEventsTab();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // eventos (colección: 'eventos') ordenados por fechaInicio
    final q = FirebaseFirestore.instance
        .collection('eventos')
        .orderBy('fechaInicio'); // evitamos índice compuesto

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((d) {
              final data = d.data();
              final estado = (data['estado'] ?? 'borrador').toString();
              final fi = _toDate(data['fechaInicio']);
              return estado == 'activo' && (fi == null || !fi.isBefore(now));
            })
            .toList();

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No hay eventos activos',
            subtitle: 'Por el momento no hay eventos publicados. Cuando haya nuevos eventos disponibles, aparecerán aquí automáticamente.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final id = docs[i].id;
            final nombre = (d['nombre'] ?? '').toString();
            final lugar = (d['lugarGeneral'] ?? '').toString();
            final fi = _toDate(d['fechaInicio']);
            final ff = _toDate(d['fechaFin']);

            final when = '${_fmt(fi)}${ff != null ? ' – ${_fmt(ff)}' : ''}';
            final subtitleParts = <String>[when];
            if (lugar.isNotEmpty) subtitleParts.add(lugar);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(subtitleParts.join(' • ')),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Ver detalles'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentEventDetailScreen(eventId: id),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MyHistoryTab extends StatelessWidget {
  const _MyHistoryTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
        icon: Icons.lock_outline,
        title: 'Debes iniciar sesión',
        subtitle: 'Ingresa con tu cuenta para ver tu historial.',
      );
    }

    return StreamBuilder<List<UserRegistrationView>>(
      stream: RegistrationService().watchUserHistory(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <UserRegistrationView>[];
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Sin inscripciones todavía',
            subtitle: 'Ve a la pestaña "Eventos Disponibles" para inscribirte a ponencias y eventos.',
            action: FilledButton.icon(
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Ver Eventos'),
              onPressed: () {
                // Cambiar a la primera tab
                DefaultTabController.of(context).animateTo(0);
              },
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final it = items[i];
            final rango = '${_hm(it.horaInicio)} – ${_hm(it.horaFin)}';
            final estadoAsistencia = it.attended
                ? 'Asistido'
                : it.finished
                    ? 'Finalizado'
                    : 'Inscrito';

            final subtitleParts = <String>[
              it.eventName,
              if (it.dia.isNotEmpty) it.dia,
              rango,
            ];

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  it.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(subtitleParts.join(' • ')),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(estadoAsistencia),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentEventDetailScreen(eventId: it.eventId),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* helpers */
DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _fmt(DateTime? dt) {
  if (dt == null) return '—';
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${dt.year} $hh:$mi';
}

String _hm(Timestamp ts) {
  final d = ts.toDate();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
