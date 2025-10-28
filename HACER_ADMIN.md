# Cómo configurarte como Administrador

## Problema
Tu cuenta existe en Firebase, pero no tiene el rol de administrador configurado.

## Solución

### Opción 1: Desde Firebase Console (Recomendado)
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Firestore Database**
4. Busca la colección `usuarios`
5. Encuentra tu documento (tu email)
6. Haz clic en **editar**
7. Agrega o modifica el campo `role` con el valor: `admin`
8. Agrega también el campo `rol` con el valor: `admin` (por compatibilidad)
9. Guarda los cambios
10. Refresca la aplicación

### Opción 2: Desde la Consola del Navegador
1. Abre la aplicación en el navegador
2. Haz login con tu cuenta
3. Abre las **Herramientas de Desarrollador** (F12)
4. Ve a la pestaña **Console**
5. Pega y ejecuta este código:

```javascript
// Obtener el usuario actual
const auth = firebase.auth();
const db = firebase.firestore();

auth.onAuthStateChanged(async (user) => {
  if (user) {
    console.log('Usuario actual:', user.email);
    
    // Actualizar el rol a admin
    await db.collection('usuarios').doc(user.uid).set({
      role: 'admin',
      rol: 'admin',
      active: true,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log('✅ Rol actualizado a ADMIN');
    console.log('🔄 Recarga la página para ver los cambios');
  }
});
```

6. Recarga la página

### Opción 3: Cloud Functions (Automático)
Ejecuta esta Cloud Function para hacer admin al primer usuario:

```bash
# En la carpeta functions/
npm install
firebase deploy --only functions
```

Luego llama a la función desde la consola:
```javascript
fetch('https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/makeAdmin?email=TU_EMAIL@virtual.upt.pe')
  .then(r => r.json())
  .then(console.log);
```

## Verificar que funciona
1. Después de cambiar el rol, **cierra sesión**
2. Vuelve a hacer login
3. Deberías ver el panel de administrador con:
   - Dashboard
   - Eventos
   - Ponencias
   - Ponentes
   - Usuarios
   - Reportes

## Estructura del documento en Firestore
Tu documento debe verse así:
```json
{
  "uid": "tu-uid-de-firebase",
  "email": "tu@email.com",
  "role": "admin",
  "rol": "admin",
  "active": true,
  "displayName": "Tu Nombre",
  "photoURL": "...",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Roles disponibles en el sistema
- `admin` o `administrador` → Panel de administrador
- `docente` → Panel de docente
- `ponente` → Panel de ponente
- `estudiante` → Panel de estudiante (por defecto)

## Si aún no funciona
Verifica en las reglas de Firestore que puedes leer tu propio documento. La regla actual es:
```javascript
match /usuarios/{userId} {
  allow read: if isSignedIn(); // Permite leer a cualquier usuario autenticado
  allow create: if isSignedIn() && request.auth.uid == userId;
  allow update: if isSignedIn() && request.auth.uid == userId;
}
```

