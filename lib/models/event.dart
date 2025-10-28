// lib/models/event.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String? description;
  final String? venue;
  /// 'draft' | 'published' | 'closed'
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;

  EventModel({
    required this.id,
    required this.title,
    required this.status,
    this.description,
    this.venue,
    this.startAt,
    this.endAt,
  });

  factory EventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EventModel(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      description: d['description'] as String?,
      venue: d['venue'] as String?,
      status: (d['status'] ?? 'draft').toString(),
      startAt: (d['startAt'] as Timestamp?)?.toDate(),
      endAt: (d['endAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'description': (description ?? '').trim(),
        'venue': (venue ?? '').trim(),
        'status': status,
        'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
        'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
      }..removeWhere((k, v) => v == null);
}
