// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_paths.dart';
import '../models/app_user.dart';

/// Servicio para gestionar usuarios en Firestore.
class UserService {
  final _db = FirebaseFirestore.instance;

  /// Devuelve un stream de todos los usuarios.
  Stream<List<AppUser>> watchAll() {
    return _db.collection(FirestorePaths.users).snapshots().map(
          (snap) => snap.docs.map(AppUser.fromDoc).toList(),
        );
  }

  /// Cambia el rol del usuario.
  Future<void> setRole(String uid, String role) async {
    await _db.doc(FirestorePaths.user(uid)).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Activa o desactiva un usuario.
  Future<void> setActive(String uid, bool value) async {
    await _db.doc(FirestorePaths.user(uid)).update({
      'active': value,
      'estado': value ? 'activo' : 'suspendido',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cambia la facultad del usuario.
  Future<void> setFaculty(String uid, String faculty) async {
    await _db.doc(FirestorePaths.user(uid)).update({
      'faculty': faculty,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
