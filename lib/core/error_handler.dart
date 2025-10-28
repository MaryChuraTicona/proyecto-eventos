// lib/core/error_handler.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';

/// Clase para manejar errores de manera centralizada
class ErrorHandler {
  /// Convierte excepciones de Firebase Auth a mensajes legibles
  static String handleAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return ErrorMessages.userNotFound;
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return ErrorMessages.wrongPassword;
      case 'email-already-in-use':
        return ErrorMessages.emailAlreadyInUse;
      case 'weak-password':
        return ErrorMessages.weakPassword;
      case 'user-disabled':
        return ErrorMessages.accountDisabled;
      case 'network-request-failed':
        return ErrorMessages.networkError;
      case 'invalid-email':
        return ErrorMessages.invalidEmail;
      case 'popup-blocked':
      case 'popup-closed-by-user':
        return 'Popup bloqueado. Por favor, habilita popups o intenta de nuevo.';
      case 'unauthorized-domain':
        return 'Dominio no autorizado en Firebase Console.';
      default:
        return 'Error de autenticación: ${error.code}';
    }
  }

  /// Convierte excepciones de Firestore a mensajes legibles
  static String handleFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return ErrorMessages.permissionDenied;
      case 'unavailable':
        return ErrorMessages.networkError;
      case 'not-found':
        return 'Documento no encontrado.';
      case 'already-exists':
        return 'El documento ya existe.';
      case 'deadline-exceeded':
        return 'La operación tardó demasiado. Intenta de nuevo.';
      default:
        return 'Error de base de datos: ${error.code}';
    }
  }

  /// Maneja cualquier tipo de error y devuelve un mensaje apropiado
  static String handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      return handleAuthError(error);
    } else if (error is FirebaseException) {
      return handleFirestoreError(error);
    } else if (error is String) {
      return error;
    } else {
      return ErrorMessages.unknownError;
    }
  }

  /// Registra el error en consola (solo en modo debug) y devuelve mensaje
  static String logAndHandle(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ Error: $error');
      if (stackTrace != null) {
        debugPrint('📍 Stack trace:\n$stackTrace');
      }
    }
    return handleError(error);
  }
}

/// Clase para logging estructurado
class AppLogger {
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ [SUCCESS] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack trace:\n$stackTrace');
      }
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 [DEBUG] $message');
    }
  }
}

