# 🚀 Cómo subir tu proyecto a GitHub

## Paso 1: Crear un nuevo repositorio en GitHub

1. **Ve a GitHub** y inicia sesión: https://github.com
2. **Haz clic en el botón "+" en la esquina superior derecha**
3. **Selecciona "New repository"**
4. **Configura tu repositorio:**
   - **Repository name**: `eventos-epis` (o el nombre que prefieras)
   - **Description**: "Sistema de gestión de eventos para EPIS - UPT"
   - **Visibilidad**: 
     - ✅ **Public** (si quieres que todos lo vean y descarguen)
     - ❌ **Private** (si solo tú y colaboradores autorizados pueden verlo)
   - ❌ **NO** marques "Add a README file"
   - ❌ **NO** agregues .gitignore
   - ❌ **NO** agregues licencia
5. **Haz clic en "Create repository"**

## Paso 2: Copiar la URL de tu repositorio

Después de crear el repositorio, GitHub te mostrará una página con instrucciones.

**Copia la URL HTTPS que aparece**, algo como:
```
https://github.com/TU-USUARIO/eventos-epis.git
```

## Paso 3: Ejecutar comandos en tu terminal

Abre PowerShell en la carpeta de tu proyecto y ejecuta estos comandos **UNO POR UNO**:

### 3.1 Agregar el repositorio remoto
```powershell
git remote add origin https://github.com/TU-USUARIO/eventos-epis.git
```
**⚠️ Reemplaza `TU-USUARIO` con tu nombre de usuario de GitHub**

### 3.2 Verificar que se agregó correctamente
```powershell
git remote -v
```
Deberías ver algo como:
```
origin  https://github.com/TU-USUARIO/eventos-epis.git (fetch)
origin  https://github.com/TU-USUARIO/eventos-epis.git (push)
```

### 3.3 Subir tu código a GitHub
```powershell
git push -u origin main
```

Si te pide autenticación:
- **GitHub abrirá tu navegador** para que inicies sesión
- O te pedirá tu **Personal Access Token** (si no tienes, ve al Paso 4)

---

## Paso 4: Si te pide un Personal Access Token

Si Git te pide un token en lugar de contraseña:

1. **Ve a GitHub** → Haz clic en tu foto de perfil (esquina superior derecha)
2. **Settings** → **Developer settings** (al final del menú izquierdo)
3. **Personal access tokens** → **Tokens (classic)**
4. **Generate new token** → **Generate new token (classic)**
5. **Configura el token:**
   - **Note**: "Token para eventos-epis"
   - **Expiration**: 90 días (o el tiempo que prefieras)
   - **Scopes**: Marca ✅ **repo** (todos los permisos de repositorio)
6. **Haz clic en "Generate token"**
7. **COPIA EL TOKEN** (solo se muestra una vez)
8. **Úsalo como contraseña** cuando Git te lo pida

---

## ✅ Verificar que todo funcionó

1. **Ve a tu repositorio en GitHub:**
   ```
   https://github.com/TU-USUARIO/eventos-epis
   ```

2. **Deberías ver:**
   - ✅ Todos tus archivos y carpetas
   - ✅ El README.md con la documentación
   - ✅ Los commits que hiciste

---

## 🎉 ¡Listo! Ahora otros pueden descargar tu proyecto

### Para que otros descarguen tu proyecto:

**Método 1: Clonar con Git** (recomendado para desarrolladores)
```bash
git clone https://github.com/TU-USUARIO/eventos-epis.git
cd eventos-epis
flutter pub get
```

**Método 2: Descargar ZIP**
1. Ve a tu repositorio en GitHub
2. Haz clic en el botón verde "Code"
3. Selecciona "Download ZIP"
4. Descomprime y abre en Flutter

---

## 🔄 Para actualizar tu código en GitHub (futuras actualizaciones)

Cada vez que hagas cambios y quieras subirlos:

```powershell
# 1. Ver qué archivos cambiaron
git status

# 2. Agregar todos los cambios
git add .

# 3. Hacer commit con un mensaje descriptivo
git commit -m "Descripción de los cambios"

# 4. Subir a GitHub
git push
```

---

## 🛡️ Archivos que NO debes subir (ya están en .gitignore)

- ❌ `google-services.json` (Android)
- ❌ `GoogleService-Info.plist` (iOS)
- ❌ Claves API o secretos
- ❌ `build/` (carpeta de compilación)
- ❌ `.dart_tool/` (herramientas de Dart)

**NOTA:** Si accidentalmente subiste archivos sensibles, puedes eliminarlos del historial con:
```bash
git rm --cached ruta/al/archivo
git commit -m "Eliminar archivo sensible"
git push
```

---

## 📧 ¿Problemas?

- **Error "repository not found"**: Verifica que la URL sea correcta y que tengas acceso al repositorio
- **Error "authentication failed"**: Usa un Personal Access Token en lugar de tu contraseña
- **Error "permission denied"**: Asegúrate de ser el dueño del repositorio o tener permisos de escritura

---

## 🎯 Resumen rápido

```powershell
# Agregar remote
git remote add origin https://github.com/TU-USUARIO/eventos-epis.git

# Subir código
git push -u origin main
```

**¡Ya está! Tu proyecto está en GitHub y listo para compartir** 🎉

