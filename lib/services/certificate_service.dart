import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateProgress {
  final int totalSessions;
  final int attendedSessions;
  final double percentage;
  final bool issued;
  final DateTime? issuedAt;
  final String? downloadUrl;

  bool get canIssue => totalSessions > 0 && percentage >= 0.8;

  const CertificateProgress({
    required this.totalSessions,
    required this.attendedSessions,
    required this.percentage,
    required this.issued,
    required this.issuedAt,
    required this.downloadUrl,
  });
}

class CertificateService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('certificados');

  String _docId(String eventId, String uid) => '${eventId}_$uid';

  Stream<CertificateProgress> watchProgress(String uid, String eventId) {
    final controller = StreamController<CertificateProgress>();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessions = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attendance = [];
    DocumentSnapshot<Map<String, dynamic>>? certificate;

    void emit() {
      final totalSessions = sessions.length;
      final attendedSessions = attendance
          .where((doc) => (doc.data()['present'] ?? true) == true)
          .where((doc) => (doc.data()['sessionId'] ?? '').toString().isNotEmpty)
          .length;
      final percentage = totalSessions == 0
          ? 0.0
          : attendedSessions / totalSessions;
      final issued = certificate?.exists == true;
      final issuedAt = certificate != null
          ? (certificate!.data()?['issuedAt'] as Timestamp?)?.toDate()
          : null;
      final downloadUrl = certificate?.data()?['downloadUrl'] as String?;

      controller.add(CertificateProgress(
        totalSessions: totalSessions,
        attendedSessions: attendedSessions,
        percentage: percentage,
        issued: issued,
        issuedAt: issuedAt,
        downloadUrl: downloadUrl,
      ));
    }

    final sessionsSub = _db
        .collection('eventos')
        .doc(eventId)
        .collection('sesiones')
        .snapshots()
        .listen((snap) {
      sessions = snap.docs;
      emit();
    });

    final attendanceSub = _db
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      attendance = snap.docs;
      emit();
    });

    final certSub = _col.doc(_docId(eventId, uid)).snapshots().listen((snap) {
      certificate = snap;
      emit();
    });

    emit();

    controller.onCancel = () {
      sessionsSub.cancel();
      attendanceSub.cancel();
      certSub.cancel();
    };

    return controller.stream;
  }

  Future<CertificateProgress> computeProgress(String uid, String eventId) async {
    final sessionsSnap = await _db
        .collection('eventos')
        .doc(eventId)
        .collection('sesiones')
        .get();
    final attendanceSnap = await _db
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .where('uid', isEqualTo: uid)
        .get();
    final certSnap = await _col.doc(_docId(eventId, uid)).get();

    final totalSessions = sessionsSnap.docs.length;
    final attendedSessions = attendanceSnap.docs
        .where((doc) => (doc.data()['present'] ?? true) == true)
        .where((doc) => (doc.data()['sessionId'] ?? '').toString().isNotEmpty)
        .length;
    final percentage = totalSessions == 0
        ? 0.0
        : attendedSessions / totalSessions;

    return CertificateProgress(
      totalSessions: totalSessions,
      attendedSessions: attendedSessions,
      percentage: percentage,
      issued: certSnap.exists,
      issuedAt:
          certSnap.exists ? (certSnap.data()?['issuedAt'] as Timestamp?)?.toDate() : null,
      downloadUrl: certSnap.data()?['downloadUrl'] as String?,
    );
  }

  Future<void> issueCertificate({
    required String uid,
    required String eventId,
    required String email,
    String recipientType = 'student',
  }) async {
    final progress = await computeProgress(uid, eventId);
    if (!progress.canIssue) {
      throw 'Aún no alcanza el 80% de asistencia.';
    }

    await _col.doc(_docId(eventId, uid)).set({
      'eventId': eventId,
      'uid': uid,
      'email': email,
      'recipientType': recipientType,
      'issuedAt': FieldValue.serverTimestamp(),
      'percentage': progress.percentage,
      'totalSessions': progress.totalSessions,
      'attendedSessions': progress.attendedSessions,
      'status': 'issued',
    }, SetOptions(merge: true));
  }

  Future<void> issueSpeakerCertificate({
    required String eventId,
    required String speakerId,
    required String speakerName,
    required String email,
  }) async {
    await _col.add({
      'eventId': eventId,
      'uid': 'speaker_$speakerId',
      'speakerId': speakerId,
      'speakerName': speakerName,
      'email': email,
      'recipientType': 'speaker',
      'issuedAt': FieldValue.serverTimestamp(),
      'status': 'pending_delivery',
    });
  }
}