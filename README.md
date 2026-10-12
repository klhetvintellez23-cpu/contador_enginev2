# ContadorEngine · Gestión crediticia local

Aplicación Flutter para administrar clientes, préstamos, cobros, capital y reportes.
Administración utiliza Inicio, Solicitudes, Cartera y Perfil. Cartera conserva
las funciones originales de clientes, préstamos directos, cobros e informes.
Los ajustes del negocio se encuentran en Perfil. El solicitante utiliza Inicio,
Mis solicitudes y Perfil, con un formulario por pasos.

Desde **Nuevo préstamo → Simular cuotas** se pueden comparar los métodos Francés
y Alemán con monto, tasa nominal anual y plazo mensual. El simulador muestra
tasa efectiva y desglose de cuotas con el supuesto FECI seleccionado, sin registrar préstamos.

La originación nueva utiliza condiciones versión 2 con tasa efectiva, FECI
documentado, evidencia contractual y cancelación total sin intereses futuros.
Consulta [alcance, reglas y operación para Panamá](docs/credito-panama.md).
Esta adaptación técnica requiere verificar el régimen y autorización del negocio;
no es una certificación legal ni sustituye la firma y revisión del contrato.

El código del proceso académico por roles y sus datos se conservan. Las cuentas
de solicitante, analista y cumplimiento mantienen su acceso específico.

## Ejecutar

**Si es la primera vez que ejecutas el proyecto en tu laptop, sigue la
[guía paso a paso para Windows y Linux](docs/ejecutar-en-laptop.md).** Incluye
instalación de Flutter, herramientas del sistema, descarga del código, primer
inicio de sesión, compilación y solución de errores frecuentes.

| Sistema | Guía | Estado |
| --- | --- | --- |
| Windows | [Instalar y ejecutar](docs/ejecutar-en-laptop.md#windows) | Compilación y ejecución verificadas localmente. |
| Linux (Ubuntu/Debian) | [Instalar y ejecutar](docs/ejecutar-en-laptop.md#linux-ubuntu-y-debian) | Configuración incluida; pendiente de validación en una laptop Linux. |

Versión de referencia: **Flutter 3.41.7 / Dart 3.11.5**. Las dependencias
resueltas en `pubspec.lock` requieren Flutter **3.41.0 o superior** y Dart
**3.11.0 o superior** dentro de la serie 3.x. Conserva ese archivo al instalar.

La navegación y las pantallas usan el nuevo diseño adaptable en morado y fondos
claros. Consulta la [auditoría, cambios de interfaz y validación](docs/rediseno-ui.md).
La [integración local y navegación por roles](docs/integracion-local-creditos.md)
describe el flujo aprobado, los respaldos y el alcance real de la sincronización.
La [intro actual](docs/intro-premium.md) dura 3,4 segundos y revela la pantalla
de acceso sobre un fondo morado con ondas suaves.

### Inicio rápido con las herramientas ya instaladas

Windows, desde PowerShell:

```powershell
git clone https://github.com/klhetvintellez23-cpu/contador_enginev2.git
cd contador_enginev2
flutter pub get
flutter run -d windows
```

Linux, desde una terminal del escritorio:

```bash
git clone https://github.com/klhetvintellez23-cpu/contador_enginev2.git
cd contador_enginev2
flutter pub get
flutter run -d linux
```

Si ya descargaste el proyecto, abre una terminal en la carpeta que contiene
`pubspec.yaml` y ejecuta solo los dos comandos de Flutter. Necesitas acceso al
repositorio para clonarlo; la guía también explica la descarga como ZIP.

La base Hive se crea automáticamente. No necesita Supabase, un archivo `.env`
ni un servidor de base de datos. Los datos se conservan localmente para cada
usuario del sistema; cerrar la aplicación no elimina la base. Cada laptop tiene
sus propios datos.

Para preparar un ejecutable y probar la intro en modo optimizado, consulta
[compilar en Windows](docs/ejecutar-en-laptop.md#5-generar-el-ejecutable-de-windows)
o [compilar en Linux](docs/ejecutar-en-laptop.md#5-generar-el-ejecutable-de-linux).

## Cuentas de demostración

Todas comienzan con la contraseña `ContadorLocal2026!`.

| Rol | Correo |
|---|---|
| Solicitante | cliente@contador.local |
| Analista | analista@contador.local |
| Cumplimiento | cumplimiento@contador.local |
| Gerencia | admin@contador.local |

Si cambiaste la contraseña del administrador previamente, la migración conserva su hash.
Después de introducir correo y contraseña, escribe los cuatro caracteres que
aparecen en **Código de prueba actual** y pulsa **Verificar código**. En este
prototipo la verificación se muestra dentro de la app; no se envía por correo ni SMS.
Desde el acceso se pueden registrar nuevas cuentas de solicitante; no pueden elegir
un rol privilegiado. En Seguridad puedes cambiar tu contraseña y activar TOTP con
una aplicación autenticadora. Guarda el secreto TOTP de recuperación fuera de la app.

## Demostración de principio a fin

1. Entra como solicitante y crea un borrador. Ejemplo: monto 1000, tasa nominal anual
   12%, plazo 12 meses, ingresos 2000, gastos 600, otras cuotas 100; cargos 0.
2. Envía la solicitud a análisis.
3. Cierra sesión y entra como analista. Abre el expediente, calcula DTI/scoring y
   aprueba la etapa con un motivo.
4. Entra como cumplimiento y registra la revisión con su motivo.
5. Entra como gerencia y confirma la aprobación. La solicitud queda pendiente
   de formalización; todavía no mueve caja ni permite cobrar.
6. Registra al cliente en Cartera si no existe. Desde el expediente, formaliza
   el crédito con los datos del prestamista y deudor, el régimen aplicable y
   constancias del contrato firmado y de la entrega de copia.
7. Registra la entrega real, fecha y referencia. Se verifica el capital disponible,
   se activa un solo crédito y se genera el plan desde esa fecha.
8. Registra un pago con referencia única, revisa el saldo y exporta PDF/JSON.
9. Consulta la bitácora. Si un pago es incorrecto, anúlalo con motivo; permanece visible.

Los roles no pueden saltar etapas. Una devolución permite al solicitante corregir
el borrador e invalida la evaluación anterior. El saldo cero se muestra como préstamo saldado.

## Reglas explícitas de simulación

- Moneda USD; planes calculados en centavos, con ajuste final de redondeo.
- Tasa nominal anual dividida entre 12. Cuotas mensuales con ajuste al último día
  del mes, conservando como referencia el día original.
- Francés: cuota base constante salvo redondeo final. Alemán: capital constante
  salvo ajuste final, interés sobre saldo.
- Seguro fijo por mes destinado a terceros y comisión propia en primera cuota.
  En condiciones v2, mora porcentual única sobre capital impago al vencimiento;
  los contratos v1 conservan su cargo fijo. Los cargos parten de cero.
- FECI desglosado cuando corresponda; exención/no sujeción requieren evidencia.
  La tasa efectiva usa TIR e incluye comisión propia; otro indicador agrega
  seguro y FECI al costo efectivo anual.
- Los pagos cubren cuotas en orden: mora, comisión, seguro, FECI, interés y capital.
  Se rechazan sobrepagos y referencias activas duplicadas. La cancelación total
  tiene un flujo separado que descuenta intereses/FECI futuros y primas de
  períodos no iniciados, con posible devolución. La póliza determina cualquier
  devolución adicional de seguro. Los adelantos ordinarios no reprograman cuotas.
- DTI = (otras cuotas mensuales + cuota máxima propuesta) / ingreso mensual.
  Recomendación favorable si DTI ≤ 40% y disponible tras gastos/deudas/cuota ≥ 0.
  Gerencia puede configurar el umbral; cada evaluación conserva su versión.
- Puntaje explicativo: 70 × (1 − DTI) + 30 × proporción de ingreso disponible,
  con cada componente limitado al intervalo 0–1. No es una consulta APC ni un
  modelo bancario validado. Revisar estas reglas con la profesora.

## Datos, recuperación y respaldo

Las escrituras del negocio y su bitácora se guardan juntas en una entrada Hive y
se serializan para evitar cambios parciales. La migración conserva la cartera anterior.
La cartera permite originar créditos mensuales directamente con aprobación de
gerencia, capacidad de pago, contrato y desembolso separados. Ambos motores se conservan,
con una lectura común de caja, cierre diario, gráficos y reportes. Los créditos
aprobados anteriormente conservan su plan y pagos y requieren conciliación explícita
antes de entrar en los totales comunes. No se crea una copia en la tabla de préstamos directos.

**Perfil → Administración avanzada → Respaldar negocio completo**, o Exportar
respaldo desde los ajustes del negocio, genera un JSON completo v3. Restaurar
valida el documento, reemplaza el negocio y conserva evidencia de la operación.
No exporta contraseñas, sesiones ni secretos 2FA. Requiere que las cuentas propietarias
existan con los mismos identificadores: sirve para recuperar la misma instalación
(o una instalación con las cuentas de demostración correspondientes). No es una
migración automática de usuarios personalizados entre equipos. El respaldo histórico
v1 se importa desde los ajustes del negocio; también se aceptan respaldos completos v2.

Las solicitudes se comparten entre roles en una misma instalación. Dos dispositivos
mantienen bases independientes. La sincronización remota requiere un servidor,
autenticación central y permisos; todavía no está implementada.

En web los documentos se descargan; en plataformas nativas se guardan y pueden
compartirse. Cerrar sesión conserva preferencias y comprobantes. Olvidar el PIN
permite recuperar acceso con contraseña y 2FA, si está activo, sin reinstalar.

La sesión local dura ocho horas. Las contraseñas usan PBKDF2-HMAC-SHA256 con sal
individual; cinco intentos fallidos bloquean la cuenta cinco minutos. Los datos del
negocio no están cifrados en reposo. La bitácora es de solo lectura desde la interfaz,
con actor, rol, fecha, cambios y hashes encadenados; no es inviolable frente a alguien
que controla los archivos o el navegador del dispositivo.

Las fuentes están incluidas bajo su licencia en `assets/fonts/`. El recordatorio
es una función Android/iOS que se actualiza desde su botón; Windows muestra los
vencimientos dentro de la aplicación, sin notificaciones del sistema.
No se realizan desembolsos, cobros bancarios, transferencias ni consultas externas.

## Verificación

```sh
flutter analyze
flutter test
```

Compila desde el sistema correspondiente: `flutter build windows --release` en
Windows o `flutter build linux --release` en Linux.

Las pruebas incluyen referencias de amortización, DTI, permisos negativos, ciclo de
aprobación, devolución, pagos y anulaciones, TOTP, persistencia, restauración,
rechazo de respaldos alterados, generación PDF y pantallas a tamaño móvil.
Consulta `docs/implementacion-academica.md` para conocer el alcance comprobado y sus límites.
