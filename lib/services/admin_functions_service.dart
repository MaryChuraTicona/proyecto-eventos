// lib/services/admin_functions_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firestore_paths.dart';

/// Servicio auxiliar para funciones del administrador
/// - Crear usuarios con rol específico.
/// - Guardar datos iniciales en Firestore.
class AdminFunctionsService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// Crea un nuevo usuario en Firebase Authentication y su documento en Firestore.
  ///
  /// Retorna un mapa con los datos creados:
  /// { "uid": ..., "email": ..., "tempPassword": ... }
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String role,
    String? displayName,
    String? tempPassword,
  }) async {
    // Si no hay password, genera una temporal
    tempPassword ??= _generateTempPassword();

    try {
      // Crear cuenta en Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      // Actualizar displayName
      await cred.user?.updateDisplayName(displayName ?? email);

      // Crear documento en Firestore
      await _db.doc(FirestorePaths.user(cred.user!.uid)).set({
        'email': email.toLowerCase(),
        'displayName': displayName ?? '',
        'role': role,
        'estado': 'activo',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'uid': cred.user!.uid,
        'email': email,
        'tempPassword': tempPassword,
      };
    } on FirebaseAuthException catch (e) {
      throw Exception('Error FirebaseAuth: ${e.message}');
    } catch (e) {
      throw Exception('Error creando usuario: $e');
    }
  }

  /// Genera una contraseña temporal aleatoria (8 caracteres)
  String _generateTempPassword() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    chars.split('');
    return List.generate(
      8,
      (i) => chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length],
    ).join();
  }
}
