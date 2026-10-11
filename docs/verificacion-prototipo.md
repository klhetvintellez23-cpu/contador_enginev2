# Verificación local del prototipo

El login valida correo y contraseña sin abrir una sesión. La pantalla siguiente
crea una sola instancia de `PrototypeVerificationCode` por intento de acceso.
Genera cuatro caracteres de `A-Z` y `0-9` con `Random.secure()` (con alternativa
para plataformas que no lo soportan), sin repetir el código inmediatamente
anterior. El código fijo `1234` dejó de ser una clave de acceso.

El mismo objeto conserva el código vigente, su vencimiento y los segundos
restantes, y valida lo que se escribe. Programa un único tick pendiente contra
el vencimiento absoluto, en vez de sumar callbacks. A los 60 segundos invalida
el código y lo renueva automáticamente. Reenviar también invalida el anterior
y comienza un minuto completo, cancelando primero el tick pendiente.

El reenvío manual exige esperar 60 segundos desde la entrada o el último reenvío
manual. La interfaz deshabilita el botón y el modelo rechaza los intentos
anticipados, sin cambiar el código ni prolongar el bloqueo. La renovación
automática no reinicia este bloqueo: al cumplir el minuto se permite un reenvío
manual y, al usarlo, comienza otra espera de 60 segundos.

Al recuperar el primer plano se recalcula el intervalo vigente. Validar también
revisa el vencimiento, incluso antes del siguiente tick. Reconstruir widgets
no crea otro código ni reinicia el reloj. Volver al login, completar el acceso
o cerrar la pantalla libera el temporizador y los controladores.

Las casillas conservan su diseño y comparten un buffer de edición para aceptar
pegado, borrado y corrección con teclados móviles y Windows. Solo aceptan ASCII
alfanumérico; las letras se convierten a mayúsculas. Cuando se renueva el código,
se limpian las casillas y se muestra un aviso discreto.

## Exclusivo del prototipo académico

La franja «Código de prueba actual» muestra el código por petición del prototipo.
Se oculta compilando con `--dart-define=SHOW_PROTOTYPE_CODE=false`. En producción
también se debe sustituir la generación y validación local por un servicio
confiable y un canal real de entrega. Ocultar la franja, por sí solo, no convierte
este flujo local en autenticación de producción.

La API existente `signIn` mantiene su verificación TOTP. El flujo de interfaz
del prototipo usa `beginPrototypeSignIn` / `completePrototypeSignIn`, mantiene
la validación de contraseña y el rol de la cuenta, y no abre una sesión hasta
validar el código actual. No se modifican datos ni cálculos financieros.

## Comprobaciones

- `test/prototype_verification_code_test.dart`: formato, renovación sin repetición,
  rechazo exacto al vencer, recuperación tras varios minutos en segundo plano,
  reenvío, bloqueo de 100 intentos consecutivos y liberación.
- `test/auth_flow_test.dart`: acceso y registro, rechazo de códigos incorrectos
  y sustituidos, permisos de rol, retorno, pegado y mayúsculas, borrado, reenvío,
  renovación automática, reconstrucciones y tamaños de 320 a 1280 píxeles.

Validación del 10 de octubre de 2026: `flutter analyze --no-pub` sin incidencias
y `flutter test --no-pub --reporter expanded` con 78 pruebas aprobadas. También
se revisaron capturas del acceso y la verificación a 320, 390 y 1280 píxeles.
