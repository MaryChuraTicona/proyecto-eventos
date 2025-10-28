// lib/features/admin/services/admin_seed_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de inicialización (seed) para cargar datos demo en Firestore.
/// Este archivo se ejecuta desde el botón de "auto_fix_high" del panel admin.
class AdminSeedService {
  static final _db = FirebaseFirestore.instance;

  /// Crea colecciones base y un evento de ejemplo.
  static Future<void> bootstrapFirestore() async {
    // Crear las colecciones principales si no existen
    await _db.collection('eventos').doc('_meta').set({
      'createdAt': FieldValue.serverTimestamp(),
      'note': 'placeholder',
    }, SetOptions(merge: true));

    await _db.collection('ponentes').doc('_meta').set({
      'createdAt': FieldValue.serverTimestamp(),
      'note': 'placeholder',
    }, SetOptions(merge: true));

    // Crear un evento de ejemplo
    final inicio = DateTime(DateTime.now().year, 11, 3);
    final fin = inicio.add(const Duration(days: 2));
    final dias = _buildDias(inicio, fin);

    final evRef = await _db.collection('eventos').add({
      'nombre': 'CATEC',
      'tipo': 'CATEC',
      'descripcion': 'Congreso de Tecnología EPIS',
      'fechaInicio': Timestamp.fromDate(inicio),
      'fechaFin': Timestamp.fromDate(fin),
      'dias': dias,
      'lugarGeneral': 'Auditorio EPIS',
      'modalidadGeneral': 'Mixta',
      'aforoGeneral': 800,
      'estado': 'activo',
      'requiereInscripcionPorSesion': true,
      'createdBy': 'admin-demo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Crear una ponencia de ejemplo dentro del evento
    final sesCol = evRef.collection('sesiones');
    await sesCol.add({
      'titulo': 'Inteligencia Artificial Aplicada',
      'ponenteId': null,
      'ponenteNombre': 'Ponente Demo',
      'dia': dias.first,
      'horaInicio': Timestamp.fromDate(inicio.add(const Duration(hours: 9))),
      'horaFin': Timestamp.fromDate(inicio.add(const Duration(hours: 10))),
      'modalidad': 'Presencial',
      'sala': 'Auditorio A',
      'link': null,
      'aforo': 120,
      'cuposDisponibles': 120,
      'tags': ['IA'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Genera una lista de fechas entre [inicio] y [fin] en formato yyyy-MM-dd
  static List<String> _buildDias(DateTime inicio, DateTime fin) {
    final out = <String>[];
    for (var d = DateTime(inicio.year, inicio.month, inicio.day);
        !d.isAfter(fin);
        d = d.add(const Duration(days: 1))) {
      out.add("${d.year.toString().padLeft(4, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')}");
    }
    return out;
  }
}
