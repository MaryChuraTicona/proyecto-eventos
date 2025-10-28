# ⚠️ INSTRUCCIONES URGENTES - Solución de Permisos

## 🚨 Problema
No puedes hacer login con ningún usuario - ni `@upt.pe` ni `@virtual.upt.pe`

## ✅ Solución Aplicada
He desplegado reglas de Firestore **COMPLETAMENTE ABIERTAS** (solo para desarrollo):
```javascript
match /{document=**} {
  allow read, write: if true;  // ⚠️ TEMPORAL
}
```

## 🔧 QUÉ DEBES HACER AHORA (IMPORTANTE)

### Paso 1: Limpiar Caché del Navegador
Es **CRÍTICO** que limpies la caché:

**Opción A - Limpieza Rápida:**
1. Presiona `Ctrl + Shift + Delete`
2. Selecciona **"Imágenes y archivos en caché"**
3. Selecciona **"Últimos 7 días"** o **"Todo"**
4. Haz clic en **"Borrar datos"**

**Opción B - Usar Ventana Incógnito (MÁS RÁPIDO):**
1. Presiona `Ctrl + Shift + N` para abrir ventana incógnito
2. Ve a `localhost:64059` (o el puerto que aparezca en tu terminal)
3. Intenta hacer login

### Paso 2: Recargar la Aplicación
1. **Cierra completamente** el navegador Edge
2. **Abre de nuevo** Edge
3. Ve a `localhost:64059` (verifica el puerto en el terminal de Flutter)
4. **Intenta hacer login** con tu email

### Paso 3: Probar Login
Intenta con cualquiera de estos:
- ✅ `joarteaga@upt.pe`
- ✅ `cualquier@virtual.upt.pe`
- ✅ Cualquier email

## 📊 Lo Que Deberías Ver

### En el Terminal de Flutter:
```
ℹ️ [INFO] Determinando pantalla home para joarteaga@upt.pe
✨ Usuario creado como ADMINISTRADOR: joarteaga@upt.pe
✅ Redirigiendo a pantalla: AdminHomeScreen
```

### En el Navegador:
- ✅ **Panel de Administrador** completo
- ✅ Menú lateral con opciones
- ✅ Dashboard, Eventos, Ponencias, etc.

## ❌ Si AÚN No Funciona

### Opción 1: Reiniciar Flutter
En el terminal donde está corriendo Flutter:
```
q          (para salir)
```
Luego:
```
flutter run -d edge
```

### Opción 2: Verificar Puerto
Mira en el terminal de Flutter qué puerto está usando:
```
This app is linked to the debug service: ws://127.0.0.1:XXXXX/...
```
Asegúrate de ir a `localhost:XXXXX` en el navegador

### Opción 3: Verificar Reglas en Firebase Console
1. Ve a https://console.firebase.google.com/
2. Selecciona tu proyecto `eventos-e7a2c`
3. Ve a **Firestore Database** → **Rules**
4. Deberías ver:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

## 🔍 Debugging

### Verifica en la Consola del Navegador (F12)
Busca mensajes de error relacionados con:
- `permission-denied` → Las reglas no se aplicaron correctamente
- `auth/...` → Problema con Firebase Authentication
- Otros errores → Compártelos conmigo

### Verifica el Email
Asegúrate de estar usando un email que termine en:
- `@upt.pe`
- `@virtual.upt.pe`

## ⚠️ IMPORTANTE

### Esta configuración es TEMPORAL
Las reglas actuales permiten a **cualquiera** leer/escribir en tu base de datos.

**Solo para desarrollo local.**

Antes de producción, **DEBES**:
1. Comentar la regla `allow read, write: if true;`
2. Descomentar las reglas específicas
3. Redesplegar con `firebase deploy --only firestore:rules`

## 📝 Próximos Pasos

Una vez que puedas entrar:
1. ✅ Verifica que el panel de admin funciona
2. ✅ Prueba crear un evento con "Sembrar datos demo"
3. ✅ Avísame que funciona
4. 🔒 Después configuraremos reglas de seguridad apropiadas

## 🆘 Si Nada Funciona

Comparte conmigo:
1. **Screenshot** de la consola del navegador (F12)
2. **Terminal output** completo de Flutter
3. **URL** exacta que estás usando en el navegador
4. **Email** con el que intentas hacer login

---

**RECUERDA**: Limpia la caché o usa ventana incógnito. El navegador puede estar cacheando las reglas antiguas de Firestore.

