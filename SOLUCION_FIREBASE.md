# 🔥 Solución: Los datos no se guardan en Firebase

## 🔍 Diagnóstico del problema

Si los datos que ingresas no se guardan en Firestore, las causas más comunes son:

1. ❌ **Reglas de seguridad muy restrictivas** (la más común)
2. ❌ **Autenticación no habilitada correctamente**
3. ❌ **Usuario no tiene permisos de admin**
4. ❌ **Base de datos no creada en Firebase**

---

## ✅ **SOLUCIÓN RÁPIDA (Para probar)**

### Paso 1: Habilitar reglas permisivas temporalmente

1. **Ve a Firebase Console**: https://console.firebase.google.com/
2. **Selecciona tu proyecto**: `eventos-e7a2c`
3. **Ve a Firestore Database** (menú izquierdo)
4. **Pestaña "Reglas" (Rules)**
5. **Reemplaza todo con esto:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ⚠️ MODO DESARROLLO: Permite todo (solo para pruebas)
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

6. **Haz clic en "Publicar" (Publish)**

---

## 🛡️ **SOLUCIÓN PERMANENTE (Segura)**

### Paso 1: Configurar reglas de seguridad correctas

1. **Ve a Firebase Console → Firestore Database → Reglas**
2. **Copia y pega el contenido del archivo `firestore.rules`** que está en tu proyecto
3. **Haz clic en "Publicar"**

### Paso 2: Verificar autenticación

1. **Ve a Authentication → Sign-in method**
2. **Verifica que estén habilitados:**
   - ✅ Email/Password
   - ✅ Google

### Paso 3: Crear un usuario admin

1. **Inicia sesión en tu app** (con cualquier cuenta)
2. **Ve a Firestore Database**
3. **Busca la colección `usuarios`**
4. **Encuentra tu usuario** (busca por tu email)
5. **Edita el documento** y agrega/modifica estos campos:

```json
{
  "email": "tu@email.com",
  "role": "admin",
  "rol": "admin",
  "active": true,
  "estado": "activo"
}
```

6. **Guarda los cambios**

### Paso 4: Crear colecciones manualmente (si no existen)

Si las colecciones no se han creado automáticamente:

1. **Ve a Firestore Database**
2. **Haz clic en "Iniciar colección" o "Start collection"**
3. **Crea estas colecciones:**
   - `usuarios`
   - `eventos`
   - `speakers` o `ponentes`
   - `inscripciones` o `registrations`

---

## 🧪 **Prueba que funcione**

### 1. Verifica la conexión en la consola del navegador

Cuando la app esté corriendo:

1. **Presiona F12** (para abrir DevTools)
2. **Ve a la pestaña "Console"**
3. **Busca errores de Firebase**:
   - `permission-denied` → Problema de reglas
   - `auth/unauthenticated` → No has iniciado sesión
   - `not-found` → Colección no existe

### 2. Prueba crear un ponente

1. **Inicia sesión como admin**
2. **Ve a la sección "Ponentes"**
3. **Haz clic en "Nuevo"**
4. **Llena el formulario y guarda**
5. **Ve a Firebase Console → Firestore Database**
6. **Verifica que aparezca en la colección `speakers` o `ponentes`**

---

## 🐛 **Errores comunes y soluciones**

### Error: "permission-denied"

**Causa**: Las reglas de Firestore no permiten escribir.

**Solución**:
1. Activa las reglas permisivas temporalmente (ver arriba)
2. O configura las reglas correctas con el archivo `firestore.rules`

### Error: "Missing or insufficient permissions"

**Causa**: No eres admin o no has iniciado sesión.

**Solución**:
1. Verifica que iniciaste sesión
2. Configura tu usuario como admin en Firestore

### Error: "FAILED_PRECONDITION"

**Causa**: La colección o índice no existe.

**Solución**:
1. Crea la colección manualmente en Firestore
2. O intenta crear un documento primero (se creará automáticamente)

### Los datos no aparecen

**Causa**: Puede ser un error silencioso.

**Solución**:
1. Abre la consola del navegador (F12)
2. Ve a la pestaña "Console"
3. Busca errores en rojo
4. Ve a "Network" y verifica las peticiones a Firebase

---

## 📊 **Verificar el estado de Firebase**

### En la consola del navegador (F12):

```javascript
// Copia y pega esto en la consola
firebase.auth().currentUser
// Debería mostrar tu usuario si estás autenticado

firebase.firestore().collection('usuarios').get()
  .then(snap => console.log('Usuarios:', snap.size))
  .catch(err => console.error('Error:', err))
// Debería mostrar cuántos usuarios hay
```

---

## 🔧 **Comandos para revisar errores en Flutter**

Si la app no está corriendo correctamente:

```bash
# Limpiar el build
flutter clean

# Reinstalar dependencias
flutter pub get

# Ver errores en tiempo real
flutter run -d edge --verbose
```

---

## 📝 **Checklist de verificación**

Marca cada ítem cuando lo hayas verificado:

- [ ] Firebase Console está abierto en el proyecto correcto (`eventos-e7a2c`)
- [ ] Firestore Database está creado (no en modo Realtime Database)
- [ ] Las reglas de Firestore permiten escritura (usa reglas permisivas para probar)
- [ ] Authentication tiene Email/Password y Google habilitados
- [ ] He iniciado sesión en la app
- [ ] Mi usuario tiene `role: "admin"` en Firestore
- [ ] La colección donde quiero guardar existe (o se creará automáticamente)
- [ ] No hay errores en la consola del navegador (F12)
- [ ] La app está corriendo sin errores de compilación

---

## 🚀 **Si nada funciona: Reinicio completo**

```bash
# 1. Cerrar la app
Ctrl+C

# 2. Limpiar todo
flutter clean

# 3. Reinstalar dependencias
flutter pub get

# 4. Ejecutar de nuevo
flutter run -d edge
```

---

## 📞 **Ayuda adicional**

Si sigues teniendo problemas:

1. **Revisa la consola del navegador** (F12 → Console)
2. **Copia el mensaje de error exacto**
3. **Verifica que tu proyecto de Firebase sea el correcto**
4. **Asegúrate de tener conexión a internet**

---

## 🎯 **Prueba final**

Para verificar que todo funciona:

1. ✅ Inicia sesión en la app
2. ✅ Ve al panel de admin
3. ✅ Crea un nuevo ponente
4. ✅ Ve a Firebase Console → Firestore Database
5. ✅ Verifica que aparezca el ponente en la colección `speakers`

**Si aparece, ¡funciona! 🎉**

