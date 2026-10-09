# Registro de cambios

Las novedades de cada versión se muestran dentro de la app cuando hay una
actualización disponible. Escribe cada versión como `## X.Y.Z` seguida de
viñetas; el workflow de release toma ese bloque como notas del release.

## 1.0.5
- Interés vencido configurable POR PRÉSTAMO: cada préstamo decide si acumula el interés de cada vencimiento cuando el anterior sigue pendiente. Viene activado por defecto (Opción B).
- Puedes desactivarlo en un préstamo concreto desde el menú (⋮) de su ficha, sin afectar a los demás.
- El interés de cada período se calcula SIEMPRE sobre el capital pendiente, nunca sobre el total adeudado (no hay interés sobre interés).
- Nueva sección "Buscar actualización" en Ajustes para comprobar manualmente si hay una versión nueva.
- Ajustes ahora muestra la versión instalada de la app.

## 1.0.4
- Interés estilo prestamista: el interés se genera al llegar cada vencimiento (opción A/B).
