# 🚀 Instrucciones para Ejecutar el Proyecto Mejorado

## 📋 Requisitos Previos

### 1. Software Necesario
- ✅ **Flutter SDK** >= 3.0.0 (actualmente tienes 3.35.5 ✓)
- ✅ **Dart** >= 3.0
- ✅ **Git**
- ⚠️ **Visual Studio 2019/2022** (para compilar Windows desktop)
- ✅ **Chrome** o **Edge** (para web)

### 2. Cuenta Firebase
- Proyecto de Firebase configurado
- Authentication habilitado (Email/Password y Google)
- Firestore Database creado
- Archivo `google-services.json` en `android/app/`

---

## 🔧 Configuración Inicial

### Paso 1: Instalar Dependencias
```powershell
cd eventos-epis-main
flutter pub get
```

### Paso 2: Verificar Flutter
```powershell
flutter doctor
```

**Nota**: Si ves problemas con Visual Studio, puedes ejecutar en web primero.

---

## 🌐 Opciones de Ejecución

### Opción 1: Web (Recomendado - Sin VS requerido) ✅

#### En Chrome:
```powershell
flutter run -d chrome
```

#### En Edge:
```powershell
flutter run -d edge
```

**Ventajas**:
- No requiere Visual Studio
- Rápido de compilar
- Ideal para desarrollo

**Nota**: Si Chrome da problemas de conexión, usa Edge.

---

### Opción 2: Windows Desktop (Requiere Visual Studio) 💻

#### Requisitos Adicionales:
1. **Instalar Visual Studio 2022**
   - Descargar: https://visualstudio.microsoft.com/downloads/
   - Seleccionar workload: "Desktop development with C++"

2. **Habilitar Modo Desarrollador** (Windows 10/11):
   - Settings → Update & Security → For developers
   - Activar "Developer Mode"

#### Ejecutar:
```powershell
flutter run -d windows
```

**Ventajas**:
- Mejor rendimiento
- Experiencia nativa
- Acceso a más APIs del sistema

---

### Opción 3: Android (Requiere Android Studio) 📱

#### Requisitos:
1. **Android Studio** instalado
2. **Android Emulator** o dispositivo físico conectado

#### Ejecutar:
```powershell
# Ver dispositivos disponibles
flutter devices

# Ejecutar en Android
flutter run -d <device-id>
```

---

## 📦 Archivos Nuevos Creados

### Archivos de Mejoras:
1. **`lib/core/constants.dart`** - Sistema de constantes centralizado
2. **`lib/core/error_handler.dart`** - Manejo de errores y logging
3. **`lib/common/widgets/custom_card.dart`** - Widgets reutilizables
4. **`lib/features/auth/auth_controller.dart`** - Controlador de autenticación
5. **`lib/features/auth/improved_login_screen.dart`** - Login mejorado
6. **`MEJORAS_APLICADAS.md`** - Documentación de mejoras

### Archivos Modificados:
1. **`lib/core/firestore_paths.dart`** - Actualizado con constantes
2. **`lib/services/event_service.dart`** - Con caché y logging
3. **`lib/app/router_by_rol.dart`** - Con logging mejorado
4. **`lib/features/admin/admin_home_screen.dart`** - Con logging

---

## 🎯 Cómo Usar la Versión Mejorada

### Para usar la nueva pantalla de login:

1. Abrir `lib/main.dart`
2. Cambiar la importación:

```dart
// Cambiar esto:
import 'features/auth/login_screen.dart';

// Por esto:
import 'features/auth/improved_login_screen.dart';
```

3. Actualizar el widget:

```dart
// Cambiar esto:
return const LoginScreen();

// Por esto:
return const ImprovedLoginScreen();
```

### O puedes mantener ambas versiones y elegir cuál usar.

---

## 🔍 Verificar que Todo Funciona

### 1. Compilar sin Errores:
```powershell
flutter build web
```

### 2. Verificar Linter:
```powershell
flutter analyze
```

### 3. Ver Logs Mejorados:
Al ejecutar la app, ahora verás en la consola:
```
✅ [SUCCESS] Usuario creado: estudiante@upt.pe
ℹ️ [INFO] Obteniendo evento abc123 desde Firestore
⚠️ [WARNING] Cuenta inactiva: usuario@example.com
```

---

## 🐛 Solución de Problemas Comunes

### Error: "Unable to find suitable Visual Studio toolchain"
**Solución**: Ejecuta en web en lugar de Windows:
```powershell
flutter run -d edge
```

### Error: "google-services.json not found"
**Solución**: 
1. Descarga el archivo desde Firebase Console
2. Colócalo en `android/app/google-services.json`

### Error: "Could not resolve all dependencies"
**Solución**:
```powershell
flutter clean
flutter pub get
```

### Chrome muestra errores de conexión
**Solución**: Usa Edge o Windows:
```powershell
flutter run -d edge
```

### Problemas de cache de Firestore
**Solución**: Los nuevos cambios incluyen manejo de caché mejorado.

---

## 📊 Configuración Firebase

### 1. Authentication
En Firebase Console → Authentication → Sign-in method:
- ✅ Habilitar "Email/Password"
- ✅ Habilitar "Google"
- ✅ Agregar dominio autorizado (localhost, tu dominio)

### 2. Firestore
Reglas básicas recomendadas:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Usuarios: lectura propia o admin
    match /usuarios/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      (request.auth.uid == userId || 
                       get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Eventos: lectura pública, escritura admin
    match /eventos/{eventId} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 3. Crear Usuario Admin
1. Regístrate en la app
2. Ve a Firestore Console → usuarios → tu-usuario
3. Edita el documento:
```json
{
  "role": "admin",
  "rol": "admin",
  "active": true
}
```

---

## 🎨 Características del Código Mejorado

### 1. Logging Estructurado
Ahora verás logs claros en la consola:
```
ℹ️ [INFO] Intentando login con email: usuario@example.com
✅ [SUCCESS] Login exitoso: usuario@example.com
❌ [ERROR] Error de autenticación
   Details: user-not-found
```

### 2. Manejo de Errores
Los errores ahora muestran mensajes en español y claros:
- ❌ "Usuario no encontrado"
- ❌ "Contraseña incorrecta"
- ❌ "Error de conexión. Verifica tu internet."

### 3. Caché Inteligente
Las consultas a Firestore usan caché para:
- ⚡ Reducir latencia
- 💰 Ahorrar costos
- 🚀 Mejorar UX

### 4. Widgets Reutilizables
Usa componentes consistentes en toda la app:
```dart
EmptyStateWidget(
  icon: Icons.inbox,
  title: 'Sin datos',
  subtitle: 'No hay información disponible',
)
```

---

## 📚 Documentación Adicional

- **`MEJORAS_APLICADAS.md`** - Detalles de todas las mejoras
- **`README.md`** - Documentación original del proyecto
- **`INSTRUCCIONES_GITHUB.md`** - Cómo subir a GitHub

---

## 🚀 Comandos Rápidos

```powershell
# Instalar dependencias
flutter pub get

# Ejecutar en web (Edge)
flutter run -d edge

# Ejecutar en Windows (requiere VS)
flutter run -d windows

# Ver dispositivos disponibles
flutter devices

# Limpiar build
flutter clean

# Analizar código
flutter analyze

# Compilar para producción (web)
flutter build web

# Ver logs
flutter logs
```

---

## ✅ Checklist de Verificación

Antes de considerar el proyecto listo:

- [ ] `flutter pub get` ejecutado sin errores
- [ ] `flutter analyze` sin warnings críticos
- [ ] Firebase configurado (Auth + Firestore)
- [ ] `google-services.json` en su lugar
- [ ] App ejecuta en al menos una plataforma
- [ ] Logs estructurados funcionando
- [ ] Puedes hacer login (externo o Google)
- [ ] Usuario admin creado en Firestore

---

## 🎉 ¡Listo!

Tu proyecto ahora tiene:
- ✅ Código más limpio y organizado
- ✅ Mejor manejo de errores
- ✅ Logging estructurado
- ✅ Widgets reutilizables
- ✅ Optimizaciones de rendimiento
- ✅ Documentación completa

**Siguiente paso recomendado**: Leer `MEJORAS_APLICADAS.md` para entender todas las mejoras implementadas.

---

**Desarrollado para**: EVENTOS EPIS - UPT  
**Soporte**: eventos-epis@upt.pe  
**Última actualización**: Octubre 2025

