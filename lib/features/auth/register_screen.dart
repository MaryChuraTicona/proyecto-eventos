import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/email.domain.dart';

Future<void> onRegisterSubmit(String email, String password, String displayName) async {
  final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password.trim(),
  );

  await cred.user!.updateDisplayName(displayName.trim());
  final isInst = isInstitutionalEmail(email);

  await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
    'email': email.trim().toLowerCase(),
    'displayName': displayName.trim(),
    'rol': 'estudiante',            // <- clave: siempre estudiante en self-signup
    'active': true,
    'isInstitutional': isInst,      // para métricas/reportes
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
