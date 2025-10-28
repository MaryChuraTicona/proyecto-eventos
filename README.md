# EVENTOS EPIS - UPT

Sistema de gestión de eventos para la Escuela Profesional de Ingeniería de Sistemas de la Universidad Privada de Tacna.

## 📱 Descripción

Aplicación Flutter multiplataforma para gestionar eventos académicos, ponencias, inscripciones y asistencia de estudiantes, docentes y ponentes.

## ✨ Características

### 👥 Roles de Usuario

- **Administrador**: Gestión completa de eventos, ponentes, sesiones y usuarios
- **Estudiante**: Inscripción a eventos, visualización de ponencias y historial
- **Docente**: Acceso a reportes y gestión de eventos
- **Ponente**: Visualización de sus ponencias programadas

### 🎯 Funcionalidades Principales

#### Panel de Administración
- ✅ Gestión de eventos (CATEC, Software Libre, Microsoft, etc.)
- ✅ Administración de ponentes con información detallada
- ✅ Creación y edición de sesiones/ponencias
- ✅ Control de usuarios y roles
- ✅ Reportes y estadísticas
- ✅ Datos de demostración (seed)

#### Para Estudiantes
- ✅ Visualización de eventos disponibles
- ✅ Inscripción a ponencias
- ✅ Historial de participación
- ✅ Generación de códigos QR para asistencia
- ✅ Vista detallada de eventos y sesiones

#### Autenticación
- ✅ Login con correo y contraseña (usuarios externos)
- ✅ Login con Google (usuarios institucionales @virtual.upt.pe)
- ✅ Recuperación de contraseña
- ✅ Registro de nuevos usuarios

#### Sistema de Asistencia
- ✅ Generación de QR por sesión
- ✅ Escaneo de QR para registro de asistencia
- ✅ Control de aforo

## 🚀 Tecnologías

- **Framework**: Flutter 3.32.8 / Dart 3.8.1
- **Backend**: Firebase
  - Authentication (Email/Password + Google Sign-In)
  - Firestore Database
  - Cloud Storage
  - Cloud Functions
- **State Management**: Riverpod
- **UI**: Material Design 3

## 📦 Dependencias Principales

```yaml
firebase_core: ^4.2.0
firebase_auth: ^6.1.1
cloud_firestore: ^6.0.3
firebase_storage: ^13.0.3
flutter_riverpod: ^3.0.3
google_fonts: ^6.3.2
google_sign_in: ^7.2.0
qr_flutter: ^4.1.0
mobile_scanner: ^7.1.2
```

## 🛠️ Instalación y Configuración

### Requisitos Previos

- Flutter SDK (>=3.0.0)
- Cuenta de Firebase
- Android Studio / VS Code
- Git

### Pasos de Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/TU-USUARIO/eventos-epis.git
cd eventos-epis
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Configurar Firebase**
   - Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
   - Descarga y configura:
     - `android/app/google-services.json` (Android)
     - `ios/Runner/GoogleService-Info.plist` (iOS)
   - El archivo `lib/firebase_options.dart` ya está configurado

4. **Habilitar autenticación en Firebase**
   - Ve a Authentication > Sign-in method
   - Habilita "Email/Password"
   - Habilita "Google"

5. **Configurar Firestore**
   - Crea la base de datos en modo producción
   - Las colecciones se crearán automáticamente

6. **Ejecutar la aplicación**
```bash
# Para web
flutter run -d chrome

# Para Edge
flutter run -d edge

# Para Android
flutter run

# Para Windows
flutter run -d windows
```

## 📁 Estructura del Proyecto

```
lib/
├── app/                    # Configuración de la app
│   ├── app_theme.dart      # Tema Material Design
│   ├── router_by_rol.dart  # Navegación por roles
│   └── utils.dart
├── features/               # Características por módulos
│   ├── admin/             # Panel de administración
│   │   ├── forms/         # Formularios
│   │   ├── models/        # Modelos de datos
│   │   ├── services/      # Servicios de Firebase
│   │   └── widgets/       # Widgets reutilizables
│   ├── auth/              # Autenticación
│   ├── events/            # Gestión de eventos
│   ├── student/           # Panel de estudiantes
│   └── attendance/        # Sistema de asistencia QR
├── models/                # Modelos globales
├── services/              # Servicios compartidos
└── main.dart              # Punto de entrada
```

## 🔐 Configuración de Seguridad

### Reglas de Firestore Recomendadas

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Eventos: lectura pública, escritura solo admins
    match /eventos/{eventId} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Usuarios: lectura propia o admin
    match /usuarios/{userId} {
      allow read: if request.auth != null && 
                     (request.auth.uid == userId || 
                      get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin');
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## 👥 Usuarios de Prueba

Para crear el primer usuario admin, registra un usuario y luego modifica su rol en Firestore:

```javascript
// Ir a Firestore > usuarios > [tu-usuario-id]
{
  "email": "admin@virtual.upt.pe",
  "role": "admin",
  "rol": "admin",
  "active": true
}
```

## 🎨 Capturas de Pantalla

_(Agrega capturas de pantalla de tu aplicación aquí)_

## 📝 Notas de Desarrollo

- **AuthWrapper**: Maneja automáticamente el estado de autenticación y redirección por roles
- **Timestamp de Firebase**: Todas las fechas se guardan con `serverTimestamp()` para consistencia
- **Formato de fechas**: Se muestra tiempo relativo (ej: "Hace 2 horas") para mejor UX
- **Validaciones**: Emails institucionales solo para @virtual.upt.pe

## 🐛 Problemas Conocidos

- Chrome en Windows puede tener problemas de conexión en debug. Usar Edge o Windows desktop.
- En Windows, habilitar "Modo Desarrollador" para symlinks.

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto es privado y pertenece a la Universidad Privada de Tacna - EPIS.

## 👨‍💻 Autor

Desarrollado para la Escuela Profesional de Ingeniería de Sistemas - UPT

## 📧 Soporte

Para soporte técnico: eventos-epis@upt.pe

---

**Universidad Privada de Tacna**  
Escuela Profesional de Ingeniería de Sistemas
