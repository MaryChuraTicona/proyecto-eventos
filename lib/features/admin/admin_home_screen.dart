import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/error_handler.dart';
import '../../core/constants.dart';
import 'forms/event_form.dart';
import 'forms/session_form.dart';
import 'forms/speaker_form.dart';
import 'forms/user_form.dart';

import 'models/admin_event_model.dart';
import 'models/admin_session_model.dart';
import 'models/admin_speaker_model.dart';

import 'services/admin_event_service.dart';
import 'services/admin_session_service.dart';
import 'services/admin_speaker_service.dart';
import 'services/admin_seed_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _Tab { dashboard, eventos, ponencias, ponentes, usuarios, reportes }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  _Tab _tab = _Tab.dashboard;

  // Estado compartido
  final _eventSvc = AdminEventService();
  final _sesSvc   = AdminSessionService();
  final _spkSvc   = AdminSpeakerService();

  String? _selectedEventGroup; // para filtrar Ponencias por grupo de eventos

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel — Admin EPIS'),
        actions: [
          IconButton(
            tooltip: 'Sembrar datos demo',
            onPressed: () async {
              await AdminSeedService.bootstrapFirestore();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datos demo creados.')),
              );
            },
            icon: const Icon(Icons.auto_fix_high_rounded),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.admin_panel_settings, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => setState(() => _tab = _Tab.values[i]),
            extended: wide,
            labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Tooltip(
                message: FirebaseAuth.instance.currentUser?.email ?? '',
                child: const Icon(Icons.account_circle_rounded),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined),  label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.event_rounded),       label: Text('Eventos')),
              NavigationRailDestination(icon: Icon(Icons.schedule_rounded),    label: Text('Ponencias')),
              NavigationRailDestination(icon: Icon(Icons.record_voice_over),   label: Text('Ponentes')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_rounded),  label: Text('Usuarios')),
              NavigationRailDestination(icon: Icon(Icons.bar_chart_rounded),   label: Text('Reportes')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tab) {
                _Tab.dashboard => _Dashboard(key: ValueKey(_tab), cs: cs),
                _Tab.eventos   => _EventosTab(key: ValueKey(_tab), eventSvc: _eventSvc),
                _Tab.ponencias => _PonenciasTab(
                  key: ValueKey(_tab),
                  eventSvc: _eventSvc,
                  sesSvc: _sesSvc,
                  selectedEventGroup: _selectedEventGroup,
                  onSelectEventGroup: (group) => setState(() => _selectedEventGroup = group),
                ),
                _Tab.ponentes  => _PonentesTab(key: ValueKey(_tab), spkSvc: _spkSvc),
                _Tab.usuarios  => _UsuariosTab(key: ValueKey(_tab)),
                _Tab.reportes  => _ReportesTab(key: ValueKey(_tab)),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- DASHBOARD ---------------- */

class _Dashboard extends StatelessWidget {
  final ColorScheme cs;
  const _Dashboard({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    final card = (String title, IconData icon, Stream<int> stream, Color color) => StreamBuilder<int>(
      stream: stream,
      builder: (_, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return _MetricCard(
            title: title,
            value: 0,
            icon: icon,
            color: color,
            isLoading: true,
          );
        }
        if (s.hasError) {
          AppLogger.error('Error en $title', s.error, StackTrace.current);
          return _MetricCard(
            title: title,
            value: 0,
            icon: icon,
            color: color,
            hasError: true,
          );
        }
        return _MetricCard(
          title: title,
          value: s.data ?? 0,
          icon: icon,
          color: color,
        );
      },
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado compacto
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Resumen del sistema',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          
          // Grid de métricas más compacto
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth;
              final crossAxisCount = cardWidth > 1200 ? 4 : (cardWidth > 600 ? 2 : 1);
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cardWidth > 600 ? 2.5 : 2.2,
                children: [
                  card('Eventos Activos', Icons.event_rounded, 
                    _count('eventos', where: ['estado','==','activo']), 
                    const Color(0xFF6366F1)), // Indigo
                  card('Ponencias', Icons.school_rounded, 
                    _countNested('eventos','sesiones'), 
                    const Color(0xFF10B981)), // Green
                  card('Ponentes', Icons.record_voice_over_rounded, 
                    _count('ponentes'), 
                    const Color(0xFFF59E0B)), // Amber
                  card('Usuarios', Icons.people_alt_rounded, 
                    _count('usuarios'), 
                    const Color(0xFFEC4899)), // Pink
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Sección de Estudiantes por Facultad
          Text(
            'Estudiantes por Facultad',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribución de estudiantes UPT',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          
          _FacultyMetrics(key: UniqueKey()),
        ],
      ),
    );
  }

  Stream<int> _count(String col, {List<Object>? where}) {
    final colRef = FirebaseFirestore.instance.collection(col);
    final q = (where != null && where.length == 3)
        ? colRef.where(where[0] as String, isEqualTo: where[2])
        : colRef;
    return q.snapshots().map((s) => s.size);
  }

  Stream<int> _countNested(String parentCol, String childCol) {
    // Escucha cambios en la colección padre y cuenta todas las sesiones en paralelo
    return FirebaseFirestore.instance
        .collection(parentCol)
        .snapshots()
        .asyncMap((parentSnapshot) async {
      if (parentSnapshot.docs.isEmpty) {
        AppLogger.warning('No hay documentos en $parentCol');
        return 0;
      }

      try {
        // Crear todas las consultas de conteo en paralelo
        final countFutures = parentSnapshot.docs.map((doc) {
          return doc.reference
              .collection(childCol)
              .get()
              .then((snapshot) => snapshot.docs.length);
        }).toList();

        // Esperar a que todas terminen
        final counts = await Future.wait(countFutures);
        final total = counts.fold<int>(0, (sum, count) => sum + count);

        AppLogger.success('Total de $childCol: $total (de ${parentSnapshot.docs.length} $parentCol)');
        return total;
      } catch (e, st) {
        AppLogger.error('Error contando $childCol', e, st);
        return 0;
      }
    });
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool hasError;
  
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.hasError = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icono compacto
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            icon,
                            color: color,
                            size: 24,
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Valor y título en columna
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Valor
                        if (hasError)
                          Text(
                            'Error',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: cs.error,
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  height: 1,
                                ),
                              ),
                              if (isLoading) ...[
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: color.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        
                        const SizedBox(height: 2),
                        
                        // Título
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- FACULTY METRICS ---------------- */

class _FacultyMetrics extends StatelessWidget {
  const _FacultyMetrics({super.key});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: UniqueKey(), // Forzar reconstrucción del StreamBuilder
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        // Filtrar solo estudiantes
        final students = allDocs.where((doc) {
          final data = doc.data();
          final roleField = data['role'] ?? data['rol'] ?? '';
          final email = data['email']?.toString() ?? 'sin email';
          
          String role = roleField.toString().toLowerCase();
          
          // Si no tiene rol, inferir por dominio del email
          if (role.isEmpty) {
            if (email.endsWith('@virtual.upt.pe')) {
              role = 'student'; // Asignar estudiante automáticamente
              AppLogger.warning('⚠️ Usuario SIN ROL detectado como ESTUDIANTE por dominio: $email');
            } else if (email.endsWith('@upt.pe')) {
              role = 'teacher'; // Asignar docente automáticamente
              AppLogger.warning('⚠️ Usuario SIN ROL detectado como DOCENTE por dominio: $email');
            } else {
              AppLogger.warning('⚠️ Usuario SIN ROL (dominio desconocido): $email');
            }
          }
          
          final isStudent = role == 'estudiante' || role == 'student';
          
          // Debug
          if (roleField.toString().isEmpty) {
            AppLogger.debug('📊 Usuario: $email - Rol INFERIDO: "$role" - Es estudiante: $isStudent');
          } else {
            AppLogger.debug('📊 Usuario: $email - Rol en BD: "$roleField" - Es estudiante: $isStudent');
          }
          
          return isStudent;
        }).toList();
        
        // Contar estudiantes por facultad
        final Map<String, int> facultyCounts = {};
        int withoutFaculty = 0;
        
        for (final doc in students) {
          final data = doc.data();
          final faculty = data['faculty']?.toString();
          
          if (faculty == null || faculty.isEmpty) {
            withoutFaculty++;
          } else {
            facultyCounts[faculty] = (facultyCounts[faculty] ?? 0) + 1;
          }
        }
        
        final total = students.length;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Totales
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, 
                      color: Theme.of(context).colorScheme.primary, 
                      size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de Estudiantes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (withoutFaculty > 0)
                      Chip(
                        avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                        label: Text('$withoutFaculty sin facultad'),
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Grid de facultades
            if (facultyCounts.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 
                                 MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3,
                ),
                itemCount: Faculties.all.length,
                itemBuilder: (context, index) {
                  final facultyCode = Faculties.all[index];
                  final count = facultyCounts[facultyCode] ?? 0;
                  final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
                  final facultyName = Faculties.getFullName(facultyCode);
                  
                  return Card(
                    elevation: 0,
                    color: count > 0 
                      ? _getFacultyColor(facultyCode).withOpacity(0.05)
                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: count > 0 
                          ? _getFacultyColor(facultyCode).withOpacity(0.3)
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getFacultyColor(facultyCode).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getFacultyIcon(facultyCode),
                              color: _getFacultyColor(facultyCode),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  facultyCode,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  facultyName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getFacultyColor(facultyCode),
                                ),
                              ),
                              Text(
                                '$percentage%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
  
  Color _getFacultyColor(String code) {
    switch (code) {
      case Faculties.faing:
        return const Color(0xFF3B82F6); // Blue
      case Faculties.fade:
        return const Color(0xFF8B5CF6); // Purple
      case Faculties.facem:
        return const Color(0xFF10B981); // Green
      case Faculties.facsa:
        return const Color(0xFFEF4444); // Red
      case Faculties.faedcoh:
        return const Color(0xFFF59E0B); // Amber
      case Faculties.fau:
        return const Color(0xFF06B6D4); // Cyan
      default:
        return Colors.grey;
    }
  }
  
  IconData _getFacultyIcon(String code) {
    switch (code) {
      case Faculties.faing:
        return Icons.engineering_rounded;
      case Faculties.fade:
        return Icons.gavel_rounded;
      case Faculties.facem:
        return Icons.business_center_rounded;
      case Faculties.facsa:
        return Icons.medical_services_rounded;
      case Faculties.faedcoh:
        return Icons.menu_book_rounded;
      case Faculties.fau:
        return Icons.architecture_rounded;
      default:
        return Icons.school_rounded;
    }
  }
}

/* ---------------- EVENTOS ---------------- */

class _EventosTab extends StatelessWidget {
  final AdminEventService eventSvc;
  const _EventosTab({super.key, required this.eventSvc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _Toolbar(
          title: 'Eventos',
          onAdd: () => showDialog(context: context, builder: (_) => const EventFormDialog()),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AdminEventModel>>(
            stream: eventSvc.streamAll(),
            builder: (_, s) {
              final items = s.data ?? const [];
              if (s.hasError) return _empty('Error: ${s.error}');
              if (items.isEmpty) return _empty('Sin eventos. Crea el primero.');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${e.tipo} • ${e.lugarGeneral} • ${e.estado.toUpperCase()}'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => EventFormDialog(existing: e),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () async {
                              await eventSvc.delete(e.id);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: items.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ---------------- PONENCIAS ---------------- */

class _PonenciasTab extends StatelessWidget {
  final AdminEventService eventSvc;
  final AdminSessionService sesSvc;
  final String? selectedEventGroup;
  final ValueChanged<String?> onSelectEventGroup;

  const _PonenciasTab({
    super.key,
    required this.eventSvc,
    required this.sesSvc,
    required this.selectedEventGroup,
    required this.onSelectEventGroup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _Toolbar(
          title: 'Ponencias',
          actionBuilder: (ctx) => StreamBuilder<List<AdminEventModel>>(
            stream: eventSvc.streamAll(),
            builder: (ctx, s) {
              final allEvents = s.data ?? const [];
              
              // Agrupar eventos por nombre base (sin años ni ediciones)
              final eventGroups = <String, List<AdminEventModel>>{};
              for (final event in allEvents) {
                // Extraer el nombre base eliminando años, números y palabras comunes
                final groupName = _extractBaseName(event.nombre);
                eventGroups.putIfAbsent(groupName, () => []).add(event);
              }
              
              // Obtener lista de grupos ordenada (case-insensitive)
              final groups = eventGroups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              
              // Validar que el grupo seleccionado existe en la lista
              // Si no existe, buscar uno que coincida case-insensitive o establecer a null
              String? validatedSelection = selectedEventGroup;
              if (selectedEventGroup != null && !groups.contains(selectedEventGroup)) {
                // Buscar coincidencia case-insensitive
                validatedSelection = groups.firstWhere(
                  (g) => g.toLowerCase() == selectedEventGroup!.toLowerCase(),
                  orElse: () => '',
                );
                if (validatedSelection.isEmpty) {
                  validatedSelection = null;
                }
                // Si encontramos uno diferente, actualizamos el estado
                if (validatedSelection != selectedEventGroup) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSelectEventGroup(validatedSelection);
                  });
                }
              }
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: validatedSelection,
                      items: groups.map((groupName) {
                        final eventsInGroup = eventGroups[groupName]!;
                        final eventCount = eventsInGroup.length;
                        final activeCount = eventsInGroup.where((e) => e.estado == 'activo').length;
                        
                        return DropdownMenuItem(
                          value: groupName,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  groupName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  eventCount == 1 
                                    ? '1 evento' 
                                    : '$eventCount eventos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: onSelectEventGroup,
                      decoration: const InputDecoration(
                        labelText: 'Grupo de Eventos',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      hint: const Text('Selecciona un grupo de eventos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: validatedSelection == null
                        ? null
                        : () => showDialog(
                              context: context,
                              builder: (_) => const SessionFormDialog(),
                            ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva ponencia'),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selectedEventGroup == null
              ? _empty('Selecciona un grupo de eventos para ver sus ponencias.')
              : StreamBuilder<List<AdminEventModel>>(
                  stream: eventSvc.streamAll(),
                  builder: (ctx, eventSnapshot) {
                    if (eventSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final allEvents = eventSnapshot.data ?? const [];
                    AppLogger.debug('📊 Total eventos: ${allEvents.length}');
                    AppLogger.debug('🔍 Grupo seleccionado: $selectedEventGroup');
                    
                    // Filtrar eventos del grupo seleccionado usando nombre base (case-insensitive)
                    final eventsInGroup = allEvents
                        .where((e) {
                          final baseName = _extractBaseName(e.nombre);
                          final match = baseName.toLowerCase() == selectedEventGroup?.toLowerCase();
                          AppLogger.debug('   Evento "${e.nombre}" -> base: "$baseName" (match: $match)');
                          return match;
                        })
                        .toList();
                    
                    AppLogger.info('✅ Eventos en grupo "$selectedEventGroup": ${eventsInGroup.length}');
                    if (eventsInGroup.isNotEmpty) {
                      for (final e in eventsInGroup) {
                        AppLogger.debug('   - ${e.nombre} (ID: ${e.id})');
                      }
                    }
                    
                    if (eventsInGroup.isEmpty) {
                      return _empty('No se encontraron eventos en este grupo.');
                    }
                    
                    // Obtener IDs de todos los eventos del grupo
                    final eventIds = eventsInGroup.map((e) => e.id).toList();
                    AppLogger.info('🎯 IDs de eventos a consultar: $eventIds');
                    
                    // Combinar ponencias de todos los eventos del grupo
                    return _GroupSessionsView(
                      sesSvc: sesSvc,
                      eventIds: eventIds,
                      groupName: selectedEventGroup!,
                      cs: cs,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Widget que muestra todas las ponencias de múltiples eventos agrupados
class _GroupSessionsView extends StatelessWidget {
  final AdminSessionService sesSvc;
  final List<String> eventIds;
  final String groupName;
  final ColorScheme cs;

  const _GroupSessionsView({
    required this.sesSvc,
    required this.eventIds,
    required this.groupName,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('🎬 _GroupSessionsView build con ${eventIds.length} eventos');
    
    // Si no hay eventos, mostrar mensaje
    if (eventIds.isEmpty) {
      return _empty('No hay eventos en este grupo.');
    }
    
    // Si solo hay un evento, usar stream directo (más simple)
    if (eventIds.length == 1) {
      return StreamBuilder<List<AdminSessionModel>>(
        stream: sesSvc.streamByEvent(eventIds.first),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            AppLogger.error('❌ Error en stream de sesiones', snapshot.error, StackTrace.current);
            return _empty('Error: ${snapshot.error}');
          }
          
          final allSessions = snapshot.data ?? [];
          AppLogger.debug('📋 Sesiones recibidas: ${allSessions.length}');
          
          if (allSessions.isEmpty) {
            return _empty('Sin ponencias para "$groupName".\nAgrega la primera ponencia.');
          }
          
          // Ordenar por fecha/hora de inicio
          allSessions.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
          
          return _buildSessionList(context, allSessions);
        },
      );
    }
    
    // Para múltiples eventos, combinar streams
    final streams = eventIds.map((id) => sesSvc.streamByEvent(id)).toList();
    
    return StreamBuilder<List<List<AdminSessionModel>>>(
      stream: _combineStreams(streams),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          AppLogger.error('❌ Error combinando streams', snapshot.error, StackTrace.current);
          return _empty('Error: ${snapshot.error}');
        }
        
        // Combinar todas las ponencias
        final allSessions = <AdminSessionModel>[];
        for (final sessionList in snapshot.data ?? []) {
          allSessions.addAll(sessionList);
        }
        
        AppLogger.debug('📋 Total sesiones combinadas: ${allSessions.length}');
        
        // Ordenar por fecha/hora de inicio
        allSessions.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
        
        if (allSessions.isEmpty) {
          return _empty('Sin ponencias para "$groupName".\nAgrega la primera ponencia.');
        }
        
        return _buildSessionList(ctx, allSessions);
      },
    );
  }
  
  Widget _buildSessionList(BuildContext context, List<AdminSessionModel> allSessions) {
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final p = allSessions[i];
            final rango = '${_fmt(p.horaInicio)} – ${_fmt(p.horaFin)}';
            
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.school, color: cs.onPrimaryContainer),
                ),
                title: Text(
                  p.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('👤 ${p.ponenteNombre}'),
                    Text('📍 ${p.modalidad} • ${p.dia} • $rango'),
                  ],
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => SessionFormDialog(existing: p),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirmar eliminación'),
                            content: Text('¿Eliminar la ponencia "${p.titulo}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          await sesSvc.delete(p.eventoId, p.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Ponencia eliminada')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: allSessions.length,
        );
  }
  
  // Combinar múltiples streams en uno solo
  // Esta implementación escucha cambios en cualquier stream y re-emite todos los datos
  Stream<List<List<AdminSessionModel>>> _combineStreams(
    List<Stream<List<AdminSessionModel>>> streams,
  ) async* {
    if (streams.isEmpty) {
      yield [];
      return;
    }
    
    // Mantener el último valor de cada stream
    final List<List<AdminSessionModel>?> latestValues = List.filled(streams.length, null);
    final controller = StreamController<List<List<AdminSessionModel>>>();
    final subscriptions = <StreamSubscription>[];
    
    // Función para emitir el estado combinado cuando todos los streams han emitido al menos una vez
    void emitCombined() {
      if (latestValues.every((v) => v != null)) {
        controller.add(latestValues.cast<List<AdminSessionModel>>().toList());
      }
    }
    
    // Escuchar cada stream
    for (int i = 0; i < streams.length; i++) {
      final subscription = streams[i].listen(
        (data) {
          latestValues[i] = data;
          emitCombined();
        },
        onError: (error) {
          AppLogger.error('Error en stream $i', error, StackTrace.current);
          controller.addError(error);
        },
      );
      subscriptions.add(subscription);
    }
    
    // Emitir los valores del controller
    try {
      await for (final value in controller.stream) {
        yield value;
      }
    } finally {
      // Cancelar todas las suscripciones al terminar
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    }
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// Extrae el nombre base de un evento eliminando años, ediciones y números
/// 
/// Ejemplos:
/// - "CATEC 2025" → "CATEC"
/// - "CATEC 2024" → "CATEC"
/// - "Microsoft 2023" → "Microsoft"
/// - "Software Libre - Edición 5" → "Software Libre"
String _extractBaseName(String eventName) {
  // Si el nombre es muy corto (menos de 3 caracteres), no procesarlo
  if (eventName.trim().length < 3) {
    return eventName.trim();
  }
  
  String cleaned = eventName;
  
  // Eliminar años (2020-2099) solo si no es todo el nombre
  final withoutYear = cleaned.replaceAll(RegExp(r'\b20\d{2}\b'), '').trim();
  if (withoutYear.isNotEmpty && withoutYear.length >= 2) {
    cleaned = withoutYear;
  }
  
  // Eliminar palabras comunes de edición solo si quedan palabras después
  final withoutEdition = cleaned.replaceAll(
    RegExp(r'\b(Edición|Edition|Ed\.|Vol\.|Volumen)\s*\d*\b', caseSensitive: false), 
    ''
  ).trim();
  if (withoutEdition.isNotEmpty && withoutEdition.length >= 2) {
    cleaned = withoutEdition;
  }
  
  // Eliminar números romanos al final (I, II, III, IV, V, etc.) solo si quedan palabras
  final withoutRoman = cleaned.replaceAll(RegExp(r'\b[IVX]+\s*$'), '').trim();
  if (withoutRoman.isNotEmpty && withoutRoman.length >= 2) {
    cleaned = withoutRoman;
  }
  
  // Eliminar números simples al final (1, 2, 3, etc.) solo si quedan palabras
  final withoutNumbers = cleaned.replaceAll(RegExp(r'\s+\d+\s*$'), '').trim();
  if (withoutNumbers.isNotEmpty && withoutNumbers.length >= 2) {
    cleaned = withoutNumbers;
  }
  
  // Eliminar guiones, puntos y espacios extra al final
  cleaned = cleaned.replaceAll(RegExp(r'[\s\-\.]+$'), '').trim();
  
  // Si quedó vacío o muy corto después de todo el procesamiento, devolver el nombre original
  if (cleaned.isEmpty || cleaned.length < 2) {
    return eventName.trim();
  }
  
  return cleaned;
}

/* ---------------- PONENTES ---------------- */

class _PonentesTab extends StatelessWidget {
  final AdminSpeakerService spkSvc;
  const _PonentesTab({super.key, required this.spkSvc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _Toolbar(
          title: 'Ponentes',
          onAdd: () => showDialog(context: context, builder: (_) => const SpeakerFormDialog()),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<AdminSpeakerModel>>(
            stream: spkSvc.streamAll(),
            builder: (_, s) {
              final items = s.data ?? const [];
              if (s.hasError) return _empty('Error: ${s.error}');
              if (items.isEmpty) return _empty('Sin ponentes.');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.person_rounded, color: cs.onPrimaryContainer),
                      ),
                      title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.institucion.isNotEmpty || p.contacto.isNotEmpty)
                            Text([p.institucion, p.contacto].where((e) => e.isNotEmpty).join(' • ')),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Registrado: ${_formatDateTime(p.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => SpeakerFormDialog(existing: p),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () async {
                              await spkSvc.delete(p.id);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponente eliminado')));
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: items.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ---------------- USUARIOS ---------------- */

class _UsuariosTab extends StatefulWidget {
  const _UsuariosTab({super.key});

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  String? _filtroRol;
  String? _filtroFacultad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _Toolbar(
          title: 'Usuarios',
          actionBuilder: (_) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filtro por Rol
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: DropdownButtonFormField<String>(
                  value: _filtroRol,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'admin', child: Text('Admins', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'estudiante', child: Text('Estudiantes', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'docente', child: Text('Docentes', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'ponente', child: Text('Ponentes', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _filtroRol = v),
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Filtro por Facultad
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: DropdownButtonFormField<String>(
                  value: _filtroFacultad,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas', overflow: TextOverflow.ellipsis)),
                    ...Faculties.all.map((code) => DropdownMenuItem(
                      value: code,
                      child: Text(code, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setState(() => _filtroFacultad = v),
                  decoration: const InputDecoration(
                    labelText: 'Facultad',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.school_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, s) {
              if (s.hasError) return _empty('Error: ${s.error}');
              
              var docs = s.data?.docs ?? const [];
              
              // Filtrar por rol si hay filtro activo
              if (_filtroRol != null) {
                docs = docs.where((d) {
                  final data = d.data();
                  final rol = (data['rol'] ?? data['role'] ?? '').toString().toLowerCase();
                  
                  // Normalizar rol: manejar tanto español como inglés
                  String normalizedRole = rol;
                  if (rol == 'student') normalizedRole = 'estudiante';
                  if (rol == 'teacher') normalizedRole = 'docente';
                  if (rol == 'speaker') normalizedRole = 'ponente';
                  
                  return normalizedRole == _filtroRol;
                }).toList();
              }
              
              // Filtrar por facultad si hay filtro activo
              if (_filtroFacultad != null) {
                docs = docs.where((d) {
                  final data = d.data();
                  final faculty = data['faculty']?.toString() ?? '';
                  return faculty == _filtroFacultad;
                }).toList();
              }
              
              if (docs.isEmpty) {
                final filters = [
                  if (_filtroRol != null) 'rol "$_filtroRol"',
                  if (_filtroFacultad != null) 'facultad "$_filtroFacultad"',
                ];
                return _empty(filters.isEmpty 
                  ? 'Sin usuarios.' 
                  : 'No hay usuarios con ${filters.join(" y ")}.');
              }
              
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final d = doc.data();
                  final email = d['email']?.toString() ?? '';
                  final rolRaw = d['rol'] ?? d['role']; // Puede ser null
                  final hasRoleInDB = rolRaw != null && rolRaw.toString().isNotEmpty;
                  final rol = (rolRaw ?? 'student').toString();
                  final active = d['active'] == true;
                  final displayName = d['displayName']?.toString() ?? '';
                  final faculty = d['faculty']?.toString();
                  
                  // Determinar color según rol
                  final Color roleColor;
                  final IconData roleIcon;
                  switch (rol.toLowerCase()) {
                    case 'admin':
                      roleColor = Colors.red;
                      roleIcon = Icons.admin_panel_settings;
                      break;
                    case 'teacher':
                      roleColor = Colors.blue;
                      roleIcon = Icons.school;
                      break;
                    case 'speaker':
                      roleColor = Colors.purple;
                      roleIcon = Icons.mic;
                      break;
                    default:
                      roleColor = Colors.green;
                      roleIcon = Icons.person;
                  }
                  
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: roleColor.withOpacity(0.2),
                        child: Icon(roleIcon, color: roleColor, size: 20),
                      ),
                      title: Text(
                        email,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(displayName, style: const TextStyle(fontSize: 12)),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              // Badge de rol
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _translateRole(rol).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                              
                              // Badge de advertencia: Sin rol en BD
                              if (!hasRoleInDB)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SIN ROL EN BD',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Badge de facultad (si tiene)
                              if (faculty != null && faculty.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.school, size: 10, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        faculty,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Estado activo/inactivo
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    active ? Icons.check_circle : Icons.cancel,
                                    size: 16,
                                    color: active ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    active ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: active ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'admin', child: Text('👑 Hacer Admin')),
                          const PopupMenuItem(value: 'student', child: Text('🎓 Hacer Estudiante')),
                          const PopupMenuItem(value: 'teacher', child: Text('👨‍🏫 Hacer Docente')),
                          const PopupMenuItem(value: 'speaker', child: Text('🎤 Hacer Ponente')),
                          const PopupMenuItem(value: 'divider1', child: Divider()),
                          const PopupMenuItem(value: 'change-faculty', child: Text('🏛️ Cambiar Facultad')),
                          const PopupMenuItem(value: 'divider2', child: Divider()),
                          PopupMenuItem(
                            value: active ? 'deactivate' : 'activate',
                            child: Text(active ? '🚫 Desactivar' : '✅ Activar'),
                          ),
                        ],
                        onSelected: (action) async {
                          if (action == 'activate' || action == 'deactivate') {
                            await _toggleUserActive(doc.id, action == 'activate');
                          } else if (action == 'change-faculty') {
                            await _changeFaculty(context, doc.id, email, faculty);
                          } else if (action != 'divider1' && action != 'divider2') {
                            await _changeUserRole(context, doc.id, email, rol, action);
                          }
                        },
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: docs.length,
              );
            },
          ),
        ),
      ],
    );
  }
  
  Future<void> _changeUserRole(BuildContext context, String userId, String email, String currentRole, String newRole) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar Rol'),
        content: Text('¿Cambiar rol de $email de "$currentRole" a "$newRole"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('usuarios').doc(userId).update({
          'role': newRole,
          'rol': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Rol actualizado a $newRole')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _toggleUserActive(String userId, bool activate) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(userId).update({
      'active': activate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> _changeFaculty(BuildContext context, String userId, String email, String? currentFaculty) async {
    String? selectedFaculty = currentFaculty;
    
    final confirmed = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar Facultad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selecciona la facultad para $email:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFaculty,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Facultad',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin facultad')),
                  ...Faculties.all.map((code) => DropdownMenuItem(
                    value: code,
                    child: Text('$code - ${Faculties.getFullName(code)}'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFaculty = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedFaculty),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed != null && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('usuarios').doc(userId).update({
          'faculty': confirmed.isEmpty ? FieldValue.delete() : confirmed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirmed.isEmpty 
                ? '✅ Facultad eliminada' 
                : '✅ Facultad actualizada a $confirmed'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e')),
          );
        }
      }
    }
  }
}

/* ---------------- REPORTES ---------------- */

class _ReportesTab extends StatefulWidget {
  const _ReportesTab({super.key});
  
  @override
  State<_ReportesTab> createState() => _ReportesTabState();
}

class _ReportesTabState extends State<_ReportesTab> {
  String? _selectedFacultyForExport;
  String? _selectedRoleForExport;
  bool _isExporting = false;
  bool _showPreview = false;
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Text(
            'Reportes y Exportación',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Genera y descarga reportes de usuarios',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          
          // Card de exportación de usuarios
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          color: cs.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exportar Lista de Usuarios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Descarga un archivo CSV con información de usuarios',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  // Filtros
                  Text(
                    'Filtros de exportación:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      // Filtro por Rol
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRoleForExport,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Rol',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: cs.surfaceVariant.withOpacity(0.3),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos los roles')),
                            DropdownMenuItem(value: UserRoles.admin, child: const Text('Administradores')),
                            DropdownMenuItem(value: UserRoles.student, child: const Text('Estudiantes')),
                            DropdownMenuItem(value: UserRoles.teacher, child: const Text('Docentes')),
                            DropdownMenuItem(value: UserRoles.speaker, child: const Text('Ponentes')),
                          ],
                          onChanged: (v) => setState(() => _selectedRoleForExport = v),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Filtro por Facultad
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFacultyForExport,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Facultad',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.school_outlined),
                            filled: true,
                            fillColor: cs.surfaceVariant.withOpacity(0.3),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todas las facultades')),
                            ...Faculties.all.map((code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            )),
                            const DropdownMenuItem(value: '_none', child: Text('Sin facultad')),
                          ],
                          onChanged: (v) => setState(() => _selectedFacultyForExport = v),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botón de vista previa
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _showPreview = !_showPreview);
                          },
                          icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
                          label: Text(_showPreview ? 'Ocultar Vista Previa' : 'Mostrar Vista Previa'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isExporting ? null : _exportUsers,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(_isExporting ? 'Descargando...' : 'Descargar CSV'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Vista previa de la tabla
          if (_showPreview)
            _buildPreviewTable(cs),
          
          if (!_showPreview)
            // Información adicional
            Card(
              elevation: 0,
              color: cs.primaryContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El archivo CSV incluirá: Email, Nombre, Rol, Facultad, Estado y Fecha de registro.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewTable(ColorScheme cs) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        var users = snapshot.data?.docs ?? [];

        // Aplicar filtros
        if (_selectedRoleForExport != null) {
          users = users.where((doc) {
            final data = doc.data();
            final role = (data['role'] ?? data['rol'] ?? '').toString().toLowerCase();
            
            // Normalizar rol: manejar tanto español como inglés
            String normalizedRole = role;
            if (role == 'student') normalizedRole = 'estudiante';
            if (role == 'teacher') normalizedRole = 'docente';
            if (role == 'speaker') normalizedRole = 'ponente';
            
            return normalizedRole == _selectedRoleForExport;
          }).toList();
        }

        if (_selectedFacultyForExport != null) {
          if (_selectedFacultyForExport == '_none') {
            users = users.where((doc) {
              final data = doc.data();
              final faculty = data['faculty']?.toString() ?? '';
              return faculty.isEmpty;
            }).toList();
          } else {
            users = users.where((doc) {
              final data = doc.data();
              final faculty = data['faculty']?.toString() ?? '';
              return faculty == _selectedFacultyForExport;
            }).toList();
          }
        }

        if (users.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No hay usuarios que coincidan con los filtros',
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Vista Previa - ${users.length} ${users.length == 1 ? 'usuario' : 'usuarios'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tabla
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 96,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      cs.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Facultad', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Fecha de Registro', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: users.map((doc) {
                      final data = doc.data();
                      final email = data['email']?.toString() ?? '';
                      final displayName = data['displayName']?.toString() ?? '';
                      final role = (data['role'] ?? data['rol'] ?? 'estudiante').toString();
                      final faculty = data['faculty']?.toString() ?? 'Sin asignar';
                      final active = data['active'] == true;
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final dateStr = createdAt != null 
                          ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                          : 'N/A';

                      // Icono y color según rol
                      IconData roleIcon;
                      Color roleColor;
                      final roleLabel = _translateRole(role);
                      
                      switch (role.toLowerCase()) {
                        case 'admin':
                          roleIcon = Icons.admin_panel_settings;
                          roleColor = Colors.red;
                          break;
                        case 'estudiante':
                        case 'student':
                          roleIcon = Icons.school;
                          roleColor = Colors.blue;
                          break;
                        case 'docente':
                        case 'teacher':
                          roleIcon = Icons.book;
                          roleColor = Colors.green;
                          break;
                        case 'ponente':
                        case 'speaker':
                          roleIcon = Icons.mic;
                          roleColor = Colors.orange;
                          break;
                        default:
                          roleIcon = Icons.person;
                          roleColor = Colors.grey;
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            SelectableText(
                              email,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(roleIcon, size: 16, color: roleColor),
                                const SizedBox(width: 6),
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: roleColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              faculty,
                              style: TextStyle(
                                fontSize: 13,
                                color: faculty == 'Sin asignar' 
                                    ? cs.onSurfaceVariant 
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                active ? 'Activo' : 'Inactivo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: active ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _exportUsers() async {
    setState(() => _isExporting = true);
    
    try {
      // Obtener usuarios de Firestore
      var query = FirebaseFirestore.instance.collection('usuarios').orderBy('createdAt', descending: true);
      
      final snapshot = await query.get();
      var users = snapshot.docs;
      
      // Aplicar filtros
      if (_selectedRoleForExport != null) {
        users = users.where((doc) {
          final data = doc.data();
          final role = (data['role'] ?? data['rol'] ?? '').toString().toLowerCase();
          
          // Normalizar rol: manejar tanto español como inglés
          String normalizedRole = role;
          if (role == 'student') normalizedRole = 'estudiante';
          if (role == 'teacher') normalizedRole = 'docente';
          if (role == 'speaker') normalizedRole = 'ponente';
          
          return normalizedRole == _selectedRoleForExport;
        }).toList();
      }
      
      if (_selectedFacultyForExport != null) {
        if (_selectedFacultyForExport == '_none') {
          users = users.where((doc) {
            final data = doc.data();
            final faculty = data['faculty']?.toString() ?? '';
            return faculty.isEmpty;
          }).toList();
        } else {
          users = users.where((doc) {
            final data = doc.data();
            final faculty = data['faculty']?.toString() ?? '';
            return faculty == _selectedFacultyForExport;
          }).toList();
        }
      }
      
      if (users.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No hay usuarios que coincidan con los filtros'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Generar CSV
      final csvData = _generateCSV(users);
      
      // Descargar archivo CSV
      _downloadCSVFile(csvData, users.length);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Archivo CSV descargado con ${users.length} usuarios'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Ver en consola',
              textColor: Colors.white,
              onPressed: () {
                AppLogger.info(csvData);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
  
  String _generateCSV(List<QueryDocumentSnapshot<Map<String, dynamic>>> users) {
    final buffer = StringBuffer();
    
    // Encabezados (mismos que la tabla de vista previa)
    buffer.writeln('Email,Nombre,Rol,Facultad,Estado,Fecha de Registro');
    
    // Datos (mismo formato que la vista previa)
    for (final doc in users) {
      final data = doc.data();
      final email = data['email']?.toString() ?? '';
      final displayName = data['displayName']?.toString() ?? '';
      final roleRaw = (data['role'] ?? data['rol'] ?? 'estudiante').toString();
      final faculty = data['faculty']?.toString() ?? 'Sin asignar';
      final active = data['active'] == true ? 'Activo' : 'Inactivo';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      
      // Formato de fecha igual que la vista previa (DD/MM/YYYY)
      final dateStr = createdAt != null 
          ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
          : 'N/A';
      
      // Traducir rol a español
      final roleLabel = _translateRole(roleRaw);
      
      // Escapar comillas en los valores
      final escapedName = displayName.replaceAll('"', '""');
      final escapedFaculty = faculty.replaceAll('"', '""');
      
      buffer.writeln('$email,"$escapedName",$roleLabel,"$escapedFaculty",$active,$dateStr');
    }
    
    return buffer.toString();
  }
  
  /// Descarga el archivo CSV en el navegador
  void _downloadCSVFile(String csvData, int userCount) {
    try {
      // Convertir CSV a bytes con codificación UTF-8 (con BOM para Excel)
      final bytes = utf8.encode('\uFEFF$csvData'); // BOM para que Excel reconozca UTF-8
      
      // Crear blob
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      
      // Crear URL del blob
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Generar nombre de archivo con fecha
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'usuarios_upt_$timestamp.csv';
      
      // Crear elemento <a> y simular click
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      
      // Limpiar
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      
      AppLogger.success('✅ CSV descargado: $filename ($userCount usuarios)');
    } catch (e) {
      AppLogger.error('Error al descargar CSV: $e');
      rethrow;
    }
  }
}

/* ---------------- UI Helpers ---------------- */

/// Traduce roles de inglés a español para mostrar en la UI
String _translateRole(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return 'Admin';
    case 'student':
    case 'estudiante':
      return 'Estudiante';
    case 'teacher':
    case 'docente':
      return 'Docente';
    case 'speaker':
    case 'ponente':
      return 'Ponente';
    default:
      return role;
  }
}

class _Toolbar extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final Widget Function(BuildContext context)? actionBuilder;

  const _Toolbar({required this.title, this.onAdd, this.actionBuilder});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (actionBuilder != null) actionBuilder!(context),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Nuevo')),
          ],
        ],
      ),
    );
  }
}

Widget _empty(String msg) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24.0),
    child: Text(msg, style: const TextStyle(color: Colors.black54)),
  ),
);

String _formatDateTime(DateTime? dt) {
  if (dt == null) return 'Sin fecha';
  
  final now = DateTime.now();
  final diff = now.difference(dt);
  
  // Si fue hace menos de 1 minuto
  if (diff.inSeconds < 60) {
    return 'Hace ${diff.inSeconds} seg';
  }
  
  // Si fue hace menos de 1 hora
  if (diff.inMinutes < 60) {
    return 'Hace ${diff.inMinutes} min';
  }
  
  // Si fue hace menos de 24 horas
  if (diff.inHours < 24) {
    return 'Hace ${diff.inHours} h';
  }
  
  // Si fue hace menos de 7 días
  if (diff.inDays < 7) {
    return 'Hace ${diff.inDays} días';
  }
  
  // Si fue hace menos de 30 días
  if (diff.inDays < 30) {
    final weeks = (diff.inDays / 7).floor();
    return 'Hace ${weeks} ${weeks == 1 ? "semana" : "semanas"}';
  }
  
  // Si fue hace menos de 365 días
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return 'Hace ${months} ${months == 1 ? "mes" : "meses"}';
  }
  
  // Si fue hace más de un año
  final years = (diff.inDays / 365).floor();
  return 'Hace ${years} ${years == 1 ? "año" : "años"}';
}
