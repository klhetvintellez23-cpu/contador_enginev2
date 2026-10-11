# Refinamiento de contraste y distribución

Se actualizó la interfaz existente sin modificar modelos, servicios, cálculos ni almacenamiento.

- Tema: fondo `#F7F7F7`, tarjetas blancas, contenedores informativos `#F1F1F1`, bordes `#EAEAEA`, texto `#191919`/`#717171` y sombras negras muy suaves. Se conservan los morados originales para iconos y botones.
- `IconMedallion` utiliza siempre fondo gris neutro e icono morado. Avatares, iconos de comprobantes, estados vacíos y superficies secundarias reutilizan los neutros. Los fondos morados de selección y las señales de estado mantienen su función.
- Inicio de gerencia agrupa saldo, Abrir cartera, Cobros de hoy y revisión pendiente en una sola tarjeta adaptable. Se retiraron las tarjetas de acceso repetidas y se compactaron las solicitudes recientes.
- Solicitudes contiene los tres indicadores (total, en revisión y activadas) con los mismos criterios de cálculo. Se mantienen independientes del filtro de la lista; aparecen en una fila cuando caben y se redistribuyen con texto ampliado o poco espacio.
- La navegación animada se conserva. `RoleShell` reserva su altura para que los elementos del contenido puedan desplazarse completamente por encima de la barra.

## Verificación

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --reporter expanded`: 66 pruebas correctas; registro en `.review/final-navigation-neutral-tests.log`.
- La prueba `workspace_refinement_test.dart` comprueba indicadores 2/1/0, filtros, persistencia de valores, ausencia de indicadores en Inicio, colores neutros y tarjetas visibles sobre el menú. Comprueba ambos roles a 320, 390 y 1280 px, con texto al 140% en 320 px, y verifica que la interacción no modifica los datos del flujo.
- Pruebas existentes de navegación, formularios, aprobación, formalización, activación, pagos y persistencia correctas. Se ajustó la prueba de desembolso para descartar la notificación transitoria antes de pulsar el selector de fecha.
- Windows Release compilado y ejecutado; navegación nativa y redimensionamiento revisados. Demostración en `.review/menu-reference/windows-final-demo.gif`.
- Capturas de gerencia con su navegación real de cuatro opciones: `.review/ui-admin-1280.png`, `.review/ui-admin-390.png`, `.review/ui-solicitudes-390.png`. Capturas con solicitudes de prueba: `.review/ui-neutral-{admin,cliente}-{inicio,solicitudes}-{320,390,1280}.png` (el montaje aislado del portal administrativo utiliza su shell de tres opciones; la aplicación real usa el shell de gerencia de cuatro).

El motor de pruebas registra mensajes de plugins nativos no implementados (biometría y compartir comprobantes); son capturados por la aplicación y no fallan las pruebas. No se presenta esa salida como una verificación de esos plugins en dispositivos móviles.
