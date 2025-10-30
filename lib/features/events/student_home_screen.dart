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
              final estado = (data['estado'] ?? 'borrador')
                  .toString()
                  .toLowerCase();
              final fi = _toDate(data['fechaInicio']);
             final ff = _toDate(data['fechaFin']);
              final allowedStates = {
                'activo',
                'publicado',
                'en curso',
                'habilitado',
                'vigente',
              };
              final isActive = allowedStates.contains(estado);
              if (!isActive) return false;

              // Mostrar eventos activos aunque hayan iniciado hace poco.
              final tolerance = now.subtract(const Duration(days: 7));
              final inRange = fi == null || fi.isAfter(tolerance) ||
                  (ff != null && ff.isAfter(now));
              return inRange;
            })
            .toList();

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No hay eventos activos',
            subtitle: 'Por el momento no hay eventos publicados. Cuando haya nuevos eventos disponibles, aparecerán aquí automáticamente.',
          );
        }
 QueryDocumentSnapshot<Map<String, dynamic>>? featuredCatec;
        final remainingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in docs) {
          final data = doc.data();
          final nombre = (data['nombre'] ?? '').toString().toUpperCase();
          if (featuredCatec == null && nombre.contains('CATEC')) {
            featuredCatec = doc;
          } else {
            remainingDocs.add(doc);
          }
        }

        final totalItems = remainingDocs.length + (featuredCatec != null ? 1 : 0);


        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          
           itemCount: totalItems,
          separatorBuilder: (_, index) {
            if (featuredCatec != null && index == 0) {
              return const SizedBox(height: 20);
            }
            return const SizedBox(height: 12);
          },
          itemBuilder: (context, index) {
            if (featuredCatec != null && index == 0) {
              return _FeaturedCatecCard(doc: featuredCatec!);
            }

            final adjustedIndex = featuredCatec != null ? index - 1 : index;
            final doc = remainingDocs[adjustedIndex];
            return _StandardEventCard(doc: doc);
          },
        );
      },
    );
  }
}

            class _FeaturedCatecCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
   const _FeaturedCatecCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = doc.data();
    final id = doc.id;
    final nombre = (data['nombre'] ?? 'CATEC').toString();
    final descripcion = (data['descripcion'] ?? '').toString();
    final lugar = (data['lugarGeneral'] ?? '').toString();
    final fi = _toDate(data['fechaInicio']);
    final ff = _toDate(data['fechaFin']);
    final when = '${_fmt(fi)}${ff != null ? ' – ${_fmt(ff)}' : ''}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.95),
                    cs.secondary.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: -12,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 160,
                color: cs.onPrimary.withOpacity(0.08),
              ),

),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: cs.onPrimary.withOpacity(0.18)),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: cs.onPrimary),
                        Text(
                          'Evento destacado',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    nombre,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1.2,
                    ),
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      descripcion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimary.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoPill(
                        icon: Icons.calendar_month_rounded,
                        label: when,
                        background: cs.onPrimary.withOpacity(0.15),
                        foreground: cs.onPrimary,
                      ),
                      if (lugar.isNotEmpty)
                        _InfoPill(
                          icon: Icons.place_outlined,
                          label: lugar,
                          background: cs.onPrimary.withOpacity(0.12),
                          foreground: cs.onPrimary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.onPrimary,
                        foregroundColor: cs.primary,
                      ),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Descubrir CATEC'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardEventCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _StandardEventCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = doc.data();
    final id = doc.id;
    final nombre = (data['nombre'] ?? '').toString();
    final descripcion = (data['descripcionCorta'] ?? data['descripcion'] ?? '')
        .toString();
    final lugar = (data['lugarGeneral'] ?? '').toString();
    final fi = _toDate(data['fechaInicio']);
    final ff = _toDate(data['fechaFin']);
    final when = '${_fmt(fi)}${ff != null ? ' – ${_fmt(ff)}' : ''}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    size: 22,
                    color: cs.primary,
                  ),
             
                ),
               
  const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),

                      ),
                   

                 if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: Icons.calendar_today_rounded,
                  label: when,
                  background: cs.primaryContainer.withOpacity(0.25),
                  foreground: cs.primary,
                ),
                if (lugar.isNotEmpty)
                  _InfoPill(
                    icon: Icons.place_outlined,
                    label: lugar,
                    background: cs.secondaryContainer.withOpacity(0.22),
                    foreground: cs.secondary,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
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
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Icon(icon, size: 16, color: foreground),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
        
      
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
            final cs = Theme.of(context).colorScheme;
            final rango = '${_hm(it.horaInicio)} – ${_hm(it.horaFin)}';
            final estadoAsistencia = it.attended
                ? 'Asistido'
                : it.finished
                    ? 'Finalizado'
                    : 'Inscrito';

            final estadoIcon = it.attended
                ? Icons.verified_rounded
                : it.finished
                    ? Icons.history_toggle_off_rounded
                    : Icons.event_available_rounded;
            final dayLabel = it.dia.isNotEmpty
                ? it.dia
                : _friendlyDay(it.horaInicio);
            final registeredAtLabel =
                it.createdAt != null ? _formatRegistrationDate(it.createdAt!) : null;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              
               child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.schedule_outlined,
                            size: 22,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                it.eventName,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          icon: Icon(estadoIcon, size: 18),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(
                          icon: Icons.event_outlined,
                          label: dayLabel,
                          background: cs.primaryContainer.withOpacity(0.25),
                          foreground: cs.primary,
                        ),
                        _InfoPill(
                          icon: Icons.access_time_rounded,
                          label: rango,
                          background: cs.secondaryContainer.withOpacity(0.22),
                          foreground: cs.secondary,
                        ),
                        if (it.location.isNotEmpty)
                          _InfoPill(
                            icon: Icons.place_outlined,
                            label: it.location,
                            background: cs.tertiaryContainer.withOpacity(0.2),
                            foreground: cs.tertiary,
                          ),
                      ],
                    ),
                    if (registeredAtLabel != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Inscrito el $registeredAtLabel',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    
                  ],
                  ],
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

String _friendlyDay(Timestamp ts) {
  final d = ts.toDate();
  const weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final weekday = weekdays[(d.weekday - 1) % weekdays.length];
  final month = months[(d.month - 1) % months.length];
  final capitalizedMonth = month[0].toUpperCase() + month.substring(1);
  return '$weekday ${d.day} de $capitalizedMonth ${d.year}';
}

String _formatRegistrationDate(Timestamp ts) {
  final d = ts.toDate();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year} $hh:$mi';
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
