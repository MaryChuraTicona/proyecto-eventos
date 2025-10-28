// lib/features/admin/forms/event_form.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/admin_event_model.dart';
import '../models/admin_session_model.dart';
import '../services/admin_event_service.dart';
import '../services/admin_session_service.dart';
import '../../../common/ui.dart';
import 'session_form.dart';

class EventFormDialog extends StatefulWidget {
  final AdminEventModel? existing;
  const EventFormDialog({super.key, this.existing});

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _lugar = TextEditingController(text: 'EPIS');
  final _aforo = TextEditingController(text: '0');

  DateTime? _inicio;
  DateTime? _fin;
  String _tipo = 'CATEC';
  String _estado = 'activo';
  bool _reqInscSesion = true;

  final _svc = AdminEventService();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nombre.text = e.nombre;
      _descripcion.text = e.descripcion;
      _lugar.text = e.lugarGeneral;
      _aforo.text = e.aforoGeneral.toString();
      _tipo = e.tipo;
      _estado = e.estado;
      _reqInscSesion = e.requiereInscripcionPorSesion;
      _inicio = e.fechaInicio; // ✅ ya son DateTime?
      _fin = e.fechaFin;       // ✅ sin .toDate()
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _lugar.dispose();
    _aforo.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final base = isStart ? (_inicio ?? now) : (_fin ?? _inicio ?? now);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: base,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _inicio = DateTime(picked.year, picked.month, picked.day, 8);
        if (_fin == null || _fin!.isBefore(_inicio!)) _fin = _inicio;
      } else {
        _fin = DateTime(picked.year, picked.month, picked.day, 20);
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_inicio == null || _fin == null) {
      Ui.showSnack(context, 'Selecciona inicio y fin');
      return;
    }
    if (_fin!.isBefore(_inicio!)) {
      Ui.showSnack(context, 'La fecha de fin no puede ser anterior al inicio');
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin-uid';

    final model = AdminEventModel(
      id: widget.existing?.id ?? '',
      nombre: _nombre.text.trim(),
      tipo: _tipo,
      descripcion: _descripcion.text.trim(),
      fechaInicio: _inicio,  // ✅ DateTime directo
      fechaFin: _fin,        // ✅ DateTime directo
      dias: const [],
      lugarGeneral: _lugar.text.trim(),
      modalidadGeneral: 'Mixta',
      aforoGeneral: int.tryParse(_aforo.text) ?? 0,
      estado: _estado,
      requiereInscripcionPorSesion: _reqInscSesion,
      createdBy: currentUid,
      createdAt: widget.existing?.createdAt,
    );

    try {
      await _svc.upsert(model);
      if (mounted) Navigator.pop(context);
      if (mounted) Ui.showSnack(context, 'Evento guardado');
    } catch (e) {
      if (mounted) Ui.showSnack(context, 'Error: $e');
    }
  }

  Future<void> _saveAndAddSession() async {
    if (!_form.currentState!.validate()) return;
    if (_inicio == null || _fin == null) {
      Ui.showSnack(context, 'Selecciona inicio y fin');
      return;
    }
    if (_fin!.isBefore(_inicio!)) {
      Ui.showSnack(context, 'La fecha de fin no puede ser anterior al inicio');
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin-uid';

    final model = AdminEventModel(
      id: '',  // Siempre nuevo
      nombre: _nombre.text.trim(),
      tipo: _tipo,
      descripcion: _descripcion.text.trim(),
      fechaInicio: _inicio,
      fechaFin: _fin,
      dias: const [],
      lugarGeneral: _lugar.text.trim(),
      modalidadGeneral: 'Mixta',
      aforoGeneral: int.tryParse(_aforo.text) ?? 0,
      estado: _estado,
      requiereInscripcionPorSesion: _reqInscSesion,
      createdBy: currentUid,
      createdAt: null,
    );

    try {
      // Guardar el evento y obtener su ID
      final eventId = await _svc.upsertAndGetId(model);
      
      if (!mounted) return;
      
      // Cerrar el diálogo del evento
      Navigator.pop(context);
      
      // Mostrar mensaje de éxito
      Ui.showSnack(context, 'Evento guardado. Ahora agrega ponencias');
      
      // Abrir el formulario de ponencias con el evento pre-seleccionado
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (_) => SessionFormDialog(
          existing: null,
          preselectedEventId: eventId,
          preselectedEventName: _nombre.text.trim(),
        ),
      );
    } catch (e) {
      if (mounted) Ui.showSnack(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo evento' : 'Editar evento'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _tipo,
                items: const [
                  DropdownMenuItem(value: 'CATEC', child: Text('CATEC')),
                  DropdownMenuItem(
                      value: 'Software Libre', child: Text('Software Libre')),
                  DropdownMenuItem(value: 'Microsoft', child: Text('Microsoft')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'CATEC'),
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _inicio == null
                          ? 'Inicio: —'
                          : 'Inicio: ${_inicio!.toLocal().toString().substring(0, 10)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Elegir'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fin == null
                          ? 'Fin: —'
                          : 'Fin: ${_fin!.toLocal().toString().substring(0, 10)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Elegir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lugar,
                decoration:
                    const InputDecoration(labelText: 'Lugar general'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aforo,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Aforo general'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _estado,
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(value: 'borrador', child: Text('Borrador')),
                  DropdownMenuItem(
                      value: 'finalizado', child: Text('Finalizado')),
                ],
                onChanged: (v) => setState(() => _estado = v ?? 'activo'),
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              SwitchListTile(
                value: _reqInscSesion,
                onChanged: (v) => setState(() => _reqInscSesion = v),
                title: const Text('Requiere inscripción por sesión'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Si es edición, mostrar botón para agregar ponencias
        if (widget.existing != null) ...[
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => SessionFormDialog(
                  existing: null,
                  preselectedEventId: widget.existing!.id,
                  preselectedEventName: widget.existing!.nombre,
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Agregar ponencia'),
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
        // Si es nuevo evento, opción de guardar y agregar ponencias
        if (widget.existing == null) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _saveAndAddSession,
            icon: const Icon(Icons.add),
            label: const Text('Guardar y agregar ponencia'),
          ),
        ],
      ],
    );
  }
}
