// lib/models/registration.dart
class RegistrationModel {
  final String id;      // doc id (uid del usuario)
  final String eventId;
  final String userId;
  final DateTime createdAt;

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.createdAt,
  });
}
