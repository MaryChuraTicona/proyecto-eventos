// lib/features/admin/forms/user_form.dart
import 'package:flutter/material.dart';
import '../../../services/admin_functions_service.dart';

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key});
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  String _role = 'ponente';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear usuario (admin)'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obligatorio' : null,
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'ponente', child: Text('Ponente')),
                DropdownMenuItem(value: 'docente', child: Text('Docente')),
                DropdownMenuItem(value: 'encargado', child: Text('Encargado')),
                // Si quieres permitir admin, agrega:
                // DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'ponente'),
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(
                  labelText: 'Password temporal (opcional)'),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _busy = true);
                  try {
                    final res = await AdminFunctionsService().createUser(
                      email: _email.text.trim(),
                      displayName: _name.text.trim().isEmpty
                          ? null
                          : _name.text.trim(),
                      role: _role,
                      tempPassword: _password.text.trim().isEmpty
                          ? null
                          : _password.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Creado: ${res["email"]} • pass: ${res["tempPassword"] ?? "(defínelo en correo de bienvenida)"}'),
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
