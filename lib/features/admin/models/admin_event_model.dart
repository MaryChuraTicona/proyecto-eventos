import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) { try { return DateTime.parse(v); } catch (_) {} }
  return null;
}

class AdminEventOrganizer {
  final String uid;
  final String email;
  final String displayName;
  final String? phone;
  final String? ciclo;

  const AdminEventOrganizer({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phone,
    this.ciclo,
  });

  factory AdminEventOrganizer.fromMap(Map<String, dynamic> data) {
    return AdminEventOrganizer(
      uid: (data['uid'] ?? data['id'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      displayName: (data['displayName'] ?? data['nombre'] ?? '').toString(),
      phone: (data['phone'] ?? data['telefono'])?.toString(),
      ciclo: (data['ciclo'] ?? data['cicloAcademico'])?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (ciclo != null && ciclo!.isNotEmpty) 'ciclo': ciclo,
      };
}
class AdminEventModel {
  final String id;
  final String nombre;
  final String tipo;
  final String descripcion;
  final DateTime? fechaInicio;   // start
  final DateTime? fechaFin;      // end
  final List<String> dias;
  final String lugarGeneral;
  final String modalidadGeneral;
  final int aforoGeneral;
  final String estado;
  final bool requiereInscripcionPorSesion;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<AdminEventOrganizer> organizers;

  AdminEventModel({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.dias,
    required this.lugarGeneral,
    required this.modalidadGeneral,
    required this.aforoGeneral,
    required this.estado,
    required this.requiereInscripcionPorSesion,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.organizers = const [],
  });

 List<String> get organizerIds => organizers.map((o) => o.uid).where((e) => e.isNotEmpty).toList();
  factory AdminEventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

      final rawOrganizers = (d['organizers'] as List?) ?? const [];
    final parsedOrganizers = rawOrganizers
        .map((e) {
          if (e is AdminEventOrganizer) return e;
          if (e is Map<String, dynamic>) return AdminEventOrganizer.fromMap(e);
          if (e is Map) {
            return AdminEventOrganizer.fromMap(
                e.map((key, value) => MapEntry(key.toString(), value)));
          }
          return null;
        })
        .whereType<AdminEventOrganizer>()
        .where((e) => e.uid.isNotEmpty)
        .toList();
    return AdminEventModel(
      id: doc.id,
      nombre: (d['nombre'] ?? '').toString(),
      tipo: (d['tipo'] ?? 'CATEC').toString(),
      descripcion: (d['descripcion'] ?? '').toString(),
      fechaInicio: _toDate(d['fechaInicio']),
      fechaFin: _toDate(d['fechaFin']),
      dias: (d['dias'] as List? ?? const []).map((e) => e.toString()).toList(),
      lugarGeneral: (d['lugarGeneral'] ?? '').toString(),
      modalidadGeneral: (d['modalidadGeneral'] ?? 'Mixta').toString(),
      aforoGeneral: (d['aforoGeneral'] is int)
          ? d['aforoGeneral'] as int
          : int.tryParse('${d['aforoGeneral'] ?? 0}') ?? 0,
      estado: (d['estado'] ?? 'activo').toString(),
      requiereInscripcionPorSesion:
          (d['requiereInscripcionPorSesion'] ?? true) == true,
      createdBy: (d['createdBy'] ?? '').toString(),
      createdAt: _toDate(d['createdAt']),
      updatedAt: _toDate(d['updatedAt'] ?? d['updateAt']),
    organizers: parsedOrganizers,
    );
  }

  Map<String, dynamic> toMapForCreate() => {
        'nombre': nombre.trim(),
        'tipo': tipo,
        'descripcion': descripcion,
        'fechaInicio': fechaInicio ?? FieldValue.serverTimestamp(),
        'fechaFin': fechaFin,
        'dias': dias,
        'lugarGeneral': lugarGeneral,
        'modalidadGeneral': modalidadGeneral,
        'aforoGeneral': aforoGeneral,
        'estado': estado,
        'requiereInscripcionPorSesion': requiereInscripcionPorSesion,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
        'organizers': organizers.map((e) => e.toMap()).toList(),
        'organizerIds': organizerIds,
      };

  Map<String, dynamic> toMapForUpdate() => {
        'nombre': nombre.trim(),
        'tipo': tipo,
        'descripcion': descripcion,
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'dias': dias,
        'lugarGeneral': lugarGeneral,
        'modalidadGeneral': modalidadGeneral,
        'aforoGeneral': aforoGeneral,
        'estado': estado,
        'requiereInscripcionPorSesion': requiereInscripcionPorSesion,
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
          'organizers': organizers.map((e) => e.toMap()).toList(),
        'organizerIds': organizerIds,
      };
}
