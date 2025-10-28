// lib/utils/email_domain.dart

/// Verifica si un correo pertenece al dominio institucional.
///
/// Retorna `true` si el correo termina en:
/// - @upt.pe
/// - @virtual.upt.pe
/// 
/// Ejemplo:
/// ```dart
/// isInstitutionalEmail('mc2019065163@virtual.upt.pe'); // true
/// isInstitutionalEmail('alumno@upt.pe'); // true
/// isInstitutionalEmail('gmail@gmail.com'); // false
/// ```
bool isInstitutionalEmail(String email) {
  final e = email.trim().toLowerCase();
  return e.endsWith('@upt.pe') || e.endsWith('@virtual.upt.pe');
}
