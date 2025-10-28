import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/registration_service.dart';

class RegisterButton extends StatefulWidget {
  final String eventId;
  final String sessionId; // ponencia/sesión específica

  const RegisterButton({
    super.key,
    required this.eventId,
    required this.sessionId,
  });

  @override
  State<RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<RegisterButton> {
  final _auth = FirebaseAuth.instance;
  final _svc = RegistrationService();

  bool _loading = false;

  Future<void> _doRegister() async {
    final u = _auth.currentUser;
    if (u == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para inscribirte.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _svc.register(u.uid, widget.eventId, widget.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Inscripción registrada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al registrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<void> _doUnregister() async {
    final u = _auth.currentUser;
    if (u == null) return;

    setState(() => _loading = true);
    try {
      await _svc.unregister(u.uid, widget.eventId, widget.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Inscripción cancelada'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cancelar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    
    // Si no hay usuario, mostrar botón deshabilitado
    if (uid == null) {
      return FilledButton(
        onPressed: null,
        child: const Text('Inicia sesión'),
      );
    }
    
    // Usar StreamBuilder para actualización en tiempo real
    return StreamBuilder<bool>(
      stream: _svc.watchRegistrationStatus(uid, widget.eventId, widget.sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FilledButton(
            onPressed: null,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        final isRegistered = snapshot.data ?? false;
        
        return FilledButton(
          onPressed: _loading 
              ? null 
              : (isRegistered ? _doUnregister : _doRegister),
          style: isRegistered 
              ? FilledButton.styleFrom(backgroundColor: Colors.green)
              : null,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isRegistered ? Icons.check_circle : Icons.add_circle),
                    const SizedBox(width: 8),
                    Text(isRegistered ? 'Inscrito' : 'Inscribirme'),
                  ],
                ),
        );
      },
    );
  }
}
