import 'constants.dart';

/// Clase helper para paths de Firestore
/// 
/// Usa las constantes centralizadas de [FirestoreCollections] para garantizar
/// consistencia en toda la aplicación.
class FirestorePaths {
  // Colecciones principales
  static const String users = FirestoreCollections.users;
  static const String eventos = FirestoreCollections.events;
  static const String ponentes = FirestoreCollections.speakers;
  static const String sesiones = FirestoreCollections.sessions;
  static const String certificados = FirestoreCollections.certificates;

  // Helpers para paths completos
  static String user(String uid) => '$users/$uid';
  
  static String evento(String eventId) => '$eventos/$eventId';
  
  static String sesion(String eventId, String sessionId) => 
      '$eventos/$eventId/$sesiones/$sessionId';
  
  static String registrations(String eventId) => 
      '$eventos/$eventId/${FirestoreCollections.registrations}';
  
  static String registration(String eventId, String uid) => 
      '$eventos/$eventId/${FirestoreCollections.registrations}/$uid';
  
  static String attendances(String eventId) => 
      '$eventos/$eventId/${FirestoreCollections.attendance}';
  
 
  static String attendance(String eventId, String uid) =>
      '$eventos/$eventId/${FirestoreCollections.attendance}/$uid';

  static String certificate(String eventId, String uid) =>
      '${FirestoreCollections.certificates}/${eventId}_$uid';
}