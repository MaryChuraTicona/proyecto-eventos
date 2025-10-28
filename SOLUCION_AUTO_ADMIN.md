# Solución: Auto-Asignación de Rol Administrador

## Problema
El usuario podía hacer login, pero no cargaba el panel de administrador porque su documento en Firestore no tenía el campo `role: 'admin'` configurado.

## Solución Implementada

### 1. Función `_shouldBeAdmin()`
Se agregó una función en `lib/app/router_by_rol.dart` que determina automáticamente si un usuario debería ser administrador:

```dart
bool _shouldBeAdmin(String? email) {
  if (email == null) return false;
  
  final emailLower = email.toLowerCase().trim();
  
  // Lista de emails que deberían ser admin
  const adminEmails = [
    // Agrega aquí tu email de administrador
    // Ejemplo: 'admin@virtual.upt.pe',
  ];
  
  // Si está en la lista de admins
  if (adminEmails.contains(emailLower)) return true;
  
  // TEMPORAL: El primer usuario con email institucional es admin
  if (emailLower.endsWith('@virtual.upt.pe')) {
    return true;
  }
  
  return false;
}
```

### 2. Auto-Asignación al Crear Usuario
Cuando un usuario nuevo hace login, el sistema:
1. Verifica si el usuario debería ser admin usando `_shouldBeAdmin()`
2. Crea el documento en Firestore con el rol correspondiente
3. Redirige al panel apropiado

```dart
if (!snap.exists) {
  final isAutoAdmin = _shouldBeAdmin(user.email);
  
  await ref.set({
    'email': user.email?.toLowerCase() ?? '',
    'role': isAutoAdmin ? UserRoles.admin : UserRoles.student,
    'rol': isAutoAdmin ? UserRoles.admin : UserRoles.student,
    'active': true,
    // ...
  });
  
  if (isAutoAdmin) {
    return const AdminHomeScreen();
  }
}
```

### 3. Auto-Actualización de Usuarios Existentes
Si un usuario ya existe pero debería ser admin:
1. El sistema detecta la discrepancia
2. Actualiza el rol automáticamente
3. Redirige al panel de administrador

```dart
final isAutoAdmin = _shouldBeAdmin(user.email);
final currentRole = (data['role'] ?? data['rol'])?.toString() ?? UserRoles.student;

if (isAutoAdmin && currentRole.toLowerCase() != UserRoles.admin) {
  await ref.update({
    'role': UserRoles.admin,
    'rol': UserRoles.admin,
    'active': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return const AdminHomeScreen();
}
```

## Cómo Usar

### Opción 1: Por Email Específico (Recomendado para Producción)
Edita la lista `adminEmails` en `lib/app/router_by_rol.dart`:

```dart
const adminEmails = [
  'admin@virtual.upt.pe',
  'director@virtual.upt.pe',
  // Agrega más emails según necesites
];
```

### Opción 2: Auto-Admin para Institucionales (Temporal)
**⚠️ TEMPORAL - Solo para desarrollo**

Actualmente, cualquier usuario con email `@virtual.upt.pe` se convierte automáticamente en admin en su primer login.

**IMPORTANTE**: Después de configurar tu primer administrador, comenta estas líneas:

```dart
// COMENTAR ESTO DESPUÉS DE CONFIGURAR EL PRIMER ADMIN
// if (emailLower.endsWith('@virtual.upt.pe')) {
//   return true;
// }
```

## Flujo de Login

```
Usuario hace login
    ↓
¿Documento existe en Firestore?
    ├─ NO → ¿Debería ser admin?
    │        ├─ SÍ → Crear como admin → Panel Admin
    │        └─ NO → Crear como estudiante → Panel Estudiante
    │
    └─ SÍ → ¿Debería ser admin pero no lo es?
             ├─ SÍ → Actualizar a admin → Panel Admin
             └─ NO → Cargar según rol actual → Panel correspondiente
```

## Verificación

### 1. En la Consola del Navegador
Verás logs como:
```
ℹ️ Determinando pantalla home para tu@email.com
🔄 Actualizando usuario a ADMIN: tu@email.com
✅ Usuario actualizado a ADMINISTRADOR
✅ Redirigiendo a pantalla: AdminHomeScreen
```

### 2. En Firebase Console
Tu documento en `usuarios` debería tener:
```json
{
  "uid": "...",
  "email": "tu@virtual.upt.pe",
  "role": "admin",
  "rol": "admin",
  "active": true,
  "createdAt": "...",
  "updatedAt": "..."
}
```

### 3. En la Aplicación
Deberías ver:
- ✅ Panel de administrador con menú lateral
- ✅ Tabs: Dashboard, Eventos, Ponencias, Ponentes, Usuarios, Reportes
- ✅ Botón de "Sembrar datos demo"
- ✅ Icono de admin en la esquina superior derecha

## Seguridad

### Producción
Para producción, **DEBES**:
1. Comentar la línea que hace admin a todos los emails institucionales
2. Mantener solo la lista específica de `adminEmails`
3. Considerar mover esta lista a Firebase Remote Config o Firestore

```dart
bool _shouldBeAdmin(String? email) {
  if (email == null) return false;
  
  final emailLower = email.toLowerCase().trim();
  
  // Solo emails específicos
  const adminEmails = [
    'admin@virtual.upt.pe',
  ];
  
  return adminEmails.contains(emailLower);
}
```

### Alternativa: Admin desde Firestore
Podrías crear una colección `admin_emails` en Firestore:

```dart
Future<bool> _isAdminFromFirestore(String email) async {
  final doc = await FirebaseFirestore.instance
      .collection('admin_emails')
      .doc(email.toLowerCase())
      .get();
  return doc.exists;
}
```

## Troubleshooting

### Aún no carga el panel de admin
1. **Cierra sesión completamente**
2. **Limpia caché del navegador** (Ctrl + Shift + Delete)
3. **Vuelve a hacer login**
4. **Verifica los logs en la consola del navegador**

### Error de permisos en Firestore
Las reglas actuales permiten:
- ✅ Cualquier usuario autenticado puede leer cualquier perfil (temporal)
- ✅ Usuarios pueden actualizar su propio perfil
- ✅ El código actualiza el rol automáticamente

### No aparece como admin después de login
1. Verifica que tu email termine en `@virtual.upt.pe`
2. O agrégalo manualmente a la lista `adminEmails`
3. Revisa los logs en la consola del navegador
4. Verifica el documento en Firebase Console

## Próximos Pasos

1. **Configurar el primer admin** → Hacer login con tu cuenta
2. **Verificar que funciona** → Ver panel de administrador
3. **Comentar la auto-asignación temporal** → Editar `_shouldBeAdmin()`
4. **Crear más admins desde el panel** → Usar la pestaña "Usuarios"
5. **Ajustar reglas de Firestore** → Restringir permisos en producción

## Archivos Modificados
- ✅ `lib/app/router_by_rol.dart` - Función `_shouldBeAdmin()` y lógica de auto-asignación
- ✅ `firestore.rules` - Reglas temporales más permisivas para desarrollo

## Notas
- Esta solución es **temporal para facilitar el desarrollo**
- En **producción**, solo usa la lista específica de emails admin
- Considera implementar un sistema más robusto de gestión de roles
- Los logs con `AppLogger` te ayudarán a debuggear cualquier problema

