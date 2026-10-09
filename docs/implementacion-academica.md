# Implementación académica y verificación

Esta entrega evoluciona el diagnóstico de `revision-app-vs-presentacion.md`. Ese documento describe el estado anterior y se conserva como antecedente, no como inventario actualizado de errores.

## Bloques implementados y comprobados en orden

1. **Motor anterior:** corte histórico sin pagos futuros; rechazo de cantidades inválidas; excedentes separados del interés; vencimientos mensuales calendario. Se conservaron las pruebas existentes del motor.
2. **Persistencia:** operación y auditoría en una sola entrada Hive; cola serial de escrituras; pagos reconciliados; importaciones validadas antes de guardar; eliminación de clientes/préstamos con dependencias bloqueada. Los cambios del negocio guardan actor, rol, fecha y estados anterior/posterior.
3. **Sesión y cartera anterior:** cerrar sesión conserva preferencias e índice de comprobantes; los sobrepagos nuevos se rechazan; ganancias basadas en interés realmente aplicado; las alertas visuales no cambian el scoring. Un abono insuficiente no oculta el vencimiento pendiente. El PIN puede recuperarse reautenticando la cuenta, sin reinstalar.
4. **Motor contractual nuevo:** Francés, Alemán, centavos, cuotas mensuales, seguro, comisión y mora separados. Se probaron referencias numéricas, redondeo final, tasa cero, pagos parciales, corte histórico y exceso.
5. **Evaluación:** perfil financiero, DTI, puntaje explicativo y recomendación. Umbral DTI configurable por gerencia; versión y parámetros conservados en cada evaluación. La prueba de rendimiento local cumple el objetivo de tres segundos para generación/evaluación de un plan de 360 meses.
6. **Identidad y proceso:** cuentas separadas de solicitante, analista, cumplimiento y gerencia; registro de solicitantes, cambio de contraseña, TOTP opcional, bloqueo temporal por intentos y caducidad de sesión. Se probaron permisos negativos, privacidad de expedientes, devolución y nueva evaluación.
7. **Aprobación:** borrador → análisis → cumplimiento → gerencia → aprobación/rechazo. Sin aprobación no se genera el plan. Motivos obligatorios y conservación de decisiones. Los nuevos préstamos directos de la cartera anterior están bloqueados.
8. **Operación:** bandeja con búsqueda y filtros, expediente, tabla de cuotas, saldo contractual, indicadores de cartera y mora, pagos con referencias únicas y anulaciones con motivo. Los pagos anulados permanecen visibles. Un saldo cero se muestra como saldado.
9. **Documentos:** PDF/JSON del expediente y plan; respaldo completo v2 y restauración atómica. Se prueba la generación real de bytes PDF, ida/vuelta del respaldo y rechazo de un plan modificado. En web se descargan bytes mediante FilePicker; en nativo se guardan/comparten. Las exportaciones e importaciones históricas también tienen rutas web.
10. **Interfaz:** pruebas de navegación, envío y validación del formulario, más gerencia a 390×844. Se detectó un desbordamiento y se corrigió con desplazamiento mediante slivers antes de volver a probar.

## Organización

- `credit_engine.dart`: reglas financieras y cálculo de cuotas/saldos.
- `credit_service.dart`: casos de uso y transiciones autorizadas.
- `local_database_service.dart`: identidad local, persistencia, auditoría y respaldo.
- `credit_portal_screen.dart`: bandeja, expediente, formularios y seguridad de cuenta.
- `credit_documents.dart` / `document_files.dart`: construcción de reportes y escritura por plataforma.
- La cartera histórica permanece separada para no reinterpretar automáticamente los contratos anteriores con reglas bancarias nuevas.

## Reglas que deben revisarse con la profesora

La presentación no determina tasas, umbrales de riesgo, forma de cobrar seguro/comisión/mora ni tratamiento de anticipos. La implementación usa reglas académicas explícitas descritas en README. Los pagos adelantados cubren cuotas pactadas y no recalculan intereses por prepago. Una recomendación desfavorable impide avanzar; no hay excepción automática de gerencia. El 2FA puede activarse por cuenta; no es obligatorio en el primer acceso de las cuentas de demostración.

## Límites de la verificación

- Las pruebas de interfaz corren en el entorno de Flutter; un tamaño móvil simulado no equivale a probar un teléfono físico.
- La compilación web verifica generación del artefacto. No acredita por sí sola la descarga/compartición en todos los navegadores ni los permisos de Android/iOS.
- Biometría, notificaciones del sistema, instaladores y compartir requieren una prueba de aceptación en el dispositivo elegido para la exposición.
- El botón de recordatorio programa Android/iOS con el conteo disponible al pulsarlo; no existe un servidor ni una tarea remota que actualice ese conteo con la app cerrada.
- No hay sincronización entre dispositivos, cifrado de toda la base en reposo ni resistencia frente a la manipulación de archivos por el propietario del dispositivo. Es una simulación local.
- La bitácora es de solo lectura desde la interfaz. Los hashes encadenados aportan evidencia de encadenamiento, no una firma externa ni garantía contra un administrador del equipo.
- Los respaldos v2 no contienen contraseñas/2FA. Para restaurar expedientes de cuentas personalizadas se necesita la instalación con los mismos identificadores de usuario. La migración completa de identidades entre equipos queda pendiente.
- La cartera histórica mantiene pantallas extensas y parte de su código de caché. El flujo nuevo se separó en módulos; no se hizo una reescritura completa de todas las pantallas históricas.

## Aceptación manual para la exposición

Seguir el recorrido del README con las cuatro cuentas en la aplicación de escritorio de Windows. Probar ambos sistemas de amortización; intentar aprobar con el rol incorrecto; devolver y corregir una solicitud; rechazar otra; registrar y anular un pago; exportar PDF/JSON; respaldar y restaurar; revisar los motivos y actores en la bitácora. Windows es la plataforma principal de aceptación para la exposición.

## Comandos de validación

```sh
flutter analyze
flutter test
flutter build windows
```

Los resultados finales de esos comandos se informan en la entrega. Las pruebas nuevas están en `credit_engine_test.dart`, `credit_workflow_test.dart`, `credit_portal_test.dart`, `financial_regressions_test.dart` y `local_provider_regression_test.dart`; se ampliaron también las de persistencia local.

Resultado de la suite final: **39 pruebas aprobadas**. Análisis estático: **sin incidencias**. Incluye una prueba adicional de sesión caducada para volver al acceso y bloquear nuevas operaciones.

Compilación de escritorio Windows: **correcta** mediante `flutter build windows`.
Artefacto: `build/windows/x64/runner/Release/mi_app_flutter.exe`.
La compilación no sustituye el recorrido manual dentro de la aplicación; quedan
por comprobar allí Windows Hello, los diálogos nativos y compartir documentos.

## Revisión de usabilidad en Windows

- Acceso compacto, validación junto a los campos, contraseña visible a petición,
  envío con Enter y código 2FA desplegado solo cuando el usuario lo necesita.
- Tema compartido para colores, tipografía, campos, tarjetas y botones; controles
  de al menos 48 píxeles y contenido limitado en ventanas amplias.
- Navegación inferior: Solicitudes, Herramientas (gerencia) y Mi cuenta.
  Las tareas administrativas ya no compiten con la búsqueda y el resumen.
- Expedientes con estados legibles, progreso, instrucciones del siguiente paso
  y decisiones traducidas. Cuotas como tarjetas en ventanas estrechas.
- Solicitud organizada en crédito, capacidad de pago y cargos opcionales.
- Cerrar sesión requiere confirmación; la acción de recordatorios móviles se
  retiró del portal usado en Windows porque no programa notificaciones allí.

Validación tras el rediseño: **42 pruebas aprobadas** y análisis estático sin
incidencias. Incluye navegación de gerencia a herramientas/cuenta, cancelación de
cierre de sesión, validación del acceso, 2FA desplegable y formulario estrecho
con texto ampliado. La cartera histórica conserva su organización anterior;
este rediseño se concentra en el acceso y el flujo académico de créditos.
