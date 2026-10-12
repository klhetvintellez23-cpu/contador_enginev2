# Crédito personal mensual: adaptación técnica a Panamá

Implementación revisada el 11 de octubre de 2026. Alcance: crédito en USD,
amortización sobre saldo (francesa o alemana), cuotas mensuales y pago voluntario.
La aplicación registra operaciones realizadas fuera de ella: no entrega fondos,
verifica licencias, firma documentos por las partes ni certifica cumplimiento legal.

## Uso

1. En **Cartera → Nuevo préstamo**, selecciona al cliente y define monto, tasa,
   plazo, capacidad de pago y cargos. También se conserva el proceso por roles
   para solicitudes creadas por el solicitante.
2. Si el monto supera USD 5,000, determina el FECI. Aplicarlo añade el 1% anual
   sobre saldo. Una exención o una operación no sujeta requiere fundamento y
   referencia de evidencia. Pendiente de revisión impide formalizar.
3. Revisa tasa efectiva, costo efectivo con terceros, total y cuotas. La
   aprobación directa por gerencia exige la política de capacidad de pago y
   queda diferenciada del proceso de aprobación por roles.
4. En **Formalizar crédito**, selecciona **Cliente verificado**. Si no aparece,
   pulsa **Registrar cliente**, confirma su nombre, cédula o pasaporte y guarda;
   su ficha se añade a Cartera y queda seleccionada sin salir del formulario.
   Una cuenta de solicitante no crea por sí sola esta ficha. Los préstamos
   nuevos originados desde Cartera conservan el cliente elegido por gerencia.
   Después completa prestamista, régimen, identificación,
   domicilios, representante y lugar. Descarga el **borrador contractual** para
   revisión. Después registra las referencias del documento firmado por ambas
   partes y de la entrega de copia, y verifica identidad y aceptación.
5. Registra la entrega real de fondos con fecha y referencia. El calendario se
   genera desde esa fecha, de acuerdo con la regla mensual divulgada en el
   contrato. Los cargos propios se pagan en la primera cuota: el desembolso neto
   de este producto es el capital aprobado completo.
6. **Registrar pago** conserva el desglose de cuotas. Para terminar el préstamo,
   utiliza **Cancelar préstamo**, revisa la liquidación de hoy y registra la
   referencia del cobro o devolución realizada.
7. El PDF/JSON del expediente incluye condiciones, evidencia contractual,
   calendario, pagos, saldos y, cuando existe, la cancelación. Las anulaciones
   requieren motivo y permanecen en la bitácora.

## Reglas implementadas

- **Tasa efectiva anual:** TIR de los flujos mensuales realmente redondeados en
  centavos, anualizada mediante `(1 + TIR mensual)^12 - 1`. Incluye interés y
  comisión retenida por el prestamista. Por eso puede diferir ligeramente de
  anualizar la tasa nominal sin redondear las cuotas.
- **Costo efectivo con terceros:** segundo indicador que incorpora además las
  primas destinadas íntegramente a aseguradora y el FECI. La separación evita
  presentarlos como ganancia del prestamista. El seguro de este producto no
  admite comisión oculta o retención parcial a favor del prestamista.
- **FECI:** umbral estricto sobre principal mayor que USD 5,000; cargo mensual
  de `saldo × 0.01 / 12`, separado de intereses y sin capitalización. La
  clasificación se conserva con las condiciones; no se agregan tributos nuevos
  automáticamente a contratos históricos.
- **Mora nueva:** porcentaje explícito, aplicado una sola vez al capital impago
  al vencer cada cuota. No se cobra sobre intereses ni se capitaliza. Los límites
  de entrada del programa no representan límites legales. Los contratos antiguos
  conservan su modalidad anterior de cargo fijo.
- **Cancelación total:** capital original más cargos devengados menos pagos
  recibidos. Se eliminan intereses y FECI futuros; dentro del período mensual se
  prorratea por días calendario reales. Las amortizaciones adelantadas reducen
  la base usada en ese cálculo. No se añade interés ordinario de atraso por
  encima del plan; la mora se mantiene separada. Penalización cero.
- **Seguro:** se eliminan primas de períodos no iniciados. Una devolución
  adicional de prima del período iniciado depende de la póliza y se tramita
  por separado; el programa no presume condiciones de una aseguradora.
- **Adelanto de cuotas:** conserva la imputación pactada. No es un abono especial
  a capital con reprogramación del plazo. Si un pago alcanza la liquidación total,
  el servicio exige usar la cancelación para descontar cargos futuros.
- **Devoluciones:** si lo recibido supera la obligación devengada, la cancelación
  genera salida de caja y requiere disponible suficiente. También admite cierre
  sin movimiento cuando el neto es cero.
- **Consistencia:** la cotización vence al terminar el día y deja de ser válida
  si cambian los pagos. El registro de caja, el cierre y su evidencia se escriben
  en la misma transacción. Para corregir pagos anteriores se debe anular primero
  la cancelación. Se valida la liquidación al restaurar respaldos.

## Compatibilidad y límites

Las condiciones nuevas usan versión 2; mapas sin versión se interpretan con las
reglas anteriores. No se reescriben planes ni pagos históricos. El cierre conserva
el calendario original y guarda separadamente el detalle de liquidación. Los
respaldos completos v2/v3 siguen admitiéndose.

La pantalla de originación ya no crea préstamos periódicos indefinidos con el
primer interés completo generado al inicio. Esos préstamos históricos siguen
siendo consultables y cobrables con su motor original; requieren revisión
individual antes de cambiar condiciones o liquidarlos bajo otra regla. Los
créditos amortizados anteriores sí pueden usar la liquidación total tras estar
activos o conciliados. No se reinterpretan unilateralmente contratos anteriores.

La configuración del tipo de prestamista es obligatoria al formalizar. Aún debe
verificarse la situación jurídica y autorización real del operador. Un registro
de evidencia no autentica por sí solo una firma, una licencia ni una exención.
La huella del documento detecta cambios accidentales; no es una firma digital ni
protección frente al propietario de los archivos locales.

Quedan fuera del producto implementado: descuento de salario y su calendario,
hipotecas y garantías reales, refinanciamientos con pagos a terceros, cargos
retenidos al desembolsar, métodos agregado/descontado, tasas variables y abonos
extraordinarios a capital con reprogramación. No debe usarse esta plantilla para
esos productos sin su adaptación específica.

DTI y scoring siguen siendo políticas internas, no una consulta APC ni un umbral
legal universal. Continúan los límites de seguridad local descritos en README:
cuentas de demostración, base sin cifrado integral y ausencia de servidor central.
Los procesos de protección de datos, prevención de blanqueo, licencias y revisión
jurídica de la plantilla dependen del régimen y de la operación real del negocio.

## Fuentes revisadas

- [Ley 33 de 2002, MICI](https://mici.gob.pa/wp-content/uploads/2021/09/01-04-ley-no-33-4-julio-2002.pdf):
  modifica las reglas de información, documentación, tasa efectiva y tratamiento
  de intereses para financieras. Se consultó la modificación, no la fórmula
  reemplazada del artículo 30 original.
- [Ley 42 de 2001, MICI](https://mici.gob.pa/wp-content/uploads/2021/09/01-01-l-42-23-julio-2001.pdf):
  artículo 31, cancelación anticipada. Este producto usa saldo; no implementa
  tablas de devolución de préstamos agregados o descontados.
- [Decreto Ejecutivo 39 de 2022, publicado por la SBP](https://www.superbancos.gob.pa/documentos/feci/leyes-y-decretos/Ley_39_2022.pdf):
  referencia al régimen FECI y a exclusiones. El archivo tiene nombre
  `Ley_39_2022.pdf`, pero el documento es un decreto ejecutivo.
- [Preguntas frecuentes de Ley Bancaria, SBP](https://www.superbancos.gob.pa/leyes-y-reg/otras-regulaciones/ley-bancaria/faq-ley-bancaria):
  información de tasas y costos bancarios. La selección «banco» en el formulario
  no acredita cumplimiento de todas las obligaciones bancarias.

## Verificación

`flutter analyze` y `flutter test --no-pub`. Las pruebas específicas están en
`test/panama_credit_test.dart`: TIR, FECI, umbral/exenciones, cancelación por fecha,
amortización previa, devolución, mora, compatibilidad, permisos, evidencia,
concurrencia, restauración y anulación. Los recorridos de interfaz verifican
originación, formalización y desembolso, incluyendo pantallas estrechas.
