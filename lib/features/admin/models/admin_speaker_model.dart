import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSpeakerModel {
  final String id;
  final String nombre;
  final String institucion;
  final String emailCertificado;
  final String bio;
  final List<String> temas;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminSpeakerModel({
    required this.id,
    required this.nombre,
    required this.institucion,
    required this.emailCertificado,
    required this.bio,
    required this.temas,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  factory AdminSpeakerModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminSpeakerModel(
      id: doc.id,
      nombre: (d['nombre'] ?? '').toString(),
      institucion: (d['institucion'] ?? '').toString(),
       emailCertificado: (d['emailCertificado'] ?? d['contacto'] ?? '').toString(),
      bio: (d['bio'] ?? '').toString(),
      temas: (d['temas'] as List? ?? []).map((e) => e.toString()).toList(),
      createdAt: _dt(d['createdAt']),
      updatedAt: _dt(d['updatedAt'] ?? d['updateAt']),
    );
  }

  Map<String, dynamic> toCreate() => {
        'nombre': nombre.trim(),
        'institucion': institucion.trim(),
        'contacto': emailCertificado.trim(),
        'emailCertificado': emailCertificado.trim(),
        'bio': bio.trim(),
        'temas': temas,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(), // compatibilidad
      };

  Map<String, dynamic> toUpdate() => {
        'nombre': nombre.trim(),
        'institucion': institucion.trim(),
         'contacto': emailCertificado.trim(),
        'emailCertificado': emailCertificado.trim(),
        'bio': bio.trim(),
        'temas': temas,
        'updatedAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
      };
}
