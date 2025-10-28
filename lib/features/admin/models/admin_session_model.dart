import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSessionModel {
  final String id;
  final String eventoId;            // redundante, útil para queries
  final String titulo;
  final String ponenteId;
  final String ponenteNombre;
  final String modalidad;           // 'Presencial' | 'Virtual'
  final String? sala;
  final String? link;
  final int aforo;
  final int cuposDisponibles;
  final String dia;                 // YYYY-MM-DD
  final Timestamp horaInicio;
  final Timestamp horaFin;
   final List<String> tags; 
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  AdminSessionModel({
    required this.id,
    required this.eventoId,
    required this.titulo,
    required this.ponenteId,
    required this.ponenteNombre,
    required this.modalidad,
    required this.sala,
    required this.link,
    required this.aforo,
    required this.cuposDisponibles,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
     required this.tags,  
    this.createdAt,
    this.updatedAt,
  });

  factory AdminSessionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminSessionModel(
      id: doc.id,
      eventoId: (d['eventoId'] ?? '') as String,
      titulo: (d['titulo'] ?? '') as String,
      ponenteId: (d['ponenteId'] ?? '') as String,
      ponenteNombre: (d['ponenteNombre'] ?? '') as String,
      modalidad: (d['modalidad'] ?? 'Presencial') as String,
      sala: d['sala'] as String?,
      link: d['link'] as String?,
      aforo: (d['aforo'] ?? 0) as int,
      cuposDisponibles: (d['cuposDisponibles'] ?? 0) as int,
      dia: (d['dia'] ?? '') as String,
      horaInicio: d['horaInicio'] as Timestamp,
      horaFin: d['horaFin'] as Timestamp,
      tags: (d['tags'] as List? ?? const [])        // 👈 NUEVO
          .map((e) => e.toString())
          .toList(),
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }
  Map<String, dynamic> toCreate() => {
        'eventoId': eventoId,
        'titulo': titulo.trim(),
        'ponenteId': ponenteId,
        'ponenteNombre': ponenteNombre.trim(),
        'modalidad': modalidad,
        'sala': sala,
        'link': link,
        'aforo': aforo,
        'cuposDisponibles': cuposDisponibles,
        'dia': dia,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'tags': tags,                              // 👈 NUEVO
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdate() => {
        'titulo': titulo.trim(),
        'ponenteId': ponenteId,
        'ponenteNombre': ponenteNombre.trim(),
        'modalidad': modalidad,
        'sala': sala,
        'link': link,
        'aforo': aforo,
        'cuposDisponibles': cuposDisponibles,
        'dia': dia,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'tags': tags,                              // 👈 NUEVO
        'updatedAt': FieldValue.serverTimestamp(),
      };
}