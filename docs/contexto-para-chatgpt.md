# Contexto de Contador Engine para ChatGPT

Este documento describe el código revisado el 9 de octubre de 2026. Si vas a
modificar el proyecto, comprueba sus archivos actuales antes de dar por hecho
que todos los detalles siguen iguales.

## Qué es la aplicación

Mi aplicación se llama Contador Engine. Sirve para administrar clientes,
préstamos, intereses, cobros, capital, comprobantes y reportes de un negocio.
Quiero seguir mejorando la aplicación original y conservar sus datos y reglas.

Está desarrollada en Flutter, con el lenguaje Dart y componentes Material 3.
Se está compilando y revisando en Windows. También tiene código y servicios
para móvil, con funciones nativas cuyo soporte depende de la plataforma.
No se debe asumir que probar Windows valida también Android o iOS.

## Organización del código

- `lib/main.dart`: inicia los servicios locales, crea `DebtProvider`, configura
  el tema y decide qué pantalla abrir según la sesión y el rol del usuario.
- `lib/screens/`: pantallas y formularios. Incluye el inicio original,
  préstamos, detalle del cliente, cobros, informes, cierre diario, capital,
  comprobantes, ajustes, acceso y el portal de crédito.
- `lib/widgets/`: componentes reutilizables, comprobantes, calculadora rápida,
  diálogos de actualización y elementos de interfaz y movimiento.
- `lib/providers/debt_provider.dart`: mantiene el estado de la cartera original,
  coordina operaciones con la base local, calcula indicadores y avisa a la
  interfaz cuando debe actualizarse. Usa Provider y ChangeNotifier.
- `lib/models/`: define los datos y los cálculos financieros. Hay modelos de
  cliente, préstamo (`LoanTransaction`), pago y movimiento de capital, además
  de dos motores financieros distintos.
- `lib/services/`: persistencia y autenticación local, solicitudes de crédito,
  preferencias y caché, bloqueo de acceso, TOTP, notificaciones y actualizaciones.
- `lib/utils/`: tema visual, estilos, exportación, documentos, importación de
  respaldos y utilidades compartidas.
- `test/`: pruebas financieras, de persistencia, permisos, autenticación,
  solicitudes de crédito y flujos de interfaz.

La separación es práctica, no una arquitectura estricta: parte de las reglas
y los indicadores vive en `DebtProvider`, y la base local también valida datos
y permisos. No hay un servidor remoto de negocio en la implementación actual.

## Datos y funcionamiento local

La aplicación usa Hive para guardar los datos en el dispositivo.
`LocalDatabaseService` abre la base `contador_local_database_v1`, administra
usuarios y sesiones y guarda el estado del negocio. Sus operaciones de negocio
se serializan y registran una bitácora junto con los cambios.

`LocalCacheService` guarda preferencias, un espejo de datos, comprobantes y una
cola de operaciones. Esa infraestructura no significa que exista actualmente
sincronización con una nube: el negocio funciona con la base local.

La aplicación actual no necesita Supabase ni una API propia para prestar y
registrar cobros. Puede usar internet para funciones auxiliares, como consultar
GitHub Releases para actualizaciones de Android. Los datos del negocio no
están cifrados en reposo.

## Cartera original: la base que quiero conservar

La cuenta de Gerencia/administración abre `HomeScreen`. Su navegación actual
es Inicio, Solicitudes, Cartera y Perfil; usa una cápsula inferior flotante en
móvil y escritorio. Cartera reutiliza las vistas
originales de Clientes, Cobros e Informes. Los ajustes del negocio están en Perfil.

Desde esta cartera puedo crear clientes y préstamos directamente, registrar
cobros, consultar saldos e intereses, revisar vencimientos, administrar capital,
consultar gráficos, realizar cierres diarios y gestionar comprobantes y respaldos.

Los préstamos originales usan `LoanTransaction` y `LoanCalculator`. Admiten
interés por porcentaje o monto fijo y períodos diarios, semanales, quincenales
o mensuales. El porcentaje se calcula sobre el capital pendiente. Los pagos
cubren primero los intereses pendientes y después amortizan capital.
Cada préstamo conserva su política de acumulación de intereses vencidos.
Estas reglas deben revisarse en el motor y sus pruebas antes de modificarlas.

Un ejemplo del recorrido de una operación es:

`AddLoanScreen → DebtProvider.addLoan → LocalDatabaseService.insertLoan → Hive`

Después de guardar y actualizar su estado, el proveedor notifica a las pantallas
para que muestren los saldos e indicadores correspondientes.

## Módulo adicional de solicitudes de crédito

Existe un segundo flujo en `CreditPortalScreen`, `CreditService` y `CreditEngine`.
Tiene roles de solicitante, analista, cumplimiento y gerencia, y estados de
borrador, análisis, cumplimiento, gerencia, aprobación, rechazo y devolución.
El servicio implementa permisos por rol, evaluación de capacidad de pago,
DTI, puntaje explicativo, decisiones, planes de cuotas, pagos y anulaciones.
La evaluación es una simulación académica, sin consultas a una central de riesgo.

`CreditEngine` calcula amortización francesa y alemana con resultados monetarios
en centavos. Usa tasa nominal anual dividida entre doce y cuotas mensuales.
También maneja seguro, comisión inicial y mora fija por cuota vencida.

La integración local aprobada mantiene los registros y motores separados:
`loans` / `payments` para préstamos directos, `applications` / `credit_payments`
para solicitudes y `credit_accounts` para su formalización y activación.
`PortfolioLedger` adapta la lectura común de caja. `DebtProvider` incluye
únicamente créditos activados en sus totales, cierre diario y gráficos. Los
reportes CSV/PDF y el respaldo v3 incluyen ambos tipos de préstamo. El saldo
contractual amortizado incluye cuotas futuras y cargos; no equivale al capital
pendiente ni a ganancia cobrada.

Aprobar deja la solicitud pendiente de formalización: no permite cobrar ni
descuenta capital. Gerencia debe vincular un cliente existente y registrar la
referencia del acuerdo. Después registra la fecha real de entrega y su
referencia, con confirmación y validación de capital. Esa operación activa un
solo `credit_account`, genera el plan desde la fecha efectiva y descuenta caja
una sola vez. No crea una copia en `loans` ni un retiro adicional en capital.

Los expedientes aprobados antes del cambio conservan sus planes y pagos exactos.
Quedan pendientes de conciliación. Gerencia verifica cliente, fecha, evidencia
y si los movimientos anteriores ya están incluidos en caja. Un saldo de apertura
fijo impide volver a sumar esos cobros; una anulación posterior revierte su efecto.
Se debe verificar que el mismo crédito no esté ya registrado como préstamo directo.
No existe identificación automática fiable de duplicados históricos entre módulos.

`CreditWorkspace` muestra interfaces por rol. Gerencia accede a las solicitudes,
decisiones, formalización y desembolso desde su navegación principal. Solicitantes
ven Inicio, Mis solicitudes y Perfil, con un formulario en tres pasos. Analista
y Cumplimiento tienen una bandeja de su etapa y mantienen los permisos existentes.
`RoleShell`, `CreditConditions` y `CreditAccountTile` son componentes reutilizables.
La base publica cambios locales para refrescar los saldos; ese evento no es sincronización remota.

Los respaldos completos v3 conservan solicitudes, créditos, planes y cobros.
Se aceptan respaldos completos v2 y la importación original v1. Restaurar valida
referencias, condiciones, planes y conciliación antes de escribir. Las cuentas
propietarias deben existir en la instalación; el archivo no migra credenciales.
La restauración completa reemplaza el negocio solo mediante una acción explícita
y confirmada. Reiniciar únicamente la cartera se bloquea si existen créditos
vinculados, para no romper sus referencias.

Hay una primera conexión visual: desde Nuevo préstamo se abre
`InstallmentSimulatorScreen`, que reutiliza `CreditEngine` para comparar cuotas
francesas y alemanas. Es una simulación: no crea un préstamo ni cambia la cartera,
y no convierte el formulario original al modelo de amortización del portal.

## Acceso y seguridad

Los usuarios, contraseñas y sesiones son locales. Las contraseñas se guardan
como hashes PBKDF2-HMAC-SHA256 con sal. Hay limitación de intentos fallidos y
sesiones de ocho horas. Existe TOTP opcional para el segundo factor.

El PIN y la biometría son una protección adicional del dispositivo, gestionada
por `AppLockService`, `flutter_secure_storage` y `local_auth`. La disponibilidad
de biometría depende del equipo. Mostrar el acceso después de que venza una
sesión no significa que se haya borrado la cartera.

## Diseño actual y objetivo visual

Se conserva el logo original y la identidad morada. El tema común está en
`lib/utils/app_theme.dart`: acento `#B976FF`, morado de acciones `#7935C8`,
lavanda `#F4ECFF`, fondo casi blanco `#F8F9FB`, texto `#191620` y superficies blancas.
La tipografía Roboto está incluida como recurso local.

La dirección visual toma la composición de la referencia fitness guardada en
`.review/pinterest-ui-reference.jpg`: tarjeta principal, resúmenes compactos,
radios amplios y sombras discretas. `finance_ui.dart` comparte esos módulos entre
Inicio, solicitudes y la cartera original. `credit_overview.dart` organiza el
expediente en identidad, condiciones y capacidad de pago; el DTI y los resultados
siguen procediendo del motor existente. No se añaden tasas ni reglas visuales.
El contador «Activadas» corresponde a solicitudes con crédito activado, no a
todos los préstamos directos de la cartera.

La interfaz prioriza blanco, espacio y legibilidad. El morado se usa
en acciones, selección y foco. `RoleShell` conserva la navegación nativa y añade
una cápsula translúcida con indicador morado que se desplaza entre destinos en
280 ms. En escritorio se centra con un ancho máximo de 460 px.
`GlassSurface` limita el desenfoque a superficies de navegación y búsqueda;
en alto contraste usa blanco opaco. `AppSearchField` comparte búsqueda, limpieza
y respuesta al enfoque. Tarjetas, formularios y tablas mantienen superficies
claras sin desenfoque. La barra móvil flota sobre el contenido; las listas dejan
espacio al final para acceder a todos los elementos. Los cambios de foco y
navegación respetan la preferencia de movimiento reducido.

`lib/widgets/app_ui.dart` contiene encabezados, límites de ancho, diseño
adaptable, respuestas al pulsar, entrada de contenido, navegación entre pestañas
y una bienvenida breve. Las pantallas usan transiciones de Flutter, incluido
Hero para la continuidad del avatar del cliente, y respetan movimiento reducido.
Las opciones avanzadas se agrupan en secciones desplegables.

El video de referencia es un MOV de 19 segundos situado en la raíz del proyecto.
Se revisó una secuencia de fotogramas y se adaptaron principios de aparición
progresiva y continuidad. El video orienta la calidad visual y el movimiento;
la identidad y las funciones deben seguir siendo las de Contador Engine.

## Instrucciones para seguir trabajando

1. Trabaja sobre la aplicación original y sus componentes existentes.
2. Conserva datos, validaciones, servicios, cálculos y funciones importantes.
3. Distingue una función implementada en el motor de una función accesible desde
   la interfaz: pueden faltar botones o integración entre datos.
4. Antes de unificar los módulos, define cómo se relacionarán sus modelos,
   pagos, capital, reportes y respaldos. Añadir un botón no completa esa unión.
5. Mantén una interfaz blanca y sencilla, con acentos morados, animaciones breves y
   configuraciones técnicas accesibles mediante divulgación progresiva.
6. Explica los cambios y permite revisar el resultado visual por etapas.
7. Valida con las pruebas pertinentes, `flutter analyze` y compilación de
   Windows. Comprueba las funciones nativas en la plataforma correspondiente.

Para ejecutar en Windows: `flutter run -d windows`.
Para compilar: `flutter build windows`.
El ejecutable generado es
`build/windows/x64/runner/Release/mi_app_flutter.exe`.
