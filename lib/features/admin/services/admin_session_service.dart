import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_session_model.dart';

class AdminSessionService {
  final _db = FirebaseFirestore.instance;

  // colecciones: eventos/{eventId}/sesiones
  CollectionReference<Map<String, dynamic>> _col(String eventId) =>
      _db.collection('eventos').doc(eventId).collection('sesiones');

  // LECTURA por evento (simple, sin índice compuesto)
  Stream<List<AdminSessionModel>> streamByEvent(String eventId) {
    return _col(eventId)
        .orderBy('horaInicio')              // solo orderBy → no requiere índice
        .snapshots()
        .map((s) => s.docs.map((d) => AdminSessionModel.fromDoc(d)).toList());
  }

  Future<void> delete(String eventId, String id) => _col(eventId).doc(id).delete();

  Future<void> upsert(AdminSessionModel s) async {
    final data = s.id.isEmpty ? s.toCreate() : s.toUpdate();
    if (s.id.isEmpty) {
      await _col(s.eventoId).add(data);
    } else {
      await _col(s.eventoId).doc(s.id).set(data, SetOptions(merge: true));
    }
  }
}
