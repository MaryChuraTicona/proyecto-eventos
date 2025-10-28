// lib/services/attendance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final _db = FirebaseFirestore.instance;
  
  // Nombre de la colección (attendance en inglés para consistencia con BD existente)
  static const String _collectionName = 'attendance';

  String _docId(String eventId, String uid, [String? sessionId]) {
    return sessionId == null ? '${eventId}_$uid' : '${eventId}_${sessionId}_$uid';
  }

  Future<void> mark(String eventId, String uid, [String? sessionId, Map<String, 
  dynamic>? extra]) async {
    final id = _docId(eventId, uid, sessionId);
    await _db.collection(_collectionName).doc(id).set({
      'id': id,
      'eventId': eventId,
      'uid': uid,
      if (sessionId != null) 'sessionId': sessionId,
      'markedAt': FieldValue.serverTimestamp(),
      'present': true,
       if (extra != null) ...extra,
    }, SetOptions(merge: true));
  }

  Future<bool> wasMarked(String eventId, String uid, [String? sessionId]) async {
    final id = _docId(eventId, uid, sessionId);
    final doc = await _db.collection(_collectionName).doc(id).get();
    return doc.exists && (doc.data()?['present'] == true);
  }
  
  /// Stream en tiempo real del estado de asistencia
  /// 
  /// Se actualiza automáticamente cuando se marca/desmarca la asistencia
  Stream<bool> watchAttendanceStatus(String eventId, String uid, [String? sessionId]) {
    final id = _docId(eventId, uid, sessionId);
    return _db
        .collection(_collectionName)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists && (doc.data()?['present'] == true));
  }
  
  /// Stream de todas las asistencias de un evento
  /// 
  /// Útil para ver en tiempo real quién ha asistido
  Stream<List<Map<String, dynamic>>> watchEventAttendance(String eventId) {
    return _db
        .collection(_collectionName)
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
  
  /// Stream de asistencias por sesión específica
  Stream<List<Map<String, dynamic>>> watchSessionAttendance(
    String eventId, 
    String sessionId
  ) {
    return _db
        .collection(_collectionName)
        .where('eventId', isEqualTo: eventId)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// NUEVO: marca asistencia solo si estamos dentro de la ventana de tiempo.
  /// Usa tolerancia: 15 min antes y 30 min después.
  Future<bool> markIfInWindow({
    required String uid,
    required String eventId,
    required String sessionId,
    required DateTime start,
    required DateTime end,
    Duration toleranceBefore = const Duration(minutes: 15),
    Duration toleranceAfter = const Duration(minutes: 30),
    Map<String, dynamic>? extra,
 
  }) async {
    final now = DateTime.now();
    final windowStart = start.subtract(toleranceBefore);
    final windowEnd = end.add(toleranceAfter);

    if (now.isBefore(windowStart) || now.isAfter(windowEnd)) {
      return false;
    }

    await mark(eventId, uid, sessionId, extra);
    return true;
  }
}
