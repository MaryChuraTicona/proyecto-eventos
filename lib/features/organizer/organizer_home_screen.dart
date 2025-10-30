import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/models/admin_event_model.dart';
import 'organizer_event_detail_screen.dart';
import 'services/organizer_event_service.dart';

class OrganizerHomeScreen extends StatelessWidget {
  const OrganizerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Inicia sesión para administrar tus eventos.'),
        ),
      );
    }

    final service = OrganizerEventService();

    return StreamBuilder<List<AdminEventModel>>(
      stream: service.watchEventsFor(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Panel de organizador')),
            body: Center(
              child: Text('Error al cargar tus eventos: ${snapshot.error}'),
            ),
          );
        }
        final events = snapshot.data ?? const [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel de organizador'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestiona tus eventos asignados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (events.isEmpty && snapshot.connectionState != ConnectionState.waiting)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Aún no te han asignado como organizador. Solicita acceso al administrador.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _EventCard(event: event);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final AdminEventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              event.nombre,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(event.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.calendar_today, label: _formatDateRange(event)),
                _InfoChip(icon: Icons.location_on, label: event.lugarGeneral),
                _InfoChip(icon: Icons.people_alt, label: 'Aforo ${event.aforoGeneral}'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrganizerEventDetailScreen(eventId: event.id),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Administrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(AdminEventModel event) {
    final start = event.fechaInicio;
    final end = event.fechaFin;
    if (start == null && end == null) return 'Fechas por definir';
    String fmt(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    if (start != null && end != null) {
      return '${fmt(start)} - ${fmt(end)}';
    }
    return fmt(start ?? end!);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 16, color: cs.onSecondaryContainer),
      label: Text(label.isEmpty ? 'Por definir' : label),
      backgroundColor: cs.secondaryContainer.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}