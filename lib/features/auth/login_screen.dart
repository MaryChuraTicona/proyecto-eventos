// lib/features/auth/login_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future.microtask(_consumeRedirectResult);
    }
  }


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

   Future<void> _consumeRedirectResult() async {
    if (!kIsWeb) return;
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      final user = result.user;
      if (user == null) return;

      if (mounted) setState(() => _loading = true);
      final email = user.email?.toLowerCase() ?? '';
      if (!_esInstitucional(email)) {
        await FirebaseAuth.instance.signOut();
        _snack('Solo correos institucionales @virtual.upt.pe');
        return;
      }

      await _ensureUserDocAndGuard(user);
    } on FirebaseAuthException catch (e) {
      _snack('Google: ${e.code}');
    } catch (e, st) {
      final msg = (e is AsyncError) ? '${e.error}' : e.toString();
      debugPrint('consumeRedirectResult error: $msg\n$st');
      _snack('Error inesperado: $msg');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
     var redirected = false;
    try {
      final provider = GoogleAuthProvider();

      if (kIsWeb) {
        
        redirected = true;
        await FirebaseAuth.instance.signInWithRedirect(provider);
        return;
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
       if (!redirected && mounted) setState(() => _loading = false);
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
                final isWide = constraints.maxWidth >= 720;
                final isCompact = constraints.maxWidth < 520;
                final horizontalPadding = isWide
                    ? 56.0
                    : (isCompact ? 20.0 : 32.0);
                final topPadding = isWide
                    ? 48.0
                    : (constraints.maxHeight < 700 ? 24.0 : 32.0);
                final bottomPadding = isWide ? 48.0 : 32.0;
                final maxCardWidth = isWide
                    ? 560.0
                    : (isCompact ? 420.0 : 480.0);
                return Align(
                  alignment: isWide ? Alignment.center : Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                       topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: ConstrainedBox(
                       constraints: BoxConstraints(maxWidth: maxCardWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                         _buildWelcomeHeader(cs, compact: isCompact),
                          SizedBox(height: isCompact ? 16 : 18),
                          _buildCard(context, cs, compact: isCompact),
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

   Widget _buildCard(BuildContext context, ColorScheme cs, {required bool compact}) {
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
               padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 26,
                  compact ? 24 : 30,
                  compact ? 20 : 26,
                  compact ? 18 : 22,
                ),
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
                        height: compact ? 52 : 60,
                      child: Image.asset(
                        'assets/images/logo_horizontal.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.event_available_rounded,
                          color: cs.onPrimary,
                          size: compact ? 48 : 60,
                        ),
                      ),
                    ),
                     SizedBox(height: compact ? 14 : 18),
                    Text(
                      'EVENTOS EPIS – UPT',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                             fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                    ),
                       SizedBox(height: compact ? 4 : 6),
                    Text(
                      'Gestión integral de eventos académicos, talleres y ponencias.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimary.withOpacity(0.86),
                          fontSize: compact ? 13 : null,
                          ),
                    ),
                     SizedBox(height: compact ? 10 : 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                     spacing: compact ? 8 : 12,
                      runSpacing: compact ? 8 : 10,
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
                 padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 26,
                  compact ? 22 : 26,
                  compact ? 20 : 26,
                  compact ? 8 : 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.standard,
                        padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 16,
                          ),
                        ),
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
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
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
                             textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!_loading) _loginEmail();
                            },
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
                          compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                      ),
                                      onPressed: _loading ? null : _reset,
                                      child: const Text('¿Olvidaste tu contraseña?'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () => _showRegisterDialog(_emailCtrl.text.trim()),
                                      child: const Text('Crear cuenta'),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    TextButton(
                                      onPressed: _loading ? null : _reset,
                                      child: const Text('¿Olvidaste tu contraseña?'),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => _showRegisterDialog(_emailCtrl.text.trim()),
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
                    ),
                ],


                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 26,
                  compact ? 16 : 18,
                  compact ? 20 : 26,
                  compact ? 20 : 26,
                ),
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

  Widget _buildWelcomeHeader(ColorScheme cs, {required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 6,
          ),
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
         SizedBox(height: compact ? 10 : 14),
        Text(
          'Participa, organiza y gestiona los eventos académicos de la EPIS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface,
             fontSize: compact ? 16 : 18,
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
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final isCompact = media.size.width < 520;
        final rawMaxWidth = isCompact ? media.size.width - 48 : 420.0;
        final constrainedWidth = rawMaxWidth < 280
            ? 280.0
            : (rawMaxWidth > 520.0 ? 520.0 : rawMaxWidth);

        return AlertDialog(
          title: const Text('Crear cuenta (externo)'),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 24,
            vertical: isCompact ? 16 : 24,
          ),
          scrollable: true,
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constrainedWidth),
            child: AutofillGroup(
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
                        if (email.isEmpty) return 'Ingresa tu correo';
                        if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
                          return 'Correo inválido';
                        }
                        final parts = email.split('@');
                        if (parts.length != 2 || !parts[1].contains('.')) {
                          return 'Correo inválido';
                        }
                        if (_esInstitucional(email)) return 'Para institucional usa Google';
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],


    ),


                     const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombres'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tus nombres' : null,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],

                    ),
                  
                  const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tus apellidos' : null,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Celular de contacto',
                        hintText: '9XXXXXXXX',
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        final isNumeric = value.runes.every((r) => r >= 48 && r <= 57);
                        if (!isNumeric || value.length != 9 || !value.startsWith('9')) {
                          return 'Debe ser un número peruano válido';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: docCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Documento de identidad (opcional)',
                        hintText: 'DNI o CE',
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        final isNumeric = value.runes.every((r) => r >= 48 && r <= 57);
                        if (!isNumeric) return 'Usa solo números';
                        final length = value.length;
                        final isDni = length == 8;
                        final isCe = length >= 9 && length <= 12;
                        if (!isDni && !isCe) {
                          return 'Ingresa un DNI (8) o CE válido';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pass1Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña (mínimo 6 caracteres)'),
                      validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pass2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                      validator: (v) => v != pass1Ctrl.text ? 'Las contraseñas no coinciden' : null,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (formKey.currentState!.validate()) {
                          Navigator.of(dialogContext).pop();
                          unawaited(_registerEmail(
                            emailCtrl.text.trim(),
                            pass1Ctrl.text,
                            {
                              'nombres': nameCtrl.text.trim(),
                              'apellidos': lastNameCtrl.text.trim(),
                              'telefono': phoneCtrl.text.trim(),
                              'documento': docCtrl.text.trim(),
                            },
                          ));
                        }
                      },
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ],
                ),

              ),
            
            ),
          ),
       
 actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop();
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
        );
      },


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
