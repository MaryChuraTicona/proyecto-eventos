// lib/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un usuario registrado en la colección 'users' de Firestore.
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? role;
  final bool active;
  final bool? isInstitutional;
  final String? photoURL;
  final String? faculty; // Facultad del usuario (FAING, FACEM, etc.)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.role,
    this.active = true,
    this.isInstitutional,
    this.photoURL,
    this.faculty,
    this.createdAt,
    this.updatedAt,
  });

  /// Crea un objeto [AppUser] desde un documento de Firestore.
  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: (d['email'] ?? '').toString(),
      displayName: d['displayName'] as String?,
      role: (d['role'] ?? d['rol'] ?? 'estudiante').toString(),
      active: (d['active'] ?? true) as bool,
      isInstitutional: d['isInstitutional'] as bool?,
      photoURL: d['photoURL'] as String?,
      faculty: d['faculty'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte el objeto [AppUser] a un mapa para guardar en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role ?? 'estudiante',
      'active': active,
      'isInstitutional': isInstitutional,
      'photoURL': photoURL,
      'faculty': faculty,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }
}
