// lib/features/student/faculty_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants.dart';
import '../../core/error_handler.dart';

/// Pantalla para que el estudiante seleccione su facultad en el primer login
class FacultySelectionScreen extends StatefulWidget {
  const FacultySelectionScreen({super.key});

  @override
  State<FacultySelectionScreen> createState() => _FacultySelectionScreenState();
}

class _FacultySelectionScreenState extends State<FacultySelectionScreen> {
  String? _selectedFaculty;
  bool _isLoading = false;

  Future<void> _saveFaculty() async {
    if (_selectedFaculty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona tu facultad'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'faculty': _selectedFaculty,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Facultad guardada: $_selectedFaculty');

      if (mounted) {
        // Recargar la aplicación para que el router detecte la facultad
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      AppLogger.error('Error al guardar facultad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Icono
                Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: cs.primary,
                ),
                const SizedBox(height: 24),

                // Título
                Text(
                  '¡Bienvenido a UPT Eventos!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtítulo
                Text(
                  'Para comenzar, selecciona tu facultad:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Lista de facultades
                ...Faculties.all.map((code) {
                  final name = Faculties.getFullName(code);
                  final isSelected = _selectedFaculty == code;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      elevation: isSelected ? 4 : 0,
                      color: isSelected ? cs.primaryContainer : cs.surface,
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _selectedFaculty = code;
                                });
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? cs.primary
                                  : cs.outline.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Icono de facultad
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primary.withOpacity(0.15)
                                      : cs.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getFacultyIcon(code),
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Texto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      code,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? cs.onPrimaryContainer
                                            : cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isSelected
                                            ? cs.onPrimaryContainer
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Check icon
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: cs.primary,
                                  size: 28,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Botón continuar
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveFaculty,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _isLoading ? 'Guardando...' : 'Continuar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFacultyIcon(String code) {
    switch (code) {
      case Faculties.faing:
        return Icons.engineering_rounded;
      case Faculties.fade:
        return Icons.gavel_rounded;
      case Faculties.facem:
        return Icons.business_center_rounded;
      case Faculties.facsa:
        return Icons.medical_services_rounded;
      case Faculties.faedcoh:
        return Icons.menu_book_rounded;
      case Faculties.fau:
        return Icons.architecture_rounded;
      default:
        return Icons.school_rounded;
    }
  }
}

