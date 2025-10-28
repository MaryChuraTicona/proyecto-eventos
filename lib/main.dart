import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'app/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'app/router_by_rol.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EventosEpisApp());
}

class EventosEpisApp extends StatelessWidget {
  const EventosEpisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVENTOS EPIS – UPT',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si hay usuario autenticado, ir a su pantalla según rol
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder(
            future: goHomeByRolWidget(context, snapshot.data!),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return futureSnapshot.data ?? const LoginScreen();
            },
          );
        }

        // Si no hay usuario, mostrar login
        return const LoginScreen();
      },
    );
  }
}
