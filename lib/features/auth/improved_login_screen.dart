// lib/features/auth/improved_login_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/error_handler.dart';
import 'auth_controller.dart';

/// Pantalla de login mejorada con AuthController
/// Mejoras:
/// - Separación de lógica en AuthController
/// - Uso de constantes centralizadas
/// - Manejo de errores mejorado
/// - Logging estructurado
/// - Código más limpio y mantenible
class ImprovedLoginScreen extends StatefulWidget {
  const ImprovedLoginScreen({super.key});

  @override
  State<ImprovedLoginScreen> createState() => _ImprovedLoginScreenState();
}

class _ImprovedLoginScreenState extends State<ImprovedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authController = AuthController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _institutionalMode = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: UIConstants.snackbarDuration,
      ),
    );
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;

    try {
      // Si es institucional, forzamos Google
      if (_institutionalMode || _authController.isInstitutionalEmail(email)) {
        _showSnackbar(ErrorMessages.institutionalOnly);
        await _handleGoogleSignIn();
        return;
      }

      await _authController.signInWithEmailPassword(
        email: email,
        password: password,
      );
      // Navega el AuthWrapper automáticamente
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await _showRegisterDialog(email);
      } else {
        _showSnackbar(ErrorHandler.handleAuthError(e));
      }
    } on String catch (message) {
      _showSnackbar(message);
    } catch (e, st) {
      _showSnackbar(ErrorHandler.logAndHandle(e, st));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegistration({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    setState(() => _isLoading = true);
    try {
      await _authController.registerWithEmailPassword(
        email: email,
        password: password,
        profileData: profileData,
      );
      _showSnackbar(SuccessMessages.registerSuccess);
      // AuthWrapper navega solo
    } on String catch (message) {
      _showSnackbar(message);
    } catch (e, st) {
      _showSnackbar(ErrorHandler.logAndHandle(e, st));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnackbar('Ingresa tu correo para recuperar la contraseña.');
      return;
    }
    try {
      await _authController.sendPasswordResetEmail(email);
      _showSnackbar(SuccessMessages.passwordResetSent);
    } catch (e, st) {
      _showSnackbar(ErrorHandler.logAndHandle(e, st));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authController.signInWithGoogle(institutionalMode: _institutionalMode);
      // AuthWrapper navega solo
    } on String catch (message) {
      if (message != 'redirect') {
        _showSnackbar(message);
      }
    } catch (e, st) {
      _showSnackbar(ErrorHandler.logAndHandle(e, st));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg_login.jpg'),
                fit: BoxFit.cover,
                opacity: 0.32,
              ),
            ),
          ),
          // Contenido
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: UIConstants.maxContentWidth,
                ),
                child: _buildLoginCard(cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(ColorScheme cs) {
    return Card(
      elevation: UIConstants.cardElevation,
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
            _buildHeader(cs),
            const SizedBox(height: 16),
            _buildModeSelector(),
            const SizedBox(height: 16),
            _buildGoogleButton(),
            const SizedBox(height: 12),
            _buildDivider(cs),
            const SizedBox(height: 12),
            _buildEmailForm(cs),
            const SizedBox(height: 18),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 8),
            _buildFooter(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
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
      ],
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Institucional')),
        ButtonSegment(value: false, label: Text('Externo')),
      ],
      selected: {_institutionalMode},
      onSelectionChanged: (selection) {
        setState(() => _institutionalMode = selection.first);
      },
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: Image.asset(
          'assets/images/google_logo.png',
          width: 18,
          height: 18,
          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
        ),
        label: const Text('Iniciar sesión con Google'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'o con correo',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }

  Widget _buildEmailForm(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: _institutionalMode
                  ? 'usuario@virtual.upt.pe'
                  : 'correo@ejemplo.com',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: _isLoading ? null : _handlePasswordReset,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                onPressed: _isLoading
                    ? null
                    : () => _showRegisterDialog(_emailCtrl.text.trim()),
                label: const Text('Crear cuenta'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleEmailLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Iniciar sesión'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    return Text.rich(
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
    );
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Ingresa tu correo';
    }
    if (!ValidationConstants.emailRegex.hasMatch(email)) {
      return ErrorMessages.invalidEmail;
    }
    if (_institutionalMode && !_authController.isInstitutionalEmail(email)) {
      return 'Debe ser ${InstitutionalDomains.upt}';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < ValidationConstants.minPasswordLength) {
      return ErrorMessages.weakPassword;
    }
    return null;
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

    String? submittedEmail;
    String? submittedPassword;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;

        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          'Crear cuenta (externo)',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa tu correo personal para registrarte una sola vez. '
                          'Si tienes un correo ${InstitutionalDomains.upt}, ingresa con Google.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Correo
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Correo'),
                          validator: (value) {
                            final email = (value ?? '').trim().toLowerCase();
                            if (email.isEmpty) return 'Ingresa tu correo';
                            if (!ValidationConstants.emailRegex.hasMatch(email)) {
                              return ErrorMessages.invalidEmail;
                            }
                            if (_authController.isInstitutionalEmail(email)) {
                              return 'Usa Google con tu correo institucional';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Nombres
                        TextFormField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Nombres'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Ingresa tus nombres' : null,
                        ),
                        const SizedBox(height: 12),

                        // Apellidos
                        TextFormField(
                          controller: lastNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Apellidos'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Ingresa tus apellidos'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Celular
                        TextFormField(
                          controller: phoneCtrl,
                          textInputAction: TextInputAction.next,
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

                        // Documento / Código
                        TextFormField(
                          controller: docCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Documento / Código (opcional)',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contraseña
                        TextFormField(
                          controller: pass1Ctrl,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText:
                                'Contraseña (min ${ValidationConstants.minPasswordLength})',
                          ),
                          validator: (value) {
                            if ((value ?? '').length <
                                ValidationConstants.minPasswordLength) {
                              return ErrorMessages.weakPassword;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Repite contraseña
                        TextFormField(
                          controller: pass2Ctrl,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(labelText: 'Repite contraseña'),
                          validator: (value) {
                            if (value != pass1Ctrl.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(false);
                              },
                              child: const Text('Cancelar'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () {
                                if (_isLoading || !formKey.currentState!.validate()) {
                                  return;
                                }
                                FocusScope.of(sheetContext).unfocus();
                                submittedEmail = emailCtrl.text.trim();
                                submittedPassword = pass1Ctrl.text;
                                Navigator.of(sheetContext).pop(true);
                              },
                              child: const Text('Crear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: const Text('Tengo un correo institucional'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    emailCtrl.dispose();
    pass1Ctrl.dispose();
    pass2Ctrl.dispose();
    nameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    docCtrl.dispose();

    if (created == true && submittedEmail != null && submittedPassword != null) {
      await _handleRegistration(
        email: submittedEmail!,
        password: submittedPassword!,
        profileData: {
          'nombres': nameCtrl.text.trim(),
          'apellidos': lastNameCtrl.text.trim(),
          'telefono': phoneCtrl.text.trim(),
          'documento': docCtrl.text.trim(),
          'rol': 'externo',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    }
  }
}
