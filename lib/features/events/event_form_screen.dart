// lib/features/events/event_form_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';

class EventFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initial;
  const EventFormScreen({super.key, this.docId, this.initial});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _venue = TextEditingController();
  String _status = 'draft';
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _title.text = d['title'] ?? '';
      _desc.text = d['description'] ?? '';
      _venue.text = d['venue'] ?? '';
      _status = d['status'] ?? 'draft';
      _startAt = (d['startAt'] as Timestamp?)?.toDate();
      _endAt = (d['endAt'] as Timestamp?)?.toDate();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _venue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? 'Nuevo evento' : 'Editar evento'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obligatorio' : null,
            ),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(labelText: 'Sede / Lugar'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Borrador')),
                DropdownMenuItem(value: 'published', child: Text('Publicado')),
                DropdownMenuItem(value: 'closed', child: Text('Cerrado')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'draft'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Inicio',
                    value: _startAt,
                    onPicked: (d) => setState(() => _startAt = d),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DatePickerField(
                    label: 'Fin',
                    value: _endAt,
                    onPicked: (d) => setState(() => _endAt = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                if (_startAt != null &&
                    _endAt != null &&
                    _endAt!.isBefore(_startAt!)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('La fecha de fin no puede ser anterior a inicio'),
                  ));
                  return;
                }

                final model = EventModel(
                  id: widget.docId ?? '',
                  title: _title.text.trim(),
                  description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                  venue: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
                  status: _status,
                  startAt: _startAt,
                  endAt: _endAt,
                );

                try {
                  await EventService().upsert(widget.docId, model);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error guardando: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '—'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
          ' ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}';
    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        onPicked(DateTime(
          date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0,
        ));
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $text'),
      ),
    );
  }
}
