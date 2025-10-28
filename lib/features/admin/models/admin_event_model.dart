import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) { try { return DateTime.parse(v); } catch (_) {} }
  return null;
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
  });

  factory AdminEventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
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
      };
}
