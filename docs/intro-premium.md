# Intro de Contador Engine

Esta es la intro adoptada para la aplicación, aprobada el 11 de octubre de 2026.

La intro dura 3,4 segundos desde que el logo está decodificado. Usa el logo
original sobre un degradado morado con dos ondas amplias y discretas dibujadas
en Flutter. No necesita imágenes nuevas, vídeos, red ni paquetes adicionales.

| Tiempo | Movimiento |
| --- | --- |
| 0–950 ms | Logo centrado: opacidad 0→1, escala 90 %→100 %, easeOutCubic. |
| 950–1550 ms | Pausa con el logo quieto. |
| 1550–3200 ms | El fondo se desliza hacia arriba con easeInOutCubic. |
| 1650–2350 ms | El logo desaparece suavemente, sube 24 px y se reduce un 4 %. |
| 1750–3200 ms | El login real aparece con fade y desplazamiento de 20 px. |
| 3200–3400 ms | Pantalla estable; termina la intro y se habilita el formulario. |

`lib/widgets/welcome_entrance.dart` coordina las fases con un único
AnimationController y curvas independientes. El fondo estático y el logo tienen
RepaintBoundary; el formulario no se reconstruye en cada frame. El login y el
navegador conservan su estado al terminar. La intro solo se reproduce al iniciar
la app: navegar, reconstruir el tema o cerrar sesión no la vuelve a ejecutar.
Una sesión guardada conserva su destino habitual después de la intro.

El login se pinta al 1 % de opacidad detrás del fondo completamente opaco durante
la preparación. Así sus textos y capas se preparan antes de empezar a revelarse;
una opacidad cero omitiría ese trabajo hasta el primer fotograma visible.

Durante la intro se bloquean interacción, foco y semántica del contenido tapado.
La preferencia del sistema de reducir animaciones omite la intro, incluso si
cambia durante la reproducción. El diseño se adapta al tamaño disponible.

## Validación

```powershell
flutter analyze
flutter test test/welcome_entrance_test.dart test/auth_flow_test.dart test/ui_redesign_test.dart
flutter build windows
```

Las pruebas comprueban el acceso al formulario, su estado al terminar y al
reconstruir, movimiento reducido, cambio de tamaño durante la transición y
ventanas de 320, 390 y 1280 px. Para generar capturas de las fases en `.review/`:

```powershell
$env:SAVE_INTRO_PREVIEW='1'
flutter test test/welcome_entrance_test.dart
```

La fluidez debe revisarse en una compilación release o profile; debug no sirve
para medir el rendimiento final. Las capturas y pruebas de widgets verifican
composición y comportamiento, no la tasa de fotogramas de un dispositivo físico.

Validación local del 11 de octubre de 2026: análisis sin incidencias y 19 pruebas
aprobadas entre intro, acceso y navegación. En Windows profile se recogieron
629 fotogramas: percentil 95 de construcción 0,237 ms y de rasterizado 0,574 ms.
El primer fotograma de preparación tardó 88,882 ms en rasterizar; los restantes
no superaron 7,564 ms. Preparar el login bajo el splash eliminó el pico de
rasterizado de 25,778 ms observado al empezar el revelado en la primera medición.
Los datos locales están en `.review/intro-profile-frames.json`, generados con
`.review/intro_profile.dart`. Estas cifras corresponden a este equipo; no se ha
medido el rendimiento en un teléfono físico.

## Volver a la versión anterior

La versión anterior a la intro se conserva en el commit
`5aadef782e5e4e8e871b4d229a3ea9a17ef49e49` de `contador_enginev2`.
En el equipo de desarrollo también se guardó una copia exacta de
`lib/widgets/app_ui.dart` y un manifiesto con SHA-256 en
`.review/intro-before-20261011/`.

Para retirar únicamente esta idea, restaurar `app_ui.dart` desde ese commit
o la copia local y quitar `lib/widgets/welcome_entrance.dart`,
`test/welcome_entrance_test.dart` y este documento. Si después se modifican
esos archivos, revisar el diff antes de restaurar para conservar cambios ajenos.
Luego volver a compilar Windows. No hay migraciones ni cambios en datos locales.
