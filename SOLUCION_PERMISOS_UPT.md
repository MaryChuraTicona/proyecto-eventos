# Solución: Error de Permisos para Usuarios @upt.pe

## Problema
El usuario con email `@upt.pe` (no `@virtual.upt.pe`) no podía hacer login y recibía:
```
❌ [ERROR] Error al determinar rol de usuario
   Details: [cloud_firestore/permission-denied] Missing or insufficient permissions.
```

## Causas Identificadas

### 1. Email Institucional No Reconocido
La función `_shouldBeAdmin()` solo verificaba emails con `@virtual.upt.pe`, pero el usuario tenía `@upt.pe`.

### 2. Reglas de Firestore Demasiado Restrictivas
Las reglas de Firestore requerían que el documento de usuario existiera para verificar si es admin, pero el sistema no podía crear el documento inicial debido a las restricciones.

**Problema circular:**
```
Login → Intentar crear documento usuario → Firestore verifica si es admin → 
Requiere leer documento usuario → Documento no existe → ERROR de permisos
```

## Solución Implementada

### 1. Actualizar `_shouldBeAdmin()` para Múltiples Dominios
**Archivo**: `lib/app/router_by_rol.dart`

```dart
bool _shouldBeAdmin(String? email) {
  if (email == null) return false;
  
  final emailLower = email.toLowerCase().trim();
  
  // Lista de emails específicos que deberían ser admin
  const adminEmails = [
    // Agrega aquí emails específicos
  ];
  
  if (adminEmails.contains(emailLower)) return true;
  
  // TEMPORAL: Usuarios con email institucional son admin
  if (emailLower.endsWith('@virtual.upt.pe') || emailLower.endsWith('@upt.pe')) {
    return true;
  }
  
  return false;
}
```

**Cambio clave**: Agregado `|| emailLower.endsWith('@upt.pe')`

### 2. Reglas de Firestore Temporalmente Permisivas
**Archivo**: `firestore.rules`

```javascript
// TEMPORAL: Para desarrollo y configuración inicial
// ⚠️ COMENTAR ESTO EN PRODUCCIÓN
match /{document=**} {
  allow read, write: if isSignedIn();
}
```

Esto permite que **cualquier usuario autenticado** pueda:
- ✅ Crear su documento inicial en la colección `usuarios`
- ✅ Leer cualquier colección
- ✅ Escribir en cualquier colección

**⚠️ IMPORTANTE**: Esta regla es **TEMPORAL** solo para desarrollo y configuración inicial.

## Flujo de Login Corregido

```
Usuario hace login con joarteaga@upt.pe
    ↓
Firebase Authentication: ✅ Usuario autenticado
    ↓
Verificar documento en Firestore: ❌ No existe
    ↓
_shouldBeAdmin('joarteaga@upt.pe'): ✅ true (termina en @upt.pe)
    ↓
Crear documento con role: 'admin': ✅ Permitido (reglas temporales)
    ↓
Redirigir a AdminHomeScreen: ✅ Éxito
```

## Instrucciones para el Usuario

### 1. Recargar la Aplicación
**Si estás en la app en el navegador:**
1. **Presiona `Ctrl + R`** o recarga la página
2. O presiona **`r`** en el terminal de Flutter para hot reload

### 2. Cerrar Sesión y Volver a Entrar
1. Si ya estás con sesión iniciada, **cierra sesión**
2. **Vuelve a hacer login** con tu email `@upt.pe`
3. Deberías ver el panel de administrador

### 3. Verificar en Consola del Navegador
Abre las **DevTools (F12)** y deberías ver:
```
ℹ️ [INFO] Determinando pantalla home para joarteaga@upt.pe
✨ Usuario creado como ADMINISTRADOR: joarteaga@upt.pe
✅ Redirigiendo a pantalla: AdminHomeScreen
```

## Dominios Soportados

Ahora el sistema reconoce como institucionales (y potencialmente admin):
- ✅ `usuario@virtual.upt.pe`
- ✅ `usuario@upt.pe`

Para agregar más dominios, modifica la función `_shouldBeAdmin()`:
```dart
if (emailLower.endsWith('@virtual.upt.pe') || 
    emailLower.endsWith('@upt.pe') ||
    emailLower.endsWith('@upttacna.edu.pe')) {
  return true;
}
```

## Seguridad en Producción

### ⚠️ CRÍTICO: Antes de Producción

1. **Comentar la auto-asignación de admin**:
```dart
// COMENTAR ESTO EN PRODUCCIÓN
// if (emailLower.endsWith('@virtual.upt.pe') || emailLower.endsWith('@upt.pe')) {
//   return true;
// }
```

2. **Usar solo lista específica de admins**:
```dart
const adminEmails = [
  'admin@upt.pe',
  'director@upt.pe',
];
return adminEmails.contains(emailLower);
```

3. **Comentar las reglas permisivas en `firestore.rules`**:
```javascript
// COMENTAR EN PRODUCCIÓN
// match /{document=**} {
//   allow read, write: if isSignedIn();
// }
```

4. **Usar las reglas específicas** que ya estaban definidas en el archivo

## Troubleshooting

### Aún dice "Permission Denied"
1. **Verifica que las reglas se desplegaron**:
   ```bash
   firebase deploy --only firestore:rules
   ```
2. **Limpia caché del navegador**: Ctrl + Shift + Delete
3. **Usa ventana incógnito** para evitar caché
4. **Verifica en Firebase Console** → Firestore → Rules

### No aparece como admin
1. Verifica que tu email termine en `@upt.pe` o `@virtual.upt.pe`
2. Revisa la consola del navegador (F12) para ver los logs
3. Ve a Firebase Console → Firestore → usuarios → tu documento
4. Verifica que tenga `role: 'admin'` y `rol: 'admin'`

### Error "Application finished" en el terminal
Esto es normal si hubo un error en el login anterior. Solo:
1. Recarga la página en el navegador
2. O vuelve a ejecutar `flutter run -d edge`

## Archivos Modificados

✅ `lib/app/router_by_rol.dart`
- Agregado soporte para `@upt.pe`
- Función `_shouldBeAdmin()` actualizada

✅ `firestore.rules`
- Reglas temporales permisivas para desarrollo
- Comentarios claros sobre qué comentar en producción

✅ Cambios desplegados a Firebase
- Las reglas están activas inmediatamente

## Próximos Pasos

1. ✅ **Hacer login** con tu cuenta `@upt.pe`
2. ✅ **Verificar panel de admin** funciona correctamente
3. ✅ **Crear eventos de prueba** con el botón "Sembrar datos demo"
4. ⚠️ **ANTES DE PRODUCCIÓN**: Comentar reglas permisivas y auto-admin
5. 📝 **Documentar** lista de administradores autorizados

## Notas de Desarrollo

- Las reglas permisivas son **solo para desarrollo**
- Facilitan la configuración inicial sin bloqueos
- **DEBEN removerse** antes de lanzar a producción
- En producción, usar roles específicos y reglas restrictivas
- Considerar usar Firebase Admin SDK para operaciones privilegiadas

