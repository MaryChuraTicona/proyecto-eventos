// lib/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un usuario registrado en la colección 'users' de Firestore.
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
   final String? firstName;
  final String? lastName;
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
    this.firstName,
    this.lastName,
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
     String? _trimmedString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final rawDisplayName = _trimmedString(d['displayName']);
    final firstName = _trimmedString(d['nombres']);
    final lastName = _trimmedString(d['apellidos']);
    final combinedName = [firstName, lastName]
        .where((part) => part != null && part!.isNotEmpty)
        .map((part) => part!)
        .join(' ')
        .trim();
    final resolvedDisplayName =
        _trimmedString(rawDisplayName) ?? _trimmedString(combinedName);
    return AppUser(
      uid: doc.id,
      email: (d['email'] ?? '').toString(),
      displayName: resolvedDisplayName,
      firstName: firstName,
      lastName: lastName,
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
        'nombres': firstName,
      'apellidos': lastName,
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
