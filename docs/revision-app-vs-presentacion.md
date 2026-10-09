# Revisión crítica de ContadorEngine frente a la presentación

Fecha: 9 de octubre de 2026.

**Documento de diagnóstico inicial.** Se implementaron posteriormente correcciones y módulos; el estado actualizado está en [implementacion-academica.md](implementacion-academica.md).

Fuente: `Presentacion Asignacion #3.pdf`, 15 diapositivas. Se revisó el texto del documento y la imagen del cronograma. Se contrastaron modelos, motor de cálculo, proveedor de datos, almacenamiento, autenticación, pantallas, exportaciones, respaldos y pruebas. Esta revisión no modifica la aplicación.

El análisis de interfaz se basa en el código de pantallas: no es una prueba visual ni una validación en un teléfono. La verificación previa tuvo 18 pruebas aprobadas, análisis limpio y compilación web correcta. Esos resultados cubren el comportamiento probado; no acreditan los requisitos nuevos de la presentación. En esta revisión se ejecutaron además casos concretos del motor, conservados en `.review/probe.dart`.

## Dictamen

Hay una base reutilizable de gestión de clientes, préstamos y cobros. La presentación compromete un producto más amplio: administración del ciclo crediticio, desde solicitud y evaluación hasta aprobación, amortización y auditoría. Hoy faltan módulos centrales de ese ciclo. No corresponde declarar cumplimiento del acta ni asignar un porcentaje de avance sin una lista ponderada de criterios de aceptación.

La diapositiva 7 resume la aceptación en cálculo correcto, control por rol y trazabilidad. Deben ser la prioridad de la implementación. La app actual ofrece parte del seguimiento, pero no satisface todavía esos tres criterios en conjunto.

## Matriz de cumplimiento

| Compromiso presentado | Estado observado | Brecha concreta |
|---|---|---|
| Registro e inicio de sesión con control de acceso (6) | Parcial | Cuenta local fija; sin registro, usuarios independientes ni permisos por rol. |
| Solicitudes desde registro hasta decisión (3, 6, 12) | Ausente | Se crea directamente un préstamo; no hay expediente ni estados de solicitud. |
| Ingresos, egresos, endeudamiento y DTI (5) | Ausente | Customer solo contiene identificación y contacto. |
| Scoring por reglas (5, 7) | Parcial, distinto del solicitado | Hay confianza basada en préstamos y pagos, sin DTI ni evaluación financiera del solicitante. |
| DTI/scoring en ≤3 segundos (7) | No demostrado | El módulo comprometido no existe y no hay medición de aceptación. |
| Francés y Alemán (3, 5, 7) | Ausente | Motor de interés periódico sobre saldo, sin plazo contractual ni tabla de cuotas de esos sistemas. |
| Mora, seguro y comisiones (5) | Parcial | Alertas de atraso y acumulación de interés; sin cargos separados ni reglas contractuales completas. |
| Cliente → analista → cumplimiento → gerencia (5, 8) | Ausente | Sin roles, decisiones ni transiciones protegidas. |
| Pagos, saldos e historial (3, 6) | Parcial | Operaciones implementadas; existen problemas de validación, integridad y trazabilidad. |
| Dashboard y recordatorios (5, 6) | Implementación existente | Aprovechable; necesita indicadores del proceso de aprobación y vencimientos contractuales. |
| Bitácora no editable desde la interfaz (5, 7) | Ausente | Historial financiero calculado no equivale a bitácora de acciones y responsables. |
| Exportación PDF/JSON (6, 7) | Parcial | Reportes y respaldo implementados en rutas nativas; web devuelve null y bloquea importación. No exporta amortización bancaria. |
| Roles y 2FA (9, 11, 14) | Parcial en protección del dispositivo | PIN/biometría opcionales; no hay segundo factor de cuentas/roles. |
| Entorno simulado, sin operaciones bancarias reales (6) | Alineado | La base local sirve para simulación. No hacen falta bancos, APC, pagos reales ni IA avanzada. |

## Puntos fuertes que conservar

1. **Motor separado de las pantallas.** LoanCalculator permite reproducir el reparto entre interés y capital y consultar una fecha de corte. Es una buena ubicación para incorporar estrategias financieras y sus pruebas.
2. **Seguimiento ya desarrollado.** Clientes, préstamos, pagos, capital, cierre diario, búsquedas, alertas e historial forman una base útil para el módulo de cartera.
3. **Comprobantes y respaldo.** Hay generación de recibos, exportaciones, previsualización de importación y confirmaciones de acciones sensibles. Se debe completar su soporte y coherencia.
4. **Pruebas existentes.** Se prueban varios escenarios del interés actual, persistencia y autenticación local. Eso facilita detectar regresiones al incorporar el nuevo producto financiero.
5. **Protección adicional del dispositivo.** PIN, biometría y bloqueo al volver del segundo plano aportan valor, aunque no sustituyen permisos por rol ni 2FA de cuentas.
6. **Presentación con límites razonables.** Excluye integraciones bancarias, transferencias reales, APC automático e IA avanzada. Permite concentrarse en un ciclo administrativo demostrable.

## Hallazgos concretos y prioridades

P0: bloquea una demostración confiable o los criterios centrales. P1: corregir antes de la entrega. P2: mejora de mantenibilidad o experiencia. Un riesgo identificado por lectura no se presenta como fallo reproducido.

### P0 — La aplicación permite saltarse todo el proceso aprobado en el acta

`lib/screens/add_loan_screen.dart:480` crea el préstamo directamente; `lib/providers/debt_provider.dart:653` lo persiste sin solicitud aprobada. No existen estados ni permisos de analista/cumplimiento/gerencia. No basta añadir botones o cambiar títulos: la capa de servicio debe rechazar una transición no autorizada, incluso si se invoca fuera de la pantalla.

### P0 — Sobrepagos generan cifras incompatibles

Reproducción del motor: préstamo de 100 sin interés, pago de 150. Devuelve deuda 0 y totalPaid 100; el pago conserva 150. El proveedor suma los 150 en caja y calcula ganancia como total cobrado menos capital recuperado, por lo que puede mostrar 50 de ganancia en un préstamo sin interés.

Evidencia: `lib/models/loan_calculator.dart:223`, `lib/providers/debt_provider.dart:1348`, `lib/screens/customer_detail_screen.dart:826`. La pantalla comprueba que el pago sea positivo, pero no limita el exceso ni lo clasifica. Definir y probar rechazo del exceso o saldo a favor; nunca tratarlo implícitamente como interés ganado.

### P0 — Datos numéricos inválidos pueden entrar o romper el formulario

El monto del préstamo valida solamente que el campo no esté vacío y después usa double.parse. Texto no numérico produce excepción; un monto negativo no se rechaza con esa validación. Los servicios no imponen restricciones equivalentes. Los pagos comprueban positividad en pantalla, pero no valores finitos en todas las capas.

Reproducción directa del motor: pago de -10 sobre principal 100 produce deuda 110 e interés pagado -10. Ese caso no afirma que el formulario normal acepte -10: demuestra que motor/importación/servicios carecen de una defensa de dominio.

Evidencia: `lib/screens/add_loan_screen.dart:252`, `lib/screens/add_loan_screen.dart:495`, `lib/providers/debt_provider.dart:726`. Validar formato, signo, finitud, límites y referencias antes de mutar datos; mensajes claros para coma decimal y entradas inválidas.

### P0 — Falta trazabilidad y las eliminaciones destruyen historial

Editar o eliminar pagos altera los registros originales. Eliminar clientes puede borrar préstamos y pagos en cascada. No existe evento con actor, rol, acción, motivo, fecha y valores anteriores/posteriores.

Evidencia: `lib/providers/debt_provider.dart:775`, `lib/providers/debt_provider.dart:816`, `lib/services/local_database_service.dart:161`.

Para la entrega: bitácora de solo lectura en la interfaz y correcciones mediante anulación/reversión con motivo. Desactivar eliminación física de operaciones contabilizadas. No prometer inviolabilidad frente a alguien que controla los archivos locales; la presentación exige que la bitácora no sea editable desde la interfaz.

### P1 — Un pago futuro modifica un saldo histórico

LoanCalculator filtra fechas de devengo usando asOf, pero no filtra los pagos. Caso reproducido: principal 100, consulta al 10 de enero y pago de 40 fechado el 1 de febrero: devuelve deuda 60, aunque a la fecha de corte debería excluirse ese pago. También aplica pagos anteriores al inicio del préstamo.

Evidencia: `lib/models/loan_calculator.dart:172`. La edición de pagos permite seleccionar desde el año 2000, sin relacionar el mínimo con la fecha del préstamo (`customer_detail_screen.dart:954`). Corregir selección temporal y validación de dominio; probar corte histórico y fechas límite.

### P1 — Atraso y scoring dependen de una preferencia visual

overdueLoans devuelve una lista vacía cuando se desactivan las alertas. trustScoreForCustomer usa esa lista para penalizar atrasos. Apagar avisos cambia el resultado de riesgo sin cambiar pagos ni contratos.

Evidencia: `lib/providers/debt_provider.dart:139` y `:221`. Separar estado financiero de preferencias de presentación. Además, un pago pequeño reinicia lastActivityDate y puede quitar el atraso aunque no cubra lo vencido. El atraso debe derivarse de cuotas vencidas y sus importes pendientes.

### P1 — Mensual significa 30 días fijos

Reproducción: 31 de enero de 2026 + período mensual actual = 2 de marzo. La etiqueta “mensual” no expresa esa convención. Esto debe resolverse antes de generar planes Francés/Alemán: definir calendario contractual, fin de mes, primer vencimiento y regla de redondeo.

Evidencia: `lib/models/transaction.dart:22`. No se asume que toda convención de 30 días sea incorrecta: el problema es usarla sin definición contractual y confundirla con meses calendario.

### P1 — Se anuncia éxito antes de confirmar persistencia

Crear préstamo y registrar cobro muestran confirmación y cierran la pantalla antes de esperar la operación. Ante error de almacenamiento, el usuario puede recibir un mensaje de éxito incorrecto. No se observó un fallo de disco; el riesgo se identifica por el flujo asíncrono.

Evidencia: `lib/screens/add_loan_screen.dart:535`, `lib/screens/customer_detail_screen.dart:835`. Esperar la escritura, impedir doble envío, capturar errores y confirmar después del guardado.

### P1 — Pago y acumulado del préstamo se escriben por separado

registerPayment actualiza amount_paid e inserta el pago como dos escrituras. Edición y eliminación tienen el mismo patrón. Una interrupción entre pasos puede dejarlos distintos. La base tampoco verifica referencias entre cliente, préstamo y pago al insertar.

Evidencia: `lib/providers/debt_provider.dart:726`, `lib/services/local_database_service.dart:84`. Centralizar las operaciones relacionadas y su validación. Preferir calcular acumulados desde un registro de movimientos consistente o utilizar una unidad atómica de persistencia.

### P1 — Cerrar sesión borra preferencias e índice de comprobantes

main llama a clearData al salir; clearData llama a LocalCacheService.clearAll. Este limpia también las cajas de ajustes locales y receipt_history, no solo espejos. Los clientes, préstamos y pagos principales permanecen en la nueva base, pero ajustes como logo, avisos y el índice de comprobantes no tienen la misma conservación.

Evidencia: `lib/main.dart:67`, `lib/providers/debt_provider.dart:1328`, `lib/services/local_cache_service.dart:214`. Separar limpieza de memoria al cerrar sesión, caché regenerable, preferencias persistentes y borrado explícito del negocio.

### P1 — Respaldo y exportación no están disponibles en web

Las tres exportaciones devuelven null en web; importar JSON se bloquea explícitamente. Compilar web correctamente no valida esas funciones. Es especialmente relevante porque el comando propuesto para usar la base local abre Chrome.

Evidencia: `lib/utils/export_helper.dart:23`, `:172`, `:282`; `lib/utils/import_backup_flow.dart:19`. Implementar descarga/carga de bytes por plataforma y probar ida y vuelta del respaldo con comparación de totales.

### P1 — Mensaje de recuperación peligroso después del cambio local

En ajustes de PIN todavía se aconseja reinstalar y se afirma que los datos siguen seguros en la nube. Esa afirmación es falsa para la configuración actual y puede inducir pérdida de datos.

Evidencia: `lib/screens/home_screen.dart:2647`. Corregir el texto y definir recuperación del acceso que no dependa de desinstalar. Este pendiente corresponde a la migración local reciente.

### P1 — La cuenta local es una cuenta de demostración

LocalUser representa siempre el mismo administrador. La contraseña inicial está en el código; la sesión es un booleano persistido y la caja se abre sin cifrado explícito. Hay hash de contraseña, pero no registro, recuperación, cambio de contraseña, múltiples identidades ni autorizaciones por rol.

Evidencia: `lib/services/local_database_service.dart:7`. Mantener la base local es compatible con una simulación académica, pero requiere usuarios separados, permisos y un diseño de sesión coherente para demostrar el acta. El PIN/biometría opcional actual no acredita el 2FA indicado en el cronograma.

### P1 — Importación valida estructura superficial, no integridad completa

isValidBackupData comprueba que existan listas. No comprueba de forma integral referencias, duplicados dentro del mismo archivo, rangos de cantidades, fechas o versión admitida. importBackup escribe en varios pasos y no restaura initialCapital del respaldo como valor alternativo cuando no hay historial de capital. Es una brecha de compatibilidad para respaldos de ese tipo.

Evidencia: `lib/providers/debt_provider.dart:1211`, `:1266`; `lib/utils/export_helper.dart:288`. Validar el documento completo antes de escribir, presentar errores concretos y aplicar la importación de forma consistente.

### P2 — Métricas y simulador requieren definiciones coherentes

activeCapital acumula todo el principal prestado, incluidos préstamos recuperados; las alertas lo comparan con el capital inicial como si fuera exposición actual. La fórmula de caja usa esa suma histórica de manera razonable, pero el indicador y la alerta deben diferenciar desembolso acumulado de capital pendiente.

La calculadora rápida multiplica interés sobre principal inicial por cantidad de períodos. El motor principal calcula sobre saldo pendiente. Si hay abonos a capital, sus resultados pueden diferir: mostrar el supuesto explícitamente o utilizar el mismo motor.

Evidencia: `lib/providers/debt_provider.dart:291`, `:1348`; `lib/widgets/quick_loan_calculator_sheet.dart:86`.

### P2 — Estructura difícil de ampliar y cobertura incompleta

home_screen.dart tiene aproximadamente 4 037 líneas y debt_provider.dart 1 382. El proveedor reúne cálculos, persistencia, paginación, alertas, respaldo y reglas de negocio. Persiste código de cola/sincronización que ya no es necesario para el modo exclusivamente local. Antes de incorporar roles y solicitudes, dividir por módulos y separar casos de uso de widgets.

Las 18 pruebas existentes no cubren aprobación, permisos, DTI, amortización bancaria, auditoría ni exportaciones. Tampoco deben usarse como evidencia de que los problemas anteriores no existen.

## Diseño recomendado para respetar la presentación

Conservar Flutter, las pantallas reutilizables y el entorno local solicitado. Crear módulos de identidad/permisos, solicitudes, evaluación, aprobación, amortización, cartera y auditoría. Evitar reintroducir credenciales remotas para cumplir el acta.

Entidades mínimas: usuario/rol; cliente; perfil financiero; solicitud; evaluación con versión de reglas; decisión por etapa; préstamo aprobado; cuota programada; pago y aplicación del pago; cargos; evento de auditoría. Los expedientes y sus decisiones deben enlazarse por identificadores estables.

Flujo propuesto, a concretar como reglas verificables:

`Borrador → Enviada → Análisis → Cumplimiento → Gerencia → Aprobada/Rechazada → Préstamo y plan → Pagos → Cerrado`

Contemplar devolución para corrección y conservar cada decisión. Impedir que un usuario apruebe su propia solicitud o salte etapas. Si se modifican datos financieros tras evaluar, invalidar o versionar la evaluación y exigir nueva revisión.

Cada rol necesita una vista útil: el solicitante ve sus solicitudes y observaciones; analista ve evaluación; cumplimiento registra revisión; gerencia ve recomendaciones y decisión final. Una bandeja de pendientes por rol debe ocupar el centro del dashboard.

El motor debe seleccionar Francés o Alemán, generar un plan finito y reproducible y separar capital, interés, mora, seguro y comisiones. Definir tasa/periodicidad, vencimientos, redondeo, pago anticipado y excedentes antes de implementar. Las reglas y umbrales de scoring deben ser explícitos y versionados; no están completamente especificados en las diapositivas y no corresponde inventarlos como requisitos ya aprobados.

## Orden de implementación y demostración

1. **Estabilizar datos y cálculos.** Validaciones, sobrepagos, fechas, escrituras consistentes, salida de sesión, mensajes de recuperación y respaldos.
2. **Identidades, modelo y flujo.** Cuentas locales de los cuatro roles, solicitudes y transiciones con autorización real en servicios. Registrar eventos desde este punto.
3. **Evaluación financiera.** Datos de ingresos/egresos/deudas, DTI, reglas explicables, resultados reproducibles y medición del criterio de ≤3 segundos.
4. **Amortización contractual.** Francés/Alemán, plan de cuotas, cargos desglosados y pruebas de referencia; préstamo solo tras aprobación.
5. **Integrar cartera, auditoría y entregables.** Aplicación de pagos a cuotas, mora, exportaciones PDF/JSON y bitácora consultable sin edición.
6. **Demostración y aceptación.** Casos completos, permisos negativos, rechazo/devolución, respaldo/restauración, evidencia en teléfono y documentación de reglas.

La diapositiva 10 sitúa el cierre el 11 de diciembre de 2026. Al 9 de octubre, la fase de seguridad/aprobación aparece en curso en el plan. El código no evidencia todavía ese entregable. Esto indica riesgo respecto al cronograma, no permite afirmar por sí solo que el equipo esté atrasado: no se revisaron trabajo externo ni las 24 actividades detalladas. Debe actualizarse el seguimiento con evidencia del repositorio.

Prueba de aceptación principal: solicitante registra datos → analista obtiene DTI y scoring explicados → cumplimiento revisa → gerente decide → se genera el plan elegido → se registra un pago → cuadran cuota, saldo y reporte → la bitácora identifica cada acción. Probar también que otro rol no pueda ejecutar cada paso y que no pueda omitirse una etapa.

La migración a Hive responde a la solicitud de trabajar localmente. La presentación nombra Supabase como tecnología/responsabilidad; conviene registrar el cambio técnico y mantener intactos los compromisos funcionales. Si la profesora exige específicamente Supabase, habría que acordar esa decisión técnica o preparar una instancia local. El PDF, por sí solo, no permite asumir que usar Hive invalide el proyecto.

## Conclusión de la revisión

Conviene evolucionar la base existente hacia el proceso presentado y priorizar permisos, cálculos y trazabilidad antes de añadir efectos visuales o funciones secundarias. La declaración anterior de que la versión local estaba lista debe acotarse: pasó las pruebas y compilación realizadas, pero esta revisión descubrió brechas funcionales y pendientes de migración que requieren corrección antes de considerarla completa para la entrega.
