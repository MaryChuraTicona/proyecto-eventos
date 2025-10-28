import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/error_handler.dart';
import '../models/admin_speaker_model.dart';

class AdminSpeakerService {
  final _col = FirebaseFirestore.instance.collection('ponentes');

  Stream<List<AdminSpeakerModel>> streamAll() {
    return _col.orderBy('nombre').snapshots().map(
      (qs) => qs.docs
          .map((d) => AdminSpeakerModel.fromDoc(
                d as DocumentSnapshot<Map<String, dynamic>>,
              ))
          .toList(),
    );
  }

  Future<void> upsert(AdminSpeakerModel s) async {
    try {
      final data = s.id.isEmpty ? s.toCreate() : s.toUpdate();
      if (s.id.isEmpty) {
        final docRef = await _col.add(data);
        AppLogger.info('Ponente creado con ID: ${docRef.id}, nombre: ${s.nombre}');
      } else {
        await _col.doc(s.id).set(data, SetOptions(merge: true));
        AppLogger.info('Ponente actualizado: ${s.id}, nombre: ${s.nombre}');
      }
    } on FirebaseException catch (e, st) {
      AppLogger.error('Error Firebase al guardar ponente: ${e.message}', e, st);
      rethrow;
    } catch (e, st) {
      AppLogger.error('Error inesperado al guardar ponente: $e', e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
