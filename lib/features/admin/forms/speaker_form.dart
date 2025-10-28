// lib/features/admin/forms/speaker_form.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/admin_speaker_model.dart';
import '../services/admin_speaker_service.dart';
import '../../../common/ui.dart';

class SpeakerFormDialog extends StatefulWidget {
  final AdminSpeakerModel? existing;
  const SpeakerFormDialog({super.key, this.existing});

  @override
  State<SpeakerFormDialog> createState() => _SpeakerFormDialogState();
}

class _SpeakerFormDialogState extends State<SpeakerFormDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _institucion = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();
  final _temas = TextEditingController();

  final _svc = AdminSpeakerService();

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s != null) {
      _nombre.text = s.nombre;
      _institucion.text = s.institucion;
       _email.text = s.emailCertificado;
      _bio.text = s.bio;
      _temas.text = s.temas.join(', ');
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _institucion.dispose();
    _email.dispose();
    _bio.dispose();
    _temas.dispose();
    super.dispose();
  }

  String _formatFullDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year a las $hour:$minute';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final temas = _temas.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final model = AdminSpeakerModel(
      id: widget.existing?.id ?? '',
      nombre: _nombre.text.trim(),
      institucion: _institucion.text.trim(),
      emailCertificado: _email.text.trim(),
      bio: _bio.text.trim(),
      temas: temas,
      // Si editas, preserva createdAt; si es nuevo, el service pondrá serverTimestamp
      createdAt: widget.existing?.createdAt,
    );

    try {
      await _svc.upsert(model);
      if (mounted) Navigator.pop(context);
      if (mounted) Ui.showSnack(context, 'Ponente guardado');
    } catch (e) {
      if (mounted) Ui.showSnack(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Nuevo ponente' : 'Editar ponente'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEditing && widget.existing!.createdAt != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrado: ${_formatFullDate(widget.existing!.createdAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (widget.existing!.updatedAt != null && 
                                widget.existing!.updatedAt != widget.existing!.createdAt)
                              Text(
                                'Última actualización: ${_formatFullDate(widget.existing!.updatedAt!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _institucion,
                decoration:
                    const InputDecoration(labelText: 'Institución (opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                    labelText: 'Contacto (email/teléfono, opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Bio (opcional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _temas,
                decoration: const InputDecoration(
                    labelText: 'Temas (separados por coma, opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
