// lib/features/admin/forms/session_form.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_session_model.dart';
import '../models/admin_event_model.dart';
import '../models/admin_speaker_model.dart';

import '../services/admin_event_service.dart';
import '../services/admin_session_service.dart';
import '../services/admin_speaker_service.dart';

import '../../../common/ui.dart';

class SessionFormDialog extends StatefulWidget {
  final AdminSessionModel? existing;
  final String? preselectedEventId;
  final String? preselectedEventName;
  final bool allowEventChange;
  const SessionFormDialog({
    super.key,
    this.existing,
    this.preselectedEventId,
    this.preselectedEventName,
    this.allowEventChange = true,
  });

  @override
  State<SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<SessionFormDialog> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _sala = TextEditingController();
  final _link = TextEditingController();
  final _aforo = TextEditingController(text: '0');
  final _tags = TextEditingController();

  final _eventSvc = AdminEventService();
  final _sesSvc = AdminSessionService();
  final _spkSvc = AdminSpeakerService();

  String? _eventoId;
  String? _speakerId;
  String? _speakerName;

  String _modalidad = 'Presencial';
  DateTime _inicio = DateTime.now().add(const Duration(hours: 2));
  DateTime _fin = DateTime.now().add(const Duration(hours: 3));

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _eventoId = s.eventoId;
      _titulo.text = s.titulo;
      _speakerId = s.ponenteId;
      _speakerName = s.ponenteNombre;
      _modalidad = s.modalidad;
      _sala.text = s.sala ?? '';
      _link.text = s.link ?? '';
      _aforo.text = s.aforo.toString();
      _tags.text = s.tags.join(', ');
      _inicio = s.horaInicio.toDate();
      _fin = s.horaFin.toDate();
    } else if (widget.preselectedEventId != null) {
      // Si viene un evento pre-seleccionado, usarlo
      _eventoId = widget.preselectedEventId;
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _sala.dispose();
    _link.dispose();
    _aforo.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final base = isStart ? _inicio : _fin;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: base,
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _inicio = dt;
        if (_fin.isBefore(_inicio)) {
          _fin = _inicio.add(const Duration(hours: 1));
        }
      } else {
        _fin = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _eventoId == null || _speakerId == null) {
      Ui.showSnack(context, 'Completa los campos, selecciona evento y ponente');
      return;
    }
    if (_fin.isBefore(_inicio)) {
      Ui.showSnack(context, 'La hora de fin no puede ser anterior al inicio');
      return;
    }

    final dia =
        "${_inicio.year.toString().padLeft(4, '0')}-"
        "${_inicio.month.toString().padLeft(2, '0')}-"
        "${_inicio.day.toString().padLeft(2, '0')}";

    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final model = AdminSessionModel(
      id: widget.existing?.id ?? '',
      eventoId: _eventoId!,
      titulo: _titulo.text.trim(),
      ponenteId: _speakerId!,                 // <- id del ponente
      ponenteNombre: _speakerName ?? '',      // <- nombre duplicado útil para listas
      dia: dia,
      horaInicio: Timestamp.fromDate(_inicio),
      horaFin: Timestamp.fromDate(_fin),
      modalidad: _modalidad,
      sala: _modalidad == 'Presencial'
          ? (_sala.text.trim().isEmpty ? 'Por definir' : _sala.text.trim())
          : null,
      link: _modalidad == 'Virtual' ? _link.text.trim() : null,
      aforo: int.tryParse(_aforo.text) ?? 0,
      cuposDisponibles: int.tryParse(_aforo.text) ?? 0,
      tags: tags,
      createdAt: widget.existing?.createdAt,
    );

    try {
      await _sesSvc.upsert(model);
      if (mounted) Navigator.pop(context);
      if (mounted) Ui.showSnack(context, 'Ponencia guardada');
    } catch (e) {
      if (mounted) Ui.showSnack(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nueva ponencia' : 'Editar ponencia'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _eventSelector(),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              _speakerSelector(), // <- aquí va el selector de ponente
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _modalidad,
                items: const [
                  DropdownMenuItem(value: 'Presencial', child: Text('Presencial')),
                  DropdownMenuItem(value: 'Virtual', child: Text('Virtual')),
                ],
                onChanged: (v) => setState(() => _modalidad = v ?? 'Presencial'),
                decoration: const InputDecoration(labelText: 'Modalidad'),
              ),
              if (_modalidad == 'Presencial') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _sala,
                  decoration: const InputDecoration(labelText: 'Sala / Lugar'),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _link,
                  decoration: const InputDecoration(labelText: 'Link (Meet/Zoom)'),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Inicio: ${_inicio.toLocal().toString().substring(0, 16)}')),
                  TextButton.icon(
                    onPressed: () => _pickDateTime(isStart: true),
                    icon: const Icon(Icons.access_time),
                    label: const Text('Elegir'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('Fin: ${_fin.toLocal().toString().substring(0, 16)}')),
                  TextButton.icon(
                    onPressed: () => _pickDateTime(isStart: false),
                    icon: const Icon(Icons.access_time_outlined),
                    label: const Text('Elegir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aforo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Aforo'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(labelText: 'Tags (separados por coma)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _eventSelector() {
    return StreamBuilder<List<AdminEventModel>>(
      stream: _eventSvc.streamAll(),
      builder: (context, snap) {
        final allEvents = snap.data ?? const [];
        
        // Agrupar eventos por nombre base (sin años)
        final eventGroups = <String, List<AdminEventModel>>{};
        for (final event in allEvents) {
          final groupName = _extractBaseName(event.nombre);
          eventGroups.putIfAbsent(groupName, () => []).add(event);
        }
        
        // Crear items del dropdown mostrando grupos
        final dropdownItems = <DropdownMenuItem<String>>[];
        final sortedGroups = eventGroups.keys.toList()..sort();
        
        for (final groupName in sortedGroups) {
          final eventsInGroup = eventGroups[groupName]!;
          
          // Ordenar por activos primero, luego por nombre completo
          eventsInGroup.sort((a, b) {
            if (a.estado == 'activo' && b.estado != 'activo') return -1;
            if (a.estado != 'activo' && b.estado == 'activo') return 1;
            return b.nombre.compareTo(a.nombre); // Más reciente primero
          });
          
          // Agregar cada evento del grupo
          for (final event in eventsInGroup) {
            final isMainEvent = eventsInGroup.first == event;
            final displayName = eventsInGroup.length > 1
                ? '${groupName} (${event.nombre})'
                : groupName;
            
            dropdownItems.add(
              DropdownMenuItem<String>(
                value: event.id,
                child: Row(
                  children: [
                    if (eventsInGroup.length > 1 && !isMainEvent)
                      const Padding(
                        padding: EdgeInsets.only(left: 16, right: 4),
                        child: Icon(Icons.subdirectory_arrow_right, size: 16),
                      ),
                    Expanded(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isMainEvent && eventsInGroup.length > 1
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (event.estado == 'activo')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Activo',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        }
          if (!widget.allowEventChange && _eventoId != null) {
          final selectedName = widget.preselectedEventName ??
              allEvents.firstWhere(
                (element) => element.id == _eventoId,
                orElse: () => AdminEventModel(
                  id: _eventoId!,
                  nombre: widget.preselectedEventName ?? 'Evento',
                  tipo: '',
                  descripcion: '',
                  fechaInicio: null,
                  fechaFin: null,
                  dias: const [],
                  lugarGeneral: '',
                  modalidadGeneral: '',
                  aforoGeneral: 0,
                  estado: '',
                  requiereInscripcionPorSesion: true,
                  createdBy: '',
                ),
              ).nombre;

          return TextFormField(
            readOnly: true,
            initialValue: selectedName,
            decoration: const InputDecoration(
              labelText: 'Evento asignado',
              border: OutlineInputBorder(),
            ),
          );
        }
        return DropdownButtonFormField<String>(
          value: _eventoId,
          isExpanded: true,
          items: dropdownItems,
          onChanged: (v) => setState(() => _eventoId = v),
          decoration: const InputDecoration(
            labelText: 'Evento',
            border: OutlineInputBorder(),
            helperText: 'Selecciona el evento específico',
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un evento' : null,
        );
      },
    );
  }
  
  /// Extrae el nombre base eliminando años y ediciones
  String _extractBaseName(String eventName) {
    String cleaned = eventName.replaceAll(RegExp(r'\b20\d{2}\b'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\b(Edición|Edition|Ed\.|Vol\.|Volumen)\s*\d*\b', caseSensitive: false), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\b[IVX]+\s*$'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[\s\-\.]+$'), '').trim();
    return cleaned.isEmpty ? eventName.trim() : cleaned;
  }

  Widget _speakerSelector() {
    return StreamBuilder<List<AdminSpeakerModel>>(
      stream: _spkSvc.streamAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return Text('Error: ${snap.error}');
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Text('No hay ponentes registrados.');
        }
        // si estamos editando y tenemos id, asegura el nombre
        if (_speakerId != null && (_speakerName == null || _speakerName!.isEmpty)) {
          final m = items.where((e) => e.id == _speakerId);
          if (m.isNotEmpty) _speakerName = m.first.nombre;
        }
        return DropdownButtonFormField<String>(
          value: _speakerId,
          isExpanded: true,
          items: items
              .map((p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.nombre.isEmpty ? '(sin nombre)' : p.nombre),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() {
              _speakerId = v;
              _speakerName = v == null ? null : items.firstWhere((e) => e.id == v).nombre;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Ponente',
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un ponente' : null,
        );
      },
    );
  }
}
