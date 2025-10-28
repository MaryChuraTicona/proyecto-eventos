// lib/features/auth/improved_login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants.dart';
import '../../core/error_handler.dart';
import 'auth_controller.dart';

/// Pantalla de login mejorada con AuthController
/// 
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
      // Validar que emails institucionales usen Google
      if (_institutionalMode || _authController.isInstitutionalEmail(email)) {
        _showSnackbar(ErrorMessages.institutionalOnly);
        await _handleGoogleSignIn();
        return;
      }

      await _authController.signInWithEmailPassword(
        email: email,
        password: password,
      );
      
      // El AuthWrapper manejará la navegación automáticamente
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

  Future<void> _handleRegistration(String email, String password) async {
    setState(() => _isLoading = true);
    
    try {
      await _authController.registerWithEmailPassword(
        email: email,
        password: password,
      );
      
      _showSnackbar(SuccessMessages.registerSuccess);
      // El AuthWrapper manejará la navegación automáticamente
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
      await _authController.signInWithGoogle(
        institutionalMode: _institutionalMode,
      );
      
      // El AuthWrapper manejará la navegación automáticamente
    } on String catch (message) {
      if (message != 'redirect') {
        _showSnackbar(message);
      }
      // Si es 'redirect', el flujo continúa en segundo plano
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
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _showRegisterDialog(_emailCtrl.text.trim()),
                child: const Text('Crear cuenta'),
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
                  if (email.isEmpty) return 'Ingresa tu correo';
                  if (!ValidationConstants.emailRegex.hasMatch(email)) {
                    return ErrorMessages.invalidEmail;
                  }
                  if (_authController.isInstitutionalEmail(email)) {
                    return 'Para institucional usa Google';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: pass1Ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña (mín 6 caracteres)',
                ),
                validator: (v) => (v ?? '').length <
                        ValidationConstants.minPasswordLength
                    ? ErrorMessages.weakPassword
                    : null,
              ),
              TextFormField(
                controller: pass2Ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repite contraseña',
                ),
                validator: (v) => v != pass1Ctrl.text
                    ? 'Las contraseñas no coinciden'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              await _handleRegistration(
                emailCtrl.text.trim(),
                pass1Ctrl.text,
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

