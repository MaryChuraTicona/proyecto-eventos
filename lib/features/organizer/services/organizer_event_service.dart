import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin/models/admin_event_model.dart';

class OrganizerEventService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('eventos');

  Stream<List<AdminEventModel>> watchEventsFor(String organizerId) {
    return _col
        .where('organizerIds', arrayContains: organizerId)
        .snapshots()
        .map((snap) => snap.docs.map(AdminEventModel.fromDoc).toList());
  }

  Stream<AdminEventModel?> watchEvent(String eventId) {
    return _col.doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AdminEventModel.fromDoc(doc);
    });
  }

  Future<AdminEventModel?> fetchEvent(String eventId) async {
    final doc = await _col.doc(eventId).get();
    if (!doc.exists) return null;
    return AdminEventModel.fromDoc(doc);
  }
}