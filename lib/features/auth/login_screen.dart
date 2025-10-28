// lib/features/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Usa tu router real
import '../../app/router_by_rol.dart';

bool _esInstitucional(String email) {
  final e = email.trim().toLowerCase();
  return e.endsWith('@virtual.upt.pe'); // <- SOLO institucional si es @virtual.upt.pe
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _modoInstitucional = true;

  @override
  void dispose() {
    _emailCtrl..clear()..dispose();
    _passCtrl..clear()..dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  /// Crea/actualiza doc en `usuarios/{uid}` y lo marca activo
  Future<bool> _ensureUserDocAndGuard(User u) async {
    try {
      final uid   = u.uid;
      final mail  = (u.email ?? '').toLowerCase();
      final modo  = _esInstitucional(mail) ? 'institucional' : 'externo';
      final domain = mail.split('@').length == 2 ? mail.split('@')[1] : '';
      final ref = FirebaseFirestore.instance.collection('usuarios').doc(uid);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) {
          txn.set(ref, {
            'email'          : mail,
            'displayName'    : u.displayName ?? '',
            'photoURL'       : u.photoURL ?? '',
            'domain'         : domain,
            'modo'           : modo,
            'role'           : 'estudiante',
            'rol'            : 'estudiante',
            'active'         : true,
            'estado'         : 'activo',
            'isInstitutional': _esInstitucional(mail),
            'createdAt'      : FieldValue.serverTimestamp(),
            'updatedAt'      : FieldValue.serverTimestamp(),
          });
        } else {
          final d = (snap.data() as Map<String, dynamic>? ?? {});
          final patch = <String, dynamic>{};

          if (d['role'] == null && d['rol'] == null) {
            patch['role'] = 'estudiante';
            patch['rol']  = 'estudiante';
          } else {
            if (d['role'] == null && d['rol'] != null) patch['role'] = d['rol'];
            if (d['rol']  == null && d['role'] != null) patch['rol']  = d['role'];
          }
          if ((d['active'] ?? false) != true) patch['active'] = true;
          if ((d['estado'] ?? '').toString().toLowerCase() != 'activo') patch['estado'] = 'activo';

          if (patch.isNotEmpty) {
            patch['updatedAt'] = FieldValue.serverTimestamp();
            txn.set(ref, patch, SetOptions(merge: true));
          } else {
            txn.update(ref, {'updatedAt': FieldValue.serverTimestamp()});
          }
        }
      });

      return true;
    } catch (e, st) {
      debugPrint('_ensureUserDocAndGuard error: $e\n$st');
      _snack('No se pudo preparar tu perfil: ${e is FirebaseException ? e.code : e}');
      return false;
    }
  }

  // ------------------ LOGIN EMAIL ------------------
  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Si el usuario intenta entrar como "externo" con un correo institucional, bloquear.
      if (!_modoInstitucional && email.endsWith('@virtual.upt.pe')) {
        _snack('Los correos @virtual.upt.pe solo inician con Google.');
        return;
      }

      final pass  = _passCtrl.text;

      if (_modoInstitucional) {
        _snack('Para cuentas institucionales usa “Iniciar sesión con Google”.');
        await _googleSignIn();
        return;
      }

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      // El AuthWrapper detectará el cambio automáticamente
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await _showRegisterDialog(_emailCtrl.text.trim());
        return;
      }
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
        _snack('Correo o contraseña incorrectos.');
      } else {
        _snack('Auth: ${e.code}');
      }
    } catch (e, st) {
      final msg = (e is AsyncError) ? '${e.error}' : e.toString();
      debugPrint('loginEmail error: $msg\n$st');
      _snack('Error inesperado: $msg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------ REGISTRO EMAIL ------------------
  Future<void> _registerEmail(String email, String pass) async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
        'email'          : email.toLowerCase(),
        'displayName'    : cred.user!.displayName ?? '',
        'photoURL'       : cred.user!.photoURL ?? '',
        'domain'         : email.split('@').last,
        'modo'           : 'externo',
        'role'           : 'estudiante',
        'rol'            : 'estudiante',
        'active'         : true,
        'estado'         : 'activo',
        'isInstitutional': false,
        'createdAt'      : FieldValue.serverTimestamp(),
        'updatedAt'      : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // El AuthWrapper detectará el cambio automáticamente
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'email-already-in-use'
          ? 'Ese correo ya está registrado.'
          : 'Auth: ${e.code}');
    } catch (e, st) {
      final msg = (e is AsyncError) ? '${e.error}' : e.toString();
      debugPrint('registerEmail error: $msg\n$st');
      _snack('Error inesperado: $msg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------ RESET ------------------
  Future<void> _reset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Ingresa tu correo para recuperar la contraseña.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Enlace de recuperación enviado a $email');
    } on FirebaseAuthException catch (e) {
      _snack('Auth: ${e.code}');
    }
  }

  // ------------------ GOOGLE SIGN-IN ------------------
  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final provider = GoogleAuthProvider();

      if (kIsWeb) {
        try {
          final cred = await FirebaseAuth.instance.signInWithPopup(provider);
          final email = cred.user?.email?.toLowerCase() ?? '';
          if (_modoInstitucional && !_esInstitucional(email)) {
            await FirebaseAuth.instance.signOut();
            _snack('Solo correos institucionales @virtual.upt.pe');
            return;
          }
          await _ensureUserDocAndGuard(cred.user!);
          // El AuthWrapper detectará el cambio automáticamente
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'unauthorized-domain') {
            _snack('El navegador bloqueó el popup o el dominio no está autorizado. Probando redirección…');
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return;
          } else {
            _snack('Google: ${e.code}');
          }
        }
      } else {
        final cred = await FirebaseAuth.instance.signInWithProvider(provider);
        final email = cred.user?.email?.toLowerCase() ?? '';
        if (_modoInstitucional && !_esInstitucional(email)) {
          await FirebaseAuth.instance.signOut();
          _snack('Solo correos institucionales @virtual.upt.pe');
          return;
        }
        await _ensureUserDocAndGuard(cred.user!);
        // El AuthWrapper detectará el cambio automáticamente
      }
    } on FirebaseAuthException catch (e) {
      _snack('Google: ${e.code}');
    } catch (e, st) {
      final msg = (e is AsyncError) ? '${e.error}' : e.toString();
      debugPrint('GoogleSignIn error: $msg\n$st');
      _snack('Error inesperado: $msg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg_login.jpg'),
                fit: BoxFit.cover,
                opacity: 0.32,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildCard(context, cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ESCUELA PROFESIONAL DE INGENIERÍA DE SISTEMAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 14),
            CircleAvatar(
              radius: 40,
              backgroundColor: cs.primary.withOpacity(.1),
              child: Icon(Icons.school_rounded, color: cs.primary, size: 44),
            ),
            const SizedBox(height: 12),
            Text(
              'Acceso para docentes, estudiantes y ponentes',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'EVENTOS EPIS – UPT',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Institucional')),
                ButtonSegment(value: false, label: Text('Externo')),
              ],
              selected: {_modoInstitucional},
              onSelectionChanged: (s) => setState(() => _modoInstitucional = s.first),
            ),
            const SizedBox(height: 16),

            _GoogleButton(onPressed: _loading ? null : _googleSignIn),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: Divider(color: cs.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('o con correo', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                Expanded(child: Divider(color: cs.outlineVariant)),
              ],
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: _modoInstitucional
                          ? 'usuario@virtual.upt.pe'
                          : 'correo@ejemplo.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      final email = (v ?? '').trim();
                      final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (email.isEmpty) return 'Ingresa tu correo';
                      if (!re.hasMatch(email)) return 'Correo inválido';
                      if (_modoInstitucional && !_esInstitucional(email)) {
                        return 'Debe ser @virtual.upt.pe';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _loading ? null : _reset,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _loading ? null : () => _showRegisterDialog(_emailCtrl.text.trim()),
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _loginEmail,
                      child: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),

            Text.rich(
              TextSpan(
                text: 'Soporte: ',
                style: TextStyle(color: cs.onSurfaceVariant),
                children: const [
                  TextSpan(
                    text: 'eventos-epis@upt.pe',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterDialog(String hintEmail) async {
    final emailCtrl = TextEditingController(text: hintEmail);
    final pass1Ctrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear cuenta (externo)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) {
                  final email = (v ?? '').trim();
                  final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (email.isEmpty) return 'Ingresa tu correo';
                  if (!re.hasMatch(email)) return 'Correo inválido';
                  if (_esInstitucional(email)) return 'Para institucional usa Google';
                  return null;
                },
              ),
              TextFormField(
                controller: pass1Ctrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña (min 6)'),
                validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6' : null,
              ),
              TextFormField(
                controller: pass2Ctrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repite contraseña'),
                validator: (v) => v != pass1Ctrl.text ? 'No coincide' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              await _registerEmail(emailCtrl.text.trim(), pass1Ctrl.text);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget googleIcon() => Image.asset(
          'assets/images/google_logo.png',
          width: 18,
          height: 18,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: 10,
            backgroundColor: Colors.white,
            child: Text('G', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 12)),
          ),
        );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: googleIcon(),
        label: const Text('Iniciar sesión con Google'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: cs.outlineVariant),
          foregroundColor: cs.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
