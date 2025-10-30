// lib/services/event_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../core/constants.dart';
import '../core/error_handler.dart';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {}
  }
  return null;
}

/// Servicio para gestionar eventos
class EventService {
  final _db = FirebaseFirestore.instance;
  
  // Cache para reducir lecturas de Firestore
  final Map<String, EventModel> _cache = {};
  DateTime? _lastCacheUpdate;

  /// Obtener un evento por su ID con cache
  /// 
  /// Busca primero en cache, si no está o está desactualizado, consulta Firestore.
  Future<EventModel?> porId(String id, {bool forceRefresh = false}) async {
    try {
      // Verificar cache (válido por 5 minutos)
      if (!forceRefresh && 
          _cache.containsKey(id) && 
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 5) {
        AppLogger.debug('Evento $id obtenido desde cache');
        return _cache[id];
      }

      AppLogger.info('Obteniendo evento $id desde Firestore');
      final doc = await _db
          .collection(FirestoreCollections.events)
          .doc(id)
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (!doc.exists) {
        AppLogger.warning('Evento $id no encontrado');
        return null;
      }
      
      final d = doc.data()!;
      final event = EventModel(
        id: doc.id,
        title: (d['nombre'] ?? d['title'] ?? '').toString(),
        description: (d['descripcion'] ?? d['description'])?.toString(),
        venue: (d['lugarGeneral'] ?? d['venue'])?.toString(),
        status: (d['estado'] ?? d['status'] ?? EventStatus.draft).toString(),
        startAt: _toDate(d['fechaInicio'] ?? d['startAt']),
        endAt: _toDate(d['fechaFin'] ?? d['endAt']),
      );
      
      // Actualizar cache
      _cache[id] = event;
      _lastCacheUpdate = DateTime.now();
      
      AppLogger.success('Evento $id obtenido exitosamente');
      return event;
    } catch (e, st) {
      AppLogger.error('Error al obtener evento $id', e, st);
      throw ErrorHandler.logAndHandle(e, st);
    }
  }

  /// Guardar o actualizar un evento (admin)
  /// 
  /// Si [id] es null o vacío, crea un nuevo evento.
  /// Si [id] existe, actualiza el evento existente.
  Future<void> upsert(String? id, EventModel model) async {
    try {
      final data = {
        'nombre': model.title,
        'descripcion': model.description,
        'lugarGeneral': model.venue,
        'estado': model.status,
        'fechaInicio': model.startAt,
        'fechaFin': model.endAt,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null || id.isEmpty) {
        AppLogger.info('Creando nuevo evento: ${model.title}');
        await _db.collection(FirestoreCollections.events).add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        AppLogger.success('Evento creado: ${model.title}');
      } else {
        AppLogger.info('Actualizando evento $id');
        await _db
            .collection(FirestoreCollections.events)
            .doc(id)
            .set(data, SetOptions(merge: true));
        
        // Invalidar cache
        _cache.remove(id);
        AppLogger.success('Evento actualizado: ${model.title}');
      }
    } catch (e, st) {
      AppLogger.error('Error al guardar evento', e, st);
      throw ErrorHandler.logAndHandle(e, st);
    }
  }
  
  /// Limpiar cache manualmente
  void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
    AppLogger.debug('Cache de eventos limpiado');
  }

  /// Escuchar cambios en un evento junto con sus sesiones en tiempo real
  /// 
  /// Retorna un Stream que emite un [EventView] cada vez que el evento
  /// o sus sesiones cambian en Firestore.
  Stream<EventView> watchEventWithSessions(String eventId) async* {
    try {
      AppLogger.info('Iniciando stream para evento $eventId');
      
      await for (final evSnap in _db
          .collection(FirestoreCollections.events)
          .doc(eventId)
          .snapshots()) {
        
        if (!evSnap.exists) {
          AppLogger.warning('Evento $eventId no existe en stream');
          yield EventView(
            id: eventId,
            name: '',
            venue: null,
            start: null,
            end: null,
            sessions: const [],
            organizers: const [],
          );
          continue;
        }

        try {
          // Cargar las sesiones (ponencias) del evento
          final sesQS = await _db
              .collection(FirestoreCollections.events)
              .doc(eventId)
              .collection(FirestoreCollections.sessions)
              .orderBy('horaInicio', descending: false)
              .get(const GetOptions(source: Source.serverAndCache));

          final d = evSnap.data() as Map<String, dynamic>;
          final sessions = sesQS.docs.map((s) {
            final sd = s.data();
            return SessionView(
              id: s.id,
              titulo: (sd['titulo'] ?? '').toString(),
              ponenteNombre: (sd['ponenteNombre'] ?? '').toString(),
              dia: (sd['dia'] ?? '').toString(),
              horaInicio: (sd['horaInicio'] as Timestamp?) ?? Timestamp.now(),
              horaFin: (sd['horaFin'] as Timestamp?) ?? Timestamp.now(),
              modalidad: (sd['modalidad'] ?? SessionModality.inPerson).toString(),
              sala: (sd['sala'] ?? '').toString(),
              link: (sd['link'] ?? '').toString(),
            );
          }).toList();

 final organizers = ((d['organizers'] as List?) ?? const [])
              .map((raw) => EventOrganizerView.fromMap(raw))
              .where((o) => o.isValid)
              .toList();
          yield EventView(
            id: evSnap.id,
            name: (d['nombre'] ?? d['title'] ?? '').toString(),
            venue: (d['lugarGeneral'] ?? d['venue'])?.toString(),
            start: _toDate(d['fechaInicio'] ?? d['startAt']),
            end: _toDate(d['fechaFin'] ?? d['endAt']),
            sessions: sessions,
              organizers: organizers,
          );
        } catch (e, st) {
          AppLogger.error('Error al cargar sesiones del evento $eventId', e, st);
          // Emitir evento sin sesiones en caso de error
          final d = evSnap.data() as Map<String, dynamic>;
          yield EventView(
            id: evSnap.id,
            name: (d['nombre'] ?? d['title'] ?? '').toString(),
            venue: (d['lugarGeneral'] ?? d['venue'])?.toString(),
            start: _toDate(d['fechaInicio'] ?? d['startAt']),
            end: _toDate(d['fechaFin'] ?? d['endAt']),
            sessions: const [],
             organizers: ((d['organizers'] as List?) ?? const [])
                .map((raw) => EventOrganizerView.fromMap(raw))
                .where((o) => o.isValid)
                .toList(),
          );
        }
      }
    } catch (e, st) {
      AppLogger.error('Error en stream de evento $eventId', e, st);
      rethrow;
    }
  }
}

/// 🔸 Modelo simplificado para la vista del evento en detalle (solo lectura)
class EventView {
  final String id;
  final String name;
  final String? venue;
  final DateTime? start;
  final DateTime? end;
  final List<SessionView> sessions;
  final List<EventOrganizerView> organizers;

  EventView({
    required this.id,
    required this.name,
    required this.venue,
    required this.start,
    required this.end,
    required this.sessions,
    required this.organizers,
  });
}

class EventOrganizerView {
  final String uid;
  final String email;
  final String displayName;

  EventOrganizerView({
    required this.uid,
    required this.email,
    required this.displayName,
  });
   factory EventOrganizerView.fromMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return EventOrganizerView(
        uid: (raw['uid'] ?? raw['id'] ?? '').toString(),
        email: (raw['email'] ?? '').toString(),
        displayName:
            (raw['displayName'] ?? raw['nombre'] ?? raw['email'] ?? '').toString(),
      );
    }
    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      return EventOrganizerView(
        uid: (map['uid'] ?? map['id'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        displayName:
            (map['displayName'] ?? map['nombre'] ?? map['email'] ?? '').toString(),
      );
    }
    return EventOrganizerView(uid: '', email: '', displayName: '');
  }

  bool get isValid => uid.isNotEmpty;
}

/// 🔸 Modelo de cada ponencia o sesión
class SessionView {
  final String id;
  final String titulo;
  final String ponenteNombre;
  final String dia;
  final Timestamp horaInicio;
  final Timestamp horaFin;
  final String modalidad;
  final String? sala;
  final String? link;

  SessionView({
    required this.id,
    required this.titulo,
    required this.ponenteNombre,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.modalidad,
    this.sala,
    this.link,
  });
}
