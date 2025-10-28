import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/error_handler.dart';
import '../models/admin_event_model.dart';

class AdminEventService {
  final _db = FirebaseFirestore.instance;

  // Colección correcta en tu Firestore
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('eventos');

  Stream<List<AdminEventModel>> streamAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => AdminEventModel.fromDoc(d)).toList());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Guardar evento y devolver su ID
  Future<String> upsertAndGetId(AdminEventModel e) async {
    try {
      final DateTime? inicio = e.fechaInicio;
      final DateTime? fin = e.fechaFin;

      final List<String> diasCalc = (e.dias.isNotEmpty || inicio == null)
          ? e.dias
          : _buildDias(inicio!, (fin ?? inicio)!);

      if (e.id.isEmpty) {
        // CREATE - devolver el ID generado
        final data = e.toMapForCreate()..['dias'] = diasCalc;
        final docRef = await _col.add(data);
        AppLogger.info('Evento creado con ID: ${docRef.id}, nombre: ${e.nombre}');
        return docRef.id;
      } else {
        // UPDATE - devolver el ID existente
        final data = e.toMapForUpdate()..['dias'] = diasCalc;
        await _col.doc(e.id).set(data, SetOptions(merge: true));
        AppLogger.info('Evento actualizado: ${e.id}, nombre: ${e.nombre}');
        return e.id;
      }
    } on FirebaseException catch (e, st) {
      AppLogger.error('Error al guardar evento: ${e.message}', e, st);
      throw 'Firestore upsertAndGetId() falló: ${e.message}';
    }
  }

  Future<void> upsert(AdminEventModel e) async {
    try {
      final DateTime? inicio = e.fechaInicio;
      final DateTime? fin = e.fechaFin;

      // calcular "dias" si no viene y hay fechas válidas
      final List<String> diasCalc = (e.dias.isNotEmpty || inicio == null)
          ? e.dias
          : _buildDias(inicio!, (fin ?? inicio)!);

      if (e.id.isEmpty) {
        // CREATE
        final data = e.toMapForCreate()..['dias'] = diasCalc;
        final docRef = await _col.add(data);
        AppLogger.info('Evento creado con ID: ${docRef.id}, nombre: ${e.nombre}');
      } else {
        // UPDATE (merge)
        final data = e.toMapForUpdate()..['dias'] = diasCalc;
        await _col.doc(e.id).set(data, SetOptions(merge: true));
        AppLogger.info('Evento actualizado: ${e.id}, nombre: ${e.nombre}');
      }
    } on FirebaseException catch (e, st) {
      AppLogger.error('Error al guardar evento: ${e.message}', e, st);
      throw 'Firestore upsert() falló: ${e.message}';
    }
  }

  /// Genera lista de YYYY-MM-DD desde inicio..fin
  List<String> _buildDias(DateTime inicio, DateTime fin) {
    if (fin.isBefore(inicio)) {
      final t = inicio;
      inicio = fin;
      fin = t;
    }
    final out = <String>[];
    for (var d = DateTime(inicio.year, inicio.month, inicio.day);
        !d.isAfter(fin);
        d = d.add(const Duration(days: 1))) {
      out.add('${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }
    return out;
  }
}
