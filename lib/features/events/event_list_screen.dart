// lib/features/events/event_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firestore_paths.dart';
import 'event_form_screen.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatelessWidget {
  final Query<Map<String, dynamic>>? query;
  const EventListScreen({super.key, this.query});

  @override
  Widget build(BuildContext context) {
    final q = query ??
        FirebaseFirestore.instance
            .collection(FirestorePaths.eventos)
            .orderBy('startAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos EPIS')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Sin eventos aún'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final title = data['title'] ?? '—';
              final venue = data['venue'] ?? '';
              final status = data['status'] ?? 'draft';
              final startAt = (data['startAt'] as Timestamp?)?.toDate();

              return ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(title),
                subtitle: Text('${_fmt(startAt)}  •  $venue  •  $status'),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
                  ],
                  onSelected: (v) async {
                    if (v == 'edit') {
                      // ignore: use_build_context_synchronously
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(docId: d.id, initial: data),
                        ),
                      );
                    } else if (v == 'delete') {
                      await d.reference.delete();
                    }
                  },
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: d.id)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventFormScreen()),
          );
        },
      ),
    );
  }

  static String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$mi';
  }
}
