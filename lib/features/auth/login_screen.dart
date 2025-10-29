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
  Future<void> _registerEmail(
    String email,
    String pass,
    Map<String, String> profile,
  ) async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
       final nombres = (profile['nombres'] ?? '').trim();
      final apellidos = (profile['apellidos'] ?? '').trim();
      final telefono = (profile['telefono'] ?? '').trim();
      final documento = (profile['documento'] ?? '').trim();
      final displayName = [nombres, apellidos]
          .where((s) => s.isNotEmpty)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (displayName.isNotEmpty) {
        await cred.user!.updateDisplayName(displayName);
      }
      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
        'email'          : email.toLowerCase(),
        'displayName'    : displayName.isNotEmpty
            ? displayName
            : (cred.user!.displayName ?? ''),
        'nombres'        : nombres,
        'apellidos'      : apellidos,
        if (telefono.isNotEmpty) 'telefono': telefono,
        if (documento.isNotEmpty) 'documento': documento,
        'photoURL'       : cred.user!.photoURL ?? '',
        'domain'         : email.split('@').last,
        'modo'           : 'externo',
        'role'           : 'estudiante',
        'rol'            : 'estudiante',
        'active'         : true,
        'estado'         : 'activo',
        'isInstitutional': false,
        'profileCompleted': true,
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
          const _LoginBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;
                final horizontalPadding = isWide ? 56.0 : 24.0;

                return Align(
                  alignment: isWide ? Alignment.center : Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isWide ? 48 : 32,
                      horizontalPadding,
                      32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 560 : 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWelcomeHeader(cs),
                          const SizedBox(height: 18),
                          _buildCard(context, cs),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, ColorScheme cs) {
    final borderRadius = BorderRadius.circular(28);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.12),
            cs.primary.withOpacity(0.04),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: borderRadius.subtract(const BorderRadius.all(Radius.circular(2))),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius.subtract(const BorderRadius.all(Radius.circular(2))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.95),
                      cs.primary.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 60,
                      child: Image.asset(
                        'assets/images/logo_horizontal.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.event_available_rounded,
                          color: cs.onPrimary,
                          size: 60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'EVENTOS EPIS – UPT',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gestión integral de eventos académicos, talleres y ponencias.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimary.withOpacity(0.86),
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: const [
                        _LoginPill(
                          icon: Icons.dashboard_customize_rounded,
                          label: 'Panel administrativo',
                        ),
                        _LoginPill(
                          icon: Icons.qr_code_rounded,
                          label: 'Control con códigos QR',
                        ),
                        _LoginPill(
                          icon: Icons.auto_graph_rounded,
                          label: 'Reportes y asistencia',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.standard,
                        backgroundColor: MaterialStateProperty.resolveWith(
                          (states) => states.contains(MaterialState.selected)
                              ? cs.primary.withOpacity(0.12)
                              : Colors.transparent,
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Institucional'),
                          icon: Icon(Icons.school_rounded),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Externo'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                      ],
                      selected: {_modoInstitucional},
                      onSelectionChanged: (s) => setState(() => _modoInstitucional = s.first),
                    ),
                    const SizedBox(height: 18),
                    _GoogleButton(onPressed: _loading ? null : _googleSignIn),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o continúa con correo',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
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
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _loginEmail,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(opacity: animation, child: child),
                                child: _loading
                                    ? const SizedBox(
                                        key: ValueKey('loader'),
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.2),
                                      )
                                    : const Text(
                                        'Iniciar sesión',
                                        key: ValueKey('label'),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Soporte',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'eventos-epis@upt.pe',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Solo los correos @virtual.upt.pe pueden acceder con Google. '
                      'Los participantes externos deben registrarse una sola vez.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Plataforma oficial de la Escuela Profesional de Ingeniería de Sistemas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Participa, organiza y gestiona los eventos académicos de la EPIS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _showRegisterDialog(String hintEmail) async {
    final emailCtrl = TextEditingController(text: hintEmail);
    final pass1Ctrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
     final nameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear cuenta (externo)'),
       
content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (v) {
                      final email = (v ?? '').trim();
                      final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (email.isEmpty) return 'Ingresa tu correo';
                      if (!re.hasMatch(email)) return 'Correo inválido';
                      if (_esInstitucional(email)) return 'Para institucional usa Google';
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombres'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tus nombres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Apellidos'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tus apellidos' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Celular de contacto',
                      helperText: 'Usado para coordinar recordatorios del evento',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Ingresa tu número de contacto';
                      if (value.length < 6) return 'Número muy corto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documento / Código (opcional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pass1Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña (min 6)'),
                    validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pass2Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Repite contraseña'),
                    validator: (v) => v != pass1Ctrl.text ? 'No coincide' : null,
                  ),
                ],
                ),



              ),
            
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
             await _registerEmail(
                emailCtrl.text.trim(),
                pass1Ctrl.text,
                {
                  'nombres': nameCtrl.text.trim(),
                  'apellidos': lastNameCtrl.text.trim(),
                  'telefono': phoneCtrl.text.trim(),
                  'documento': docCtrl.text.trim(),
                },
              );
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

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg_login.jpg'),
          fit: BoxFit.cover,
          opacity: 0.28,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.15),
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LoginPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.onPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onPrimary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
