// lib/app/router_by_rol.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/firestore_paths.dart';
import '../core/constants.dart';
import '../core/error_handler.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/events/student_home_screen.dart';

// Stubs (si los tienes ya, quita esto)
class DocenteHome extends StatelessWidget {
  const DocenteHome({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Panel Docente')));
}
class PonenteHome extends StatelessWidget {
  const PonenteHome({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Panel Ponente')));
}

/// Función que devuelve el widget de home según el rol del usuario
/// 
/// Esta función es usada por [AuthWrapper] para determinar a qué pantalla
/// redirigir al usuario después de autenticarse.
Future<Widget> goHomeByRolWidget(BuildContext context, User user) async {
  try {
    AppLogger.info('Determinando pantalla home para ${user.email}');

    final ref = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid);

    final snap = await ref.get(const GetOptions(source: Source.server));
    
    if (!snap.exists) {
      AppLogger.warning('Documento de usuario no existe, creando: ${user.uid}');
      
      // Crear documento si no existe
      await ref.set({
        'email': user.email?.toLowerCase() ?? '',
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'role': UserRoles.student,
        'rol': UserRoles.student,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.success('Usuario creado como estudiante: ${user.email}');
      return const StudentHomeScreen();
    }

    final data = Map<String, dynamic>.from(snap.data() ?? {});
    final roleRaw = (data['role'] ?? data['rol'])?.toString() ?? UserRoles.student;
    final role = roleRaw.toLowerCase().trim();
    final active = (data['active'] ?? true) == true;

    AppLogger.debug('Usuario ${user.email}: role=$role, active=$active');

    if (!active) {
      AppLogger.warning('Cuenta inactiva: ${user.email}');
      await FirebaseAuth.instance.signOut();
      return const Scaffold(
        body: Center(
          child: Text('Tu cuenta está pendiente de activación.'),
        ),
      );
    }

    final Widget home = switch (role) {
      UserRoles.admin   => const AdminHomeScreen(),
      UserRoles.teacher => const DocenteHome(),
      UserRoles.speaker => const PonenteHome(),
      _                 => const StudentHomeScreen(),
    };
    
    AppLogger.success('Redirigiendo a pantalla: ${home.runtimeType}');
    return home;
  } catch (e, st) {
    AppLogger.error('Error al determinar rol de usuario', e, st);
    return Scaffold(
      body: Center(
        child: Text('Error al cargar tu perfil: ${ErrorHandler.handleError(e)}'),
      ),
    );
  }
}

/// Función de navegación imperativa (compatible con el código existente)
/// 
/// Esta función navega programáticamente a la pantalla de home según el rol.
/// Usa [Navigator.pushAndRemoveUntil] para eliminar el stack de navegación.
Future<void> goHomeByRol(BuildContext context) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) {
    AppLogger.warning('goHomeByRol llamado sin usuario autenticado');
    return;
  }

  try {
    AppLogger.info('Navegando por rol para usuario: ${u.email}');

    final ref = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(u.uid);

    final snap = await ref.get(const GetOptions(source: Source.server));
    
    if (!snap.exists) {
      AppLogger.error('Perfil de usuario no encontrado: ${u.uid}');
      throw 'No existe tu perfil en Firestore.';
    }

    final data = Map<String, dynamic>.from(snap.data() ?? {});
    final roleRaw = (data['role'] ?? data['rol'])?.toString() ?? UserRoles.student;
    final role = roleRaw.toLowerCase().trim();
    final active = (data['active'] ?? true) == true;

    AppLogger.debug('Datos de usuario: role=$role, active=$active');

    if (!active) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta está pendiente de activación.')),
      );
      await FirebaseAuth.instance.signOut();
      AppLogger.warning('Cuenta inactiva, sesión cerrada');
      return;
    }

    final Widget home = switch (role) {
      UserRoles.admin   => const AdminHomeScreen(),
      UserRoles.teacher => const DocenteHome(),
      UserRoles.speaker => const PonenteHome(),
      _                 => const StudentHomeScreen(),
    };

    if (!context.mounted) return;
    
    AppLogger.success('Navegando a: ${home.runtimeType}');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (_) => false,
    );
  } catch (e, st) {
    AppLogger.error('Error al navegar por rol', e, st);
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ErrorHandler.handleError(e))),
    );
  }
}
