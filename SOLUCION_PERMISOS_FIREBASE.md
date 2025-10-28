# 🔒 Solución: Error de Permisos de Firebase

## ❌ Error Original

```
Error: [cloud_firestore/permission-denied] Missing or insufficient permissions.
```

**Problema**: Al hacer clic en "Inscribirme", Firebase bloqueaba la operación.

---

## 🔍 Causa del Problema

Las reglas de Firestore tenían **2 problemas**:

### 1. Campo Incorrecto
- **Reglas buscaban**: `resource.data.userId`
- **Código guardaba**: `resource.data.uid`
- ❌ **No coincidían** → Permiso denegado

### 2. Validación Insuficiente en Creación
- No validaba que el usuario solo pueda crear sus propias inscripciones
- Faltaba verificar `request.resource.data.uid == request.auth.uid`

---

## ✅ Solución Aplicada

### Reglas de `registrations` Actualizadas

**Antes** ❌:
```javascript
match /registrations/{registrationId} {
  allow read: if isSignedIn() && 
                 (resource.data.userId == request.auth.uid || isAdmin());
  allow create: if isSignedIn();  // ← Demasiado permisivo
  allow update, delete: if isAdmin();
}
```

**Después** ✅:
```javascript
match /registrations/{registrationId} {
  // Lectura: el usuario que se inscribió o admin
  allow read: if isSignedIn() && 
                 (resource.data.uid == request.auth.uid || isAdmin());
  
  // Creación: usuarios autenticados pueden crear sus propias inscripciones
  allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
  
  // Actualización y eliminación: el usuario o admin
  allow update, delete: if isSignedIn() && 
                           (resource.data.uid == request.auth.uid || isAdmin());
}
```

### Reglas de `attendance` Actualizadas

**Antes** ❌:
```javascript
match /attendance/{attendanceId} {
  allow read: if isSignedIn();  // ← Demasiado permisivo
  allow create: if isSignedIn();  // ← Demasiado permisivo
  allow update, delete: if isAdmin();
}
```

**Después** ✅:
```javascript
match /attendance/{attendanceId} {
  // Lectura: el usuario que asistió o admin
  allow read: if isSignedIn() && 
                 (resource.data.uid == request.auth.uid || isAdmin());
  
  // Creación: usuarios autenticados pueden marcar su propia asistencia
  allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
  
  // Actualización y eliminación: solo admin
  allow update, delete: if isAdmin();
}
```

---

## 🚀 Cómo Desplegar las Reglas

### Opción 1: Línea de Comandos (Recomendado)

```bash
# Desplegar solo las reglas de Firestore
firebase deploy --only firestore:rules
```

**Salida esperada**:
```
=== Deploying to 'eventos-epis'...

i  deploying firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

✔  Deploy complete!
```

---

### Opción 2: Consola de Firebase (Manual)

1. **Ir a Firebase Console**:
   ```
   https://console.firebase.google.com/
   ```

2. **Seleccionar tu proyecto**: `eventos-epis`

3. **Ir a Firestore Database** → **Reglas**

4. **Copiar y pegar** el contenido de `firestore.rules`

5. **Click en "Publicar"**

---

## 🔒 Reglas de Seguridad Completas

### Resumen de Permisos

| Colección | Lectura | Creación | Actualización | Eliminación |
|-----------|---------|----------|---------------|-------------|
| **usuarios** | Propio usuario o admin | Usuario autenticado | Solo admin | Solo admin |
| **eventos** | Todos (público) | Solo admin | Solo admin | Solo admin |
| **sesiones** | Todos (público) | Solo admin | Solo admin | Solo admin |
| **ponentes** | Todos (público) | Solo admin | Solo admin | Solo admin |
| **registrations** | Propio registro o admin | Usuario autenticado | Propio registro o admin | Propio registro o admin |
| **attendance** | Propia asistencia o admin | Usuario autenticado | Solo admin | Solo admin |

---

## ✅ Validaciones de Seguridad

### 1. Inscripciones (registrations)

```javascript
// ✅ Usuario solo puede inscribirse a sí mismo
allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;

// ✅ Usuario solo puede leer sus propias inscripciones
allow read: if isSignedIn() && (resource.data.uid == request.auth.uid || isAdmin());

// ✅ Usuario puede cancelar su propia inscripción
allow delete: if isSignedIn() && (resource.data.uid == request.auth.uid || isAdmin());
```

### 2. Asistencia (attendance)

```javascript
// ✅ Usuario solo puede marcar su propia asistencia
allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;

// ✅ Usuario solo puede leer su propia asistencia
allow read: if isSignedIn() && (resource.data.uid == request.auth.uid || isAdmin());

// ✅ Solo admin puede modificar asistencias
allow update, delete: if isAdmin();
```

---

## 🧪 Probar las Reglas

### En el Simulador de Firebase

1. **Ir a Firebase Console** → **Firestore** → **Reglas**
2. **Click en "Reglas del Playground"**
3. **Configurar simulación**:

```
Tipo: get
Colección: /registrations/evento123_sesion456_user789
Autenticado: Sí
UID del usuario: user789
```

**Resultado esperado**: ✅ Permitido

---

### En la Aplicación

1. **Usuario hace login**
2. **Ve un evento con ponencias**
3. **Click en "Inscribirme"**
4. **Resultado esperado**:
   - ✅ Snackbar verde: "Te inscribiste correctamente"
   - ✅ Botón cambia a "Inscrito"
   - ✅ Sin errores en consola

---

## 📊 Estructura de Datos

### Documento en `registrations`

```javascript
{
  "id": "evento123_sesion456_user789",
  "eventId": "evento123",
  "sessionId": "sesion456",
  "uid": "user789",  // ← Campo correcto que coincide con las reglas
  "createdAt": Timestamp
}
```

### Documento en `attendance`

```javascript
{
  "id": "evento123_sesion456_user789",
  "eventId": "evento123",
  "sessionId": "sesion456",
  "uid": "user789",  // ← Campo correcto que coincide con las reglas
  "markedAt": Timestamp,
  "present": true
}
```

---

## 🛡️ Seguridad Mejorada

### Antes
- ❌ Cualquier usuario podía leer todas las inscripciones
- ❌ Cualquier usuario podía crear inscripciones de otros
- ❌ Campo incorrecto (`userId` vs `uid`)

### Después
- ✅ Usuario solo ve sus propias inscripciones
- ✅ Usuario solo puede inscribirse a sí mismo
- ✅ Usuario puede cancelar su propia inscripción
- ✅ Campo correcto (`uid`) en todos lados
- ✅ Admin puede ver/modificar todo

---

## 🔍 Debugging

### Si el error persiste:

1. **Verificar que las reglas se desplegaron**:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Verificar en Firebase Console**:
   - Ir a Firestore → Reglas
   - Verificar que el contenido sea el correcto

3. **Limpiar caché del navegador**:
   - Ctrl + Shift + R (Windows/Linux)
   - Cmd + Shift + R (Mac)

4. **Verificar en la consola del navegador**:
   ```javascript
   // Abrir DevTools (F12)
   // Ver si hay errores en la pestaña "Console"
   ```

5. **Verificar que el usuario esté autenticado**:
   ```javascript
   // En la consola del navegador
   firebase.auth().currentUser
   // Debe mostrar el objeto del usuario
   ```

---

## 📝 Archivos Modificados

- ✅ `firestore.rules` - Reglas de seguridad actualizadas

---

## ✅ Checklist de Verificación

- [x] Reglas actualizadas en `firestore.rules`
- [ ] Reglas desplegadas con `firebase deploy --only firestore:rules`
- [ ] Usuario puede inscribirse sin errores
- [ ] Botón cambia a "Inscrito" automáticamente
- [ ] Historial muestra las inscripciones
- [ ] Usuario puede cancelar inscripción
- [ ] Usuario puede marcar asistencia

---

## 🎉 Resultado Final

Una vez desplegadas las reglas:

✅ **Inscripciones funcionan correctamente**  
✅ **Seguridad robusta (usuarios solo modifican sus datos)**  
✅ **Admins tienen control total**  
✅ **Sin errores de permisos**  

---

**Fecha**: 25/10/2025  
**Estado**: ✅ Reglas actualizadas (pendiente de despliegue)  
**Siguiente paso**: Ejecutar `firebase deploy --only firestore:rules`

