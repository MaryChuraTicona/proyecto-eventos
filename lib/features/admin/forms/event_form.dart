// lib/features/admin/forms/event_form.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/admin_event_model.dart';
import '../models/admin_session_model.dart';
import '../services/admin_event_service.dart';
import '../services/admin_session_service.dart';
import '../../../common/ui.dart';
import '../../../core/constants.dart';
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
  List<AdminEventOrganizer> _organizers = const [];
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
      _inicio = e.fechaInicio; // DateTime directo
      _fin = e.fechaFin;       // DateTime directo
      _organizers = List<AdminEventOrganizer>.from(e.organizers);
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
      fechaInicio: _inicio,
      fechaFin: _fin,
      dias: const [],
      lugarGeneral: _lugar.text.trim(),
      modalidadGeneral: 'Mixta',
      aforoGeneral: int.tryParse(_aforo.text) ?? 0,
      estado: _estado,
      requiereInscripcionPorSesion: _reqInscSesion,
      createdBy: currentUid,
      createdAt: widget.existing?.createdAt,
      organizers: List<AdminEventOrganizer>.from(_organizers),
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
      id: '', // nuevo
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
      organizers: List<AdminEventOrganizer>.from(_organizers),
    );

    try {
      final eventId = await _svc.upsertAndGetId(model);
      if (!mounted) return;

      Navigator.pop(context);
      Ui.showSnack(context, 'Evento guardado. Ahora agrega ponencias');

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
                  DropdownMenuItem(value: 'Software Libre', child: Text('Software Libre')),
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
                decoration: const InputDecoration(labelText: 'Lugar general'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aforo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Aforo general'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _estado,
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(value: 'borrador', child: Text('Borrador')),
                  DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                ],
                onChanged: (v) => setState(() => _estado = v ?? 'activo'),
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Organizadores',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 6),
              _OrganizerChips(
                organizers: _organizers,
                onAdd: _openOrganizerPicker,
                onRemove: (org) {
                  setState(() {
                    _organizers =
                        _organizers.where((e) => e.uid != org.uid).toList();
                  });
                },
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
        const Spacer(), // (opcional) si no te gusta cómo se ve en AlertDialog, quítalo
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
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

  Future<void> _openOrganizerPicker() async {
    final selected = await showModalBottomSheet<List<AdminEventOrganizer>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrganizerPickerSheet(
        initialSelection: _organizers,
      ),
    );
    if (selected != null) {
      setState(() {
        final unique = <String, AdminEventOrganizer>{
          for (final org in selected) org.uid: org,
        };
        _organizers = unique.values.toList();
      });
    }
  }
}

class _OrganizerChips extends StatelessWidget {
  final List<AdminEventOrganizer> organizers;
  final VoidCallback onAdd;
  final ValueChanged<AdminEventOrganizer> onRemove;

  const _OrganizerChips({
    required this.organizers,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final org in organizers)
          InputChip(
            avatar: const CircleAvatar(child: Icon(Icons.badge, size: 16)),
            label: Text(org.displayName.isNotEmpty ? org.displayName : org.email),
            onDeleted: () => onRemove(org),
          ),
        ActionChip(
          avatar: Icon(Icons.add, color: cs.onPrimaryContainer),
          label: const Text('Agregar organizador'),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _OrganizerPickerSheet extends StatefulWidget {
  final List<AdminEventOrganizer> initialSelection;
  const _OrganizerPickerSheet({required this.initialSelection});

  @override
  State<_OrganizerPickerSheet> createState() => _OrganizerPickerSheetState();
}

class _OrganizerPickerSheetState extends State<_OrganizerPickerSheet> {
  final _search = TextEditingController();
  late Map<String, AdminEventOrganizer> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final org in widget.initialSelection) org.uid: org,
    };
    _search.addListener(() {
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom;
    final availableHeight = media.size.height * 0.75;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
        child: SizedBox(
          height: availableHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_accounts),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Selecciona organizadores',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre, correo o ciclo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .where('active', isEqualTo: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? const [];
                    final candidates = <AdminEventOrganizer>[];

                    for (final doc in docs) {
                      final data = doc.data();
                      final role = (data['role'] ?? data['rol'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (role.isEmpty) continue;
                      if (role != UserRoles.student && role != UserRoles.organizer) {
                        continue;
                      }
                      final email = (data['email'] ?? '').toString();
                      final displayName =
                          (data['displayName'] ?? data['nombre'] ?? '').toString();
                      final ciclo = (data['ciclo'] ??
                              data['cicloAcademico'] ??
                              (data['answers'] is Map
                                  ? ((data['answers'] as Map)['ciclo'] ?? '')
                                  : ''))
                          .toString();
                      final phone = (data['phone'] ?? data['telefono'] ?? '').toString();

                      final hayStack =
                          '$displayName $email ${ciclo.toUpperCase()}'.toLowerCase();
                      if (_query.isNotEmpty && !hayStack.contains(_query)) continue;

                      candidates.add(
                        AdminEventOrganizer(
                          uid: doc.id,
                          email: email,
                          displayName: displayName.isEmpty ? email : displayName,
                          phone: phone.isEmpty ? null : phone,
                          ciclo: ciclo.isEmpty ? null : ciclo,
                        ),
                      );
                    }

                    if (candidates.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron estudiantes para tu búsqueda.'),
                      );
                    }

                    candidates.sort((a, b) =>
                        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

                    return ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        final selected = _selected.containsKey(candidate.uid);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              selected ? Icons.check : Icons.person_outline,
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(candidate.displayName),
                          subtitle: Text([
                            candidate.email,
                            if (candidate.ciclo != null) 'Ciclo ${candidate.ciclo}',
                          ].join(' • ')),
                          trailing: Switch(
                            value: selected,
                            onChanged: (_) => _toggle(candidate),
                          ),
                          onTap: () => _toggle(candidate),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addByEmail,
                      icon: const Icon(Icons.alternate_email),
                      label: const Text('Agregar por correo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                                context,
                                _selected.values.toList(),
                              ),
                      icon: const Icon(Icons.check),
                      label: Text('Usar ${_selected.length}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(AdminEventOrganizer candidate) {
    setState(() {
      if (_selected.containsKey(candidate.uid)) {
        _selected.remove(candidate.uid);
      } else {
        _selected[candidate.uid] = candidate;
      }
    });
  }

  Future<void> _addByEmail() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar organizador por correo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo institucional',
            hintText: 'usuario@virtual.upt.pe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || email.isEmpty) return;

    final normalized = email.toLowerCase();
    try {
      final query = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se encontró el correo $normalized')),
        );
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final role = (data['role'] ?? data['rol'] ?? '').toString().toLowerCase();
      if (role != UserRoles.student && role != UserRoles.organizer) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El usuario no es estudiante ni organizador')),
        );
        return;
      }

      final org = AdminEventOrganizer(
        uid: doc.id,
        email: normalized,
        displayName: (data['displayName'] ?? data['nombre'] ?? normalized).toString(),
        phone: (data['phone'] ?? data['telefono'])?.toString(),
        ciclo: (data['ciclo'] ?? data['cicloAcademico'])?.toString(),
      );

      setState(() {
        _selected[org.uid] = org;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${org.displayName} añadido')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar correo: $e')),
      );
    }
  }
}
