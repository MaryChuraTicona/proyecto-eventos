// lib/services/registration_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error_handler.dart';
import 'attendance_service.dart';

class RegistrationService {
  final _db = FirebaseFirestore.instance;
  
  // Nombre de la colección (registrations en inglés para consistencia con BD existente)
  static const String _collectionName = 'registrations';

  /* =================== CRUD básico de inscripciones =================== */

  // Stream sencillo por usuario (si lo necesitas en otros lados)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchByUser(String uid) {
    return _db
        .collection(_collectionName)
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  String _docId(String eventId, String uid, [String? sessionId]) {
    // Sin sesión:   evento_uid
    // Con sesión:   evento_sesion_uid
    return sessionId == null ? '${eventId}_$uid' : '${eventId}_${sessionId}_$uid';
  }

   Future<void> register(
    String uid,
    String eventId, [
    String? sessionId,
    Map<String, dynamic>? extra,
  ]) async {
    final id = _docId(eventId, uid, sessionId);
    await _db.collection(_collectionName).doc(id).set({
      'id': id,
      'eventId': eventId,
      'uid': uid,
      if (sessionId != null) 'sessionId': sessionId,
if (sessionId == null) 'scope': 'event' else 'scope': 'session',
      if (extra != null)
        'answers': {
          ...extra,
          'updatedAt': FieldValue.serverTimestamp(),
        },

      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregister(String uid, String eventId, [String? sessionId]) async {
    final id = _docId(eventId, uid, sessionId);
    await _db.collection(_collectionName).doc(id).delete();
  }

  Future<bool> isRegistered(String uid, String eventId, [String? sessionId]) async {
    final id = _docId(eventId, uid, sessionId);
    final doc = await _db.collection(_collectionName).doc(id).get();
    return doc.exists;
  }

  /* =================== Historial para StudentHome =================== */
  
  /// Stream en tiempo real del historial del usuario combinando:
  /// - Inscripciones (registrations)
  /// - Datos del evento (eventos/{eventId})
  /// - Datos de la sesión (eventos/{eventId}/sesiones/{sessionId})
  /// - Estado de asistencia (attendance)
  /// 
  /// Se actualiza automáticamente cuando:
  /// - Se agregan/eliminan inscripciones
  /// - Se modifica un evento o sesión
  /// - Se marca asistencia
  Stream<List<UserRegistrationView>> watchUserHistory(String uid) {
    // Stream base de inscripciones
    final registrationsStream = _db
        .collection(_collectionName)
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final attendanceSvc = AttendanceService();

    // Combinar con streams de eventos y sesiones para tiempo real completo
    return registrationsStream.asyncMap((snap) async {
      if (snap.docs.isEmpty) return <UserRegistrationView>[];

      final futures = snap.docs.map((d) async {
        final data = d.data();
         final Timestamp? createdAt =
            data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
        final String eventId = (data['eventId'] ?? '').toString();
        final String? sessionId = (data['sessionId'] as String?);

        // 1) Obtener datos del evento en tiempo real
        final evDoc = await _db.collection('eventos').doc(eventId).get();
        final ev = evDoc.data() ?? {};
        final String eventName = (ev['nombre'] ?? '').toString();
         String location = (ev['lugarGeneral'] ?? '').toString();
        // Defaults (si no hay sesión)
        String titulo = eventName.isNotEmpty ? eventName : 'Evento';
        String dia = '';
        Timestamp horaInicioTs = (ev['fechaInicio'] is Timestamp)
            ? ev['fechaInicio'] as Timestamp
            : Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
        Timestamp horaFinTs = (ev['fechaFin'] is Timestamp)
            ? ev['fechaFin'] as Timestamp
            : horaInicioTs;

        // 2) Obtener datos de la sesión si existe
        if (sessionId != null && sessionId.isNotEmpty) {
          try {
            final sesDoc = await _db
                .collection('eventos')
                .doc(eventId)
                .collection('sesiones')  // Usar 'sesiones' en lugar de 'ponencias'
                .doc(sessionId)
                .get();
            
            if (sesDoc.exists) {
              final ses = sesDoc.data() ?? {};
              titulo = (ses['titulo'] ?? titulo).toString();
              dia = (ses['dia'] ?? '').toString();
              
               final sessionLocation =
                  (ses['lugar'] ?? ses['ambiente'] ?? '').toString();
              if (sessionLocation.isNotEmpty) {
                location = sessionLocation;
              }
              if (ses['horaInicio'] is Timestamp) {
                horaInicioTs = ses['horaInicio'] as Timestamp;
              }
              if (ses['horaFin'] is Timestamp) {
                horaFinTs = ses['horaFin'] as Timestamp;
              }
            }
          } catch (e) {
            // Si hay error, usar los defaults del evento
            AppLogger.warning('Error al cargar sesión: $sessionId, evento: $eventId, error: $e');
          }
        }

        // 3) Verificar asistencia
        final attended = await attendanceSvc.wasMarked(eventId, uid, sessionId);

        return UserRegistrationView(
          eventId: eventId,
          sessionId: sessionId,
          eventName: eventName,
          titulo: titulo,
          dia: dia,
          horaInicio: horaInicioTs,
          horaFin: horaFinTs,
          attended: attended,
          location: location,
          createdAt: createdAt,
        );
      }).toList();

      final list = await Future.wait(futures);
      // Ordenar por fecha de inicio descendente
     list.sort((a, b) {
        final aTs = a.createdAt ?? a.horaInicio;
        final bTs = b.createdAt ?? b.horaInicio;
        return bTs.compareTo(aTs);
      });
      return list;
    });
  }
  
  /// Stream en tiempo real del estado de registro para una sesión específica
  /// 
  /// Se actualiza automáticamente cuando el usuario se registra o des-registra
  Stream<bool> watchRegistrationStatus(String uid, String eventId, [String? sessionId]) {
    final id = _docId(eventId, uid, sessionId);
    return _db
        .collection(_collectionName)
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /* =================== Estado para una sesión concreta =================== */
  Future<UserSessionStatus> statusForUserSession(
    String? uid,
    String eventId,
    String sessionId,
  ) async {
    if (uid == null || uid.isEmpty) {
      return const UserSessionStatus(registered: false, attended: false);
    }
    final registered = await isRegistered(uid, eventId, sessionId);
    final attended = await AttendanceService().wasMarked(eventId, uid, sessionId);
    return UserSessionStatus(registered: registered, attended: attended);
  }
}

/* =================== Modelos usados por la UI =================== */

class UserRegistrationView {
  final String eventId;
  final String? sessionId;
  final String eventName;
  final String titulo;      // Título de la ponencia o del evento
  final String dia;         // Texto como "Lunes 21" (si lo manejas así)
  final Timestamp horaInicio;
  final Timestamp horaFin;
  final bool attended;
   final String location;
  final Timestamp? createdAt;

  UserRegistrationView({
    required this.eventId,
    required this.sessionId,
    required this.eventName,
    required this.titulo,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.attended,
     required this.location,
    required this.createdAt,
  });

  bool get finished => horaFin.toDate().isBefore(DateTime.now());
}

class UserSessionStatus {
  final bool registered;
  final bool attended;
  const UserSessionStatus({required this.registered, required this.attended});
}
