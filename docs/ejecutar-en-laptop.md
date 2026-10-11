# Ejecutar Contador Engine en tu laptop

Esta guía instala las herramientas, descarga el proyecto y abre la aplicación
de escritorio. Usa PowerShell en Windows y Bash en Linux.

- [Windows](#windows)
- [Linux: Ubuntu y Debian](#linux-ubuntu-y-debian)
- [Primer inicio de sesión](#primer-inicio-de-sesión)
- [Actualizar el proyecto](#actualizar-el-proyecto)
- [Problemas frecuentes](#problemas-frecuentes)

## Antes de empezar

Necesitas conexión a internet para descargar herramientas y dependencias. El
negocio funciona con una base Hive local: no debes configurar Supabase, SQL,
Node.js, Docker ni un archivo `.env` para abrir esta versión.

| Dato | Referencia del proyecto |
| --- | --- |
| Flutter usado en Windows y en el workflow de Android | **3.41.7** |
| Dart incluido en ese SDK | **3.11.5**; se instala junto con Flutter. |
| Mínimo de las dependencias de `pubspec.lock` | Flutter **3.41.0**, Dart **3.11.0** (menor que 4.0). |
| Archivo que indica la raíz del proyecto | `pubspec.yaml` |
| Windows | Compilación release y ejecución comprobadas. |
| Linux | Runner y dependencias revisados; compilación y ejecución pendientes de prueba en Linux. |

Usa Flutter 3.41.7 para reproducir el entorno documentado y conserva
`pubspec.lock`. El rango de Dart declarado en `pubspec.yaml` es más amplio que
el mínimo que exigen los paquetes actualmente instalados.

Los pasos se orientan a laptops **x64**. En Linux se toma como referencia un
escritorio Ubuntu 24.04 LTS; las distribuciones Debian compatibles usan los
mismos comandos de `apt`, aunque la disponibilidad de paquetes puede variar.
Para otros gestores de paquetes, adapta los nombres según la
[configuración oficial de Flutter para Linux](https://docs.flutter.dev/platform-integration/linux/setup).

## Windows

### 1. Instalar Git y las herramientas de C++

1. Instala [Git para Windows](https://git-scm.com/downloads/win) y vuelve a abrir
   PowerShell. Comprueba que `git --version` responde.
2. Instala [Visual Studio Community](https://visualstudio.microsoft.com/vs/community/).
   En su instalador selecciona **Desarrollo para el escritorio con C++**
   (**Desktop development with C++**). Mantén los componentes de MSVC, CMake y
   Windows SDK que propone esa carga de trabajo.
3. En **Componentes individuales**, incluye **C++ ATL** para la versión de MSVC
   instalada, necesario para el almacenamiento seguro usado por el proyecto.
4. Activa **Modo de desarrollador** desde la configuración de Windows para que
   Flutter pueda crear enlaces simbólicos. Puedes buscar ese nombre en Inicio.

Visual Studio Code es un editor opcional; por sí solo no instala el compilador
de Windows. Consulta los requisitos de
[Flutter para Windows](https://docs.flutter.dev/platform-integration/windows/setup)
y de [almacenamiento seguro](https://pub.dev/packages/flutter_secure_storage/versions/10.3.1#windows).

### 2. Instalar Flutter 3.41.7

Si ya tienes esa versión, pasa a la comprobación del paso 3. Para instalar una
copia nueva, ejecuta en PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\develop"
git clone --branch 3.41.7 --depth 1 https://github.com/flutter/flutter.git "$env:USERPROFILE\develop\flutter"
```

La carpeta de destino `flutter` debe estar libre. Si ya existe otro SDK, utiliza
su instalación o elige otra carpeta; no borres el SDK de otro proyecto. El aviso
de Git sobre `detached HEAD` es normal al descargar una versión concreta.

Añade Flutter al `Path` **de tu usuario**:

1. Busca **Editar las variables de entorno de esta cuenta** en Inicio.
2. Abre `Path` → **Editar** → **Nuevo**.
3. Añade `%USERPROFILE%\develop\flutter\bin`.
4. Acepta los cambios y cierra y abre PowerShell y tu editor.

También puedes descargar el SDK 3.41.7 para Windows desde el
[archivo oficial de Flutter](https://docs.flutter.dev/install/archive), extraer
la carpeta `flutter` en `develop` y seguir el mismo ajuste de `Path`.
La [guía de instalación manual](https://docs.flutter.dev/install/manual)
explica otras ubicaciones y la configuración de la terminal.

### 3. Comprobar las herramientas

```powershell
flutter --version
flutter config --enable-windows-desktop
flutter doctor -v
flutter devices
```

La primera ejecución puede tardar mientras Flutter descarga su SDK de Dart y
otros archivos. Debes ver **Windows** entre los dispositivos y sin errores en
la sección de **Visual Studio** de `flutter doctor`. Los avisos de Android
Studio o del SDK de Android no impiden ejecutar este proyecto en Windows.

### 4. Descargar y abrir el proyecto

Desde una carpeta de trabajo, por ejemplo:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\proyectos"
Set-Location "$env:USERPROFILE\proyectos"
git clone https://github.com/klhetvintellez23-cpu/contador_enginev2.git
Set-Location contador_enginev2
flutter pub get
flutter run -d windows
```

Si GitHub solicita acceso, usa la cuenta que tenga permiso para el repositorio.
También puedes abrir el repositorio en GitHub, seleccionar **Code → Download
ZIP**, extraerlo y abrir PowerShell dentro de la carpeta que contiene
`pubspec.yaml`. En ese caso ejecuta solo `flutter pub get` y `flutter run -d windows`.

La primera compilación suele tardar más. Al terminar se abre **Contador Engine**.
Mantén la terminal abierta durante el desarrollo: `r` recarga cambios, `R`
reinicia la app y `q` la cierra. Continúa con el
[primer inicio de sesión](#primer-inicio-de-sesión).

### 5. Generar el ejecutable de Windows

Cierra cualquier instancia de la app antes de recompilar. Desde la raíz:

```powershell
flutter build windows --release
.\build\windows\x64\runner\Release\mi_app_flutter.exe
```

Puedes abrir ese `.exe` directamente desde el Explorador. Para llevar la app a
otra laptop Windows x64, copia **toda** la carpeta `Release`, incluidos sus DLL
y la carpeta `data`. La laptop que solo ejecuta el paquete no necesita Flutter
ni Visual Studio. Si faltan las bibliotecas de Visual C++, instala el
[redistribuible oficial de Microsoft para x64](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).

Para revisar la intro optimizada desde el código también puedes usar
`flutter run -d windows --release`. Ese modo no tiene hot reload.

## Linux: Ubuntu y Debian

### 1. Instalar las herramientas del sistema

Abre una terminal **dentro de tu sesión gráfica de Linux**. Estos comandos usan
`apt`; en Ubuntu 24.04 LTS:

```bash
sudo apt update
sudo apt install -y git curl unzip xz-utils zip ca-certificates \
  clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev \
  libsecret-1-dev libsecret-1-0 gnome-keyring xdg-utils
```

GTK y las herramientas de C++ permiten compilar el runner Linux. `libsecret`
y un llavero activo, como GNOME Keyring, permiten guardar el PIN y las
preferencias de bloqueo. En un escritorio GNOME normalmente el llavero se
desbloquea al iniciar sesión. Si acabas de instalarlo, cierra sesión y vuelve
a entrar al escritorio. Estos requisitos están documentados por
[Flutter](https://docs.flutter.dev/platform-integration/linux/setup) y por
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/versions/10.3.1#linux).

### 2. Instalar Flutter 3.41.7 y configurar Bash

Si ya lo tienes instalado, comprueba su versión y pasa al paso 3. Para una
copia nueva:

```bash
mkdir -p "$HOME/develop"
git clone --branch 3.41.7 --depth 1 https://github.com/flutter/flutter.git "$HOME/develop/flutter"
echo 'export PATH="$HOME/develop/flutter/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

Ejecuta la línea que añade el `PATH` una sola vez. La carpeta `develop/flutter`
debe estar libre; conserva cualquier SDK que ya uses para otro proyecto.
El aviso `detached HEAD` corresponde a la versión fijada. Usa tu usuario normal
para Flutter y el proyecto; reserva `sudo` para instalar paquetes del sistema.

Como alternativa, descarga y extrae el SDK 3.41.7 para Linux desde el
[archivo oficial](https://docs.flutter.dev/install/archive) en `~/develop/`.
Si tu terminal utiliza Zsh u otro shell, adapta el archivo de inicio según la
[guía oficial de PATH](https://docs.flutter.dev/install/manual).

### 3. Comprobar las herramientas

```bash
flutter --version
flutter config --enable-linux-desktop
flutter doctor -v
flutter devices
```

La sección **Linux toolchain** debe quedar sin errores y `flutter devices` debe
mostrar **Linux**. Los avisos relacionados exclusivamente con Android no
impiden compilar para Linux. Esta guía usa el escritorio Linux local; una
terminal SSH sin sesión gráfica o WSL sin configuración gráfica adicional
no equivale a ese entorno.

### 4. Descargar y abrir el proyecto

```bash
mkdir -p "$HOME/proyectos"
cd "$HOME/proyectos"
git clone https://github.com/klhetvintellez23-cpu/contador_enginev2.git
cd contador_enginev2
flutter pub get
flutter run -d linux
```

Necesitas acceso al repositorio para clonarlo. Si no tienes configurada la
autenticación de Git, inicia sesión en GitHub con tu cuenta autorizada, descarga
**Code → Download ZIP**, extrae el archivo y abre la terminal dentro de la
carpeta que contiene `pubspec.yaml`. Ejecuta allí los dos comandos de Flutter.

Espera a que termine la primera compilación y aparezca la ventana. En la
terminal, `r` recarga cambios, `R` reinicia y `q` cierra la app. Sigue con el
[primer inicio de sesión](#primer-inicio-de-sesión).

### 5. Generar el ejecutable de Linux

Cierra la instancia abierta antes de compilar:

```bash
flutter build linux --release
./build/linux/x64/release/bundle/mi_app_flutter
```

Para copiar la aplicación, conserva **toda** la carpeta `bundle`, incluidos
`lib/` y `data/`. El equipo de destino debe tener una arquitectura y bibliotecas
del sistema compatibles. Puedes revisar dependencias con:

```bash
ldd build/linux/x64/release/bundle/mi_app_flutter
ldd build/linux/x64/release/bundle/lib/libflutter_secure_storage_linux_plugin.so
```

Una línea `not found` indica una biblioteca del sistema pendiente de instalar.
Consulta la [distribución de aplicaciones Linux de Flutter](https://docs.flutter.dev/platform-integration/linux/building#prepare-linux-apps-for-distribution).
Para revisar la intro en modo optimizado desde el código usa
`flutter run -d linux --release`.

La compilación de Windows se realiza en Windows y la de Linux en Linux.
El `.exe` de Windows no es el ejecutable nativo para Linux.

## Primer inicio de sesión

1. Al abrir la aplicación se reproduce la intro y aparece el acceso. Si hay
   una sesión anterior válida, la app conserva su destino habitual.
2. Selecciona una cuenta de la tabla. La contraseña inicial de todas es
   `ContadorLocal2026!`.

   | Rol | Correo |
   | --- | --- |
   | Gerencia | `admin@contador.local` |
   | Solicitante | `cliente@contador.local` |
   | Analista | `analista@contador.local` |
   | Cumplimiento | `cumplimiento@contador.local` |

3. Pulsa **Iniciar sesión**. En la siguiente pantalla copia los cuatro
   caracteres mostrados en **Código de prueba actual** y pulsa **Verificar
   código**. Si cambia el código, utiliza el nuevo. Se trata de una verificación
   local de demostración, sin envío por correo o SMS.
4. Se abrirá el inicio correspondiente al rol. También puedes crear una cuenta
   nueva de solicitante desde **¿Primera vez? Crear cuenta**.

Si cambiaste una contraseña anteriormente, se conserva la nueva. La base de
datos se crea al iniciar y queda en el almacenamiento del usuario del sistema,
fuera del código fuente. Cerrar, recompilar o actualizar la app no crea una
base compartida: **cada laptop conserva sus propios datos**. Los datos del
negocio se respaldan desde la app; consulta [datos y recuperación](../README.md#datos-recuperación-y-respaldo).

En Linux, la dependencia actual de biometría no incluye implementación para ese
sistema; utiliza el acceso y el PIN disponibles. La dependencia de compartir
archivos tampoco admite Linux: los errores de compartir un PDF no se resuelven
instalando un SDK de Android. Los recordatorios del sistema y el instalador
automático de APK son funciones móviles, no requisitos para abrir el escritorio.

## Actualizar el proyecto

Con la app cerrada, desde una copia clonada y sin cambios locales pendientes:

```sh
git status
git pull --ff-only
flutter pub get
```

Vuelve a ejecutar `flutter run -d windows` o `flutter run -d linux`. Para renovar
un ejecutable independiente, repite el comando de compilación de tu sistema.
Si tienes cambios propios, guárdalos antes de actualizar. Si descargaste un ZIP,
descarga la nueva versión y extráela en otra carpeta; ese ZIP no permite `git pull`.

## Problemas frecuentes

| Mensaje o síntoma | Qué revisar |
| --- | --- |
| `flutter` o `git` no se reconoce | Reabre la terminal y comprueba el `Path`. Windows: `Get-Command flutter, git`. Linux: `command -v flutter git`. |
| `Repository not found` al clonar | Confirma la invitación y que tu cuenta tiene acceso al repositorio; prueba abrirlo en el navegador. |
| `No pubspec.yaml file found` | Entra en la carpeta raíz del proyecto, no en su carpeta contenedora. |
| Error de versión de Dart/Flutter o `version solving failed` | Compara `flutter --version` con la versión de referencia. Conserva `pubspec.lock` y ejecuta `flutter pub get` con el SDK correcto. |
| Falta Visual Studio, MSVC, ATL o Windows SDK | Modifica la instalación de Visual Studio y completa el paso 1 de Windows; repite `flutter doctor -v`. |
| `Building with plugins requires symlink support` | Activa Modo de desarrollador en Windows y vuelve a abrir la terminal. |
| `LNK1168`, `Access is denied` o no se puede escribir el `.exe` | Cierra las instancias abiertas de Contador Engine antes de recompilar. |
| `Nuget.exe not found` durante Windows | Si Flutter continúa con la descarga o una copia en caché, espera. Si la compilación falla, revisa el acceso de red a NuGet y el error final. |
| Falta `gtk+-3.0`, `libsecret-1`, Clang, CMake o Ninja | Revisa los paquetes del paso 1 de Linux y la sección Linux toolchain de `flutter doctor -v`. |
| Error de `org.freedesktop.secrets` o llavero bloqueado | Inicia sesión en el escritorio con un servicio de llavero activo y desbloqueado; revisa GNOME Keyring o el servicio de tu escritorio. |
| `cannot open display` | Ejecuta desde una sesión gráfica Linux local. |
| El dispositivo Windows/Linux no aparece | Comprueba que estás en ese sistema, habilita su destino con `flutter config` y ejecuta `flutter devices`. |
| La intro se ve lenta en desarrollo | Prueba `flutter run -d windows --release` o `flutter run -d linux --release`; debug añade sobrecarga. |
| No se reproduce la intro | Reabre la app para repetirla. La opción de accesibilidad de reducir animaciones omite la intro. |
| Faltan DLL o recursos al copiar la app | Conserva la carpeta completa `Release` o `bundle`, según la plataforma. |

Si cambiaste de SDK o moviste el proyecto y CMake conserva rutas antiguas,
regenera los archivos de compilación desde la raíz:

```sh
flutter clean
flutter pub get
```

Después repite el comando de ejecución de tu sistema. `flutter clean` elimina
archivos generados de compilación; no es un procedimiento para borrar la base
del negocio. Si el fallo continúa, comparte el error completo y la salida de
`flutter doctor -v`.

## Comprobar cambios de código

Desde la raíz, en cualquiera de los sistemas con Flutter configurado:

```sh
flutter analyze
flutter test
```

La prueba definitiva del escritorio es compilar y ejecutar en la plataforma
objetivo. No es necesario ejecutar las pruebas cada vez que quieras abrir la app.
