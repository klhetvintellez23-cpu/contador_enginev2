# Rediseño de la aplicación original

## Ajuste visual vigente: composición de app de consumo

Se revisó la referencia fitness `.review/pinterest-ui-reference.jpg`. Se adoptan
su tarjeta principal, resúmenes pequeños, radios amplios y navegación en cápsula.
La base es casi blanca (`#F8F9FB`), con tarjetas blancas, sombras discretas y texto
oscuro. El morado destaca acciones, selección y foco. Los formularios y las
tarjetas no usan glassmorphism. La copia anterior a este ajuste está en
`.review/consumer-before/`.

`RoleShell` conserva los controles nativos de Flutter para navegación, teclado
y accesibilidad. La barra flota sobre el contenido tanto en móvil como en
escritorio, donde se centra con un máximo de 460 px. La cápsula usa
`GlassSurface`, con transparencia blanca, desenfoque recortado y sombra discreta.
El indicador morado abraza icono y etiqueta y se desplaza en 280 ms con `easeOutCubic`.
El movimiento reducido omite esa transición y el alto contraste elimina la
transparencia y el desenfoque.

`AppSearchField` unifica las búsquedas de clientes, comprobantes, solicitudes y
selección de cliente. El foco activa un borde y una sombra morada suave en 180 ms.
La limpieza de búsqueda actualiza el filtro y conserva el foco. Los botones
principales responden al hover y la pulsación; los secundarios son blancos con
borde neutro y texto oscuro. Las listas dejan espacio final para la barra flotante.

Inicio combina la acción principal con tres resúmenes de solicitudes y accesos
compactos a la cartera y cobros. Las solicitudes pasan a tarjetas con identidad,
monto destacado, plazo y estado; las listas usan dos columnas cuando hay espacio.
El expediente agrupa identidad, monto, plazo, tasa, condiciones, ingresos y
evaluación en módulos adaptables. Se mantienen visibles costos y resultados de
las reglas existentes. La cartera incorpora un resumen de disponible, saldo
por cobrar y clientes; mantiene la creación de préstamos, búsqueda y herramientas.

Gerencia mantiene Inicio, Solicitudes, Cartera y Perfil; solicitantes mantienen
Inicio, Mis solicitudes y Perfil. La cartera original sigue disponible dentro
de Cartera. Este ajuste no modifica motores, servicios, almacenamiento ni
`DebtProvider`; se comprobó su identidad con la copia previa. El alcance funcional
actual se documenta en `contexto-para-chatgpt.md` e `integracion-local-creditos.md`.

## Auditoría de la primera iteración

La interfaz es Flutter con Provider y persistencia Hive. La cartera original
está en `HomeScreen`; el motor de crédito y su proceso por roles están separados.
Este trabajo modifica la presentación, no migra ni reemplaza los datos del negocio.
Se guardó una copia del código previo en `.review/ui-before/lib`.

Problemas encontrados:

- Inicio: cabecera grande con degradado, accesos duplicados, menú flotante con
  acciones ocultas y demasiados indicadores antes de llegar a los clientes.
- Nuevo préstamo: secciones y tarjetas para casi cada opción, interés avanzado
  siempre visible, calculadoras compitiendo con el formulario y botón sin estado
  visible durante el guardado.
- Cliente: cabecera y sombras dominantes, desglose financiero antes del saldo,
  acceso al préstamo nuevo que obligaba a volver al inicio.
- Ajustes: negocio, capital, notificaciones, seguridad y respaldo en una lista
  muy larga de controles abiertos.
- Pantallas auxiliares: cabeceras repetidas, tarjetas con alturas rígidas,
  ancho de lectura sin límite en Windows y desbordamientos con texto ampliado.
- Movimiento: desenfoque costoso en diálogos, animaciones sin preferencia de
  movimiento reducido y navegación distinta entre secciones.

La primera iteración siguió los criterios escritos porque todavía no estaba
el video. Después se revisó el archivo MOV de referencia (19 segundos, 360 × 640)
mediante una secuencia de fotogramas cada 500 ms, guardada en `.review/video/`.
La referencia muestra una bienvenida que se compone por etapas, una transición
al acceso y una entrada progresiva al inicio. Se adoptan esos principios de
movimiento y jerarquía, conservando la marca y los flujos de esta aplicación.
No se trasladan sus ilustraciones, vehículos, mapas ni colores amarillos.

## Jerarquía y sistema visual

- Inicio: disponible, acción Nuevo préstamo, cobros del día y clientes buscables
  por nombre o cédula. Avisos de cartera con divulgación progresiva.
- Cobros: comprobantes por cliente; se conservan filtros y reenvío.
- Informes: ganancia cobrada, métricas y gráficos originales.
- Ajustes: grupos de negocio, capital, cobros, seguridad, respaldo,
  actualizaciones y cuenta. Las acciones destructivas conservan sus confirmaciones.
- Exportar reporte y cierre diario permanecen en Más herramientas del inicio.
- Nuevo préstamo: campos esenciales y opciones avanzadas desplegables. Ambos
  calculadores permanecen accesibles. Desde el menú del cliente se puede abrir
  un préstamo con ese cliente seleccionado.

La marca conserva su logo real. El lavanda luminoso `#B976FF` se reserva para
acentos y `#7935C8` para texto y acciones con contraste sobre superficies claras.
El fondo inicial `#FAF9FC` se sustituyó por `#F8F9FB`, con texto `#191620`,
superficies blancas y bordes neutros suaves.
Se reutilizan la tipografía local, los iconos Material y los servicios existentes.

## Movimiento y adaptación

`app_ui.dart` proporciona encabezados, límites de lectura, cuadrícula adaptable,
transiciones, superficies con respuesta al pulsar y grupos desplegables.
La navegación usa una cápsula inferior flotante tanto en móvil como en escritorio.
Las pestañas ya visitadas conservan su estado; las ocultas suspenden sus tickers.
Las listas de clientes siguen construyéndose de forma diferida.

La entrada del logo dura 800 ms sin bloquear la interacción: aparece con un
desplazamiento y escala mínimos, y se desvanece mientras entra el contenido.
El formulario de acceso y el resumen del inicio entran con desfases de 90 y
70 ms respectivamente. Esta presentación es más breve que la del video.
Las respuestas al
pulsar duran 160 ms, pestañas y paneles 220 ms, y las rutas usan fade y slide suaves.
El avatar del cliente mantiene continuidad visual con Hero. Los diálogos usan
fade y escala mínima sin desenfoque. Se respeta `disableAnimations` en los
componentes de movimiento, incluyendo Hero y la carga personalizada.

## Validación

`ui_redesign_test.dart` comprueba navegación, búsqueda por cédula, conservación de
la búsqueda al cambiar de pestaña, apertura de respaldos, creación de préstamos,
cobros y movimiento reducido. Recorre las pantallas en 390 y 1280 px, y comprueba
formularios y detalle de cliente a 360 px con texto ampliado al 140%.
También recorre las cuatro secciones a 320, 980 y 1280 px con texto ampliado,
con la cápsula flotante, y verifica la limpieza de la búsqueda.

Las capturas `.review/ui-*.png` son renderizados de los widgets Flutter con datos
temporales de prueba; no contienen ni modifican la cartera real.

La comprobación de FPS sostenidos en teléfonos de gama media requiere un equipo
físico. Las pruebas de widgets y el análisis estático no sustituyen esa medición.

Resultado del ajuste: 59 pruebas completas aprobadas y análisis de Flutter sin
errores ni advertencias. Las tres pruebas de interfaz se volvieron a ejecutar
tras ajustar la composición y la captura fiel de sombras. Se compararon los
archivos de modelos, proveedores y servicios con la copia previa: su contenido
es idéntico. Las pruebas de cobro verifican el pago guardado; los selectores
nativos de compartir y la biometría requieren comprobación en el dispositivo.
