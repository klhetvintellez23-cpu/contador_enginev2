# Menú de navegación: observación y reconstrucción

## Fuente y método

Referencia: [Collect UI, mobile-menu, Elia](https://collectui.com/designs/mobile-menu-ui-design-inspiration/00f461ac-7c78-4d72-a272-eb57d7e5c6d1).
El HTML enlaza una miniatura MP4. Se recuperó también el [clip completo optimizado](https://cdn.collectui.com/amplify_video/2108248308749832193/vid/avc1/1080x1080/pcs5di6d9drucUM9-optimized.mp4): 1080 × 1080, 9 segundos.
Copia local: `.review/menu-reference/reference-optimized.mp4`. Hojas de fotogramas en `frames/`, `forward/` y `return/` dentro de esa carpeta.
Se examinó el clip completo cada 500 ms y dos transiciones cada 50 ms. Los tiempos y curvas siguientes son **estimaciones visuales**: no se dispone del código original ni de eventos de entrada registrados; el seek del decodificador puede introducir error de un fotograma.

## Estados observados antes de implementar

- **A, reposo (0–1,30 s):** cápsula horizontal, cuatro iconos en una sola línea. Solo Home tiene etiqueta. Una única pastilla clara ocupa su icono y texto. Los otros iconos están delineados. El contenedor mide aproximadamente 860 × 170 píxeles en el video; el indicador 350 × 144, con márgenes de unos 12 píxeles. No hay panel desplegable ni cristal visible.
- **B, activación (1,35–1,45 s):** el cursor llega a Saved. La etiqueta Home pierde opacidad primero. La pastilla empieza a trasladarse y a contraerse. No se observa un ripple ni un segundo foco.
- **C, movimiento (1,45–1,70 s):** el indicador cruza hacia Saved; Home pierde el ancho reservado a su texto y Saved gana espacio. Los iconos se redistribuyen horizontalmente. Saved se desplaza hacia la izquierda para dejar espacio al texto que aparece después. La pastilla conserva su altura y sus extremos semicirculares.
- **D, resultado (1,85–2,00 s):** Saved muestra icono sólido y texto, los demás solo icono. La pastilla termina de ensancharse con desaceleración. No se observa rotación ni rebote claro.
- **E, retorno (7,90–8,45 s):** Profile → Home recorre toda la cápsula. La pastilla se estrecha casi hasta un círculo al cruzar las opciones intermedias y vuelve a expandirse en Home. Los iconos bajo la pastilla adquieren apariencia sólida al cruzarla: conviene una máscara compartida. La etiqueta Profile se retira antes de aparecer Home. Es la misma coreografía en dirección contraria, con mayor contracción por la distancia.

El clip no muestra abrir/cerrar un panel, hover sostenido, navegación de contenido, pantalla táctil ni interrupciones rápidas. Esos comportamientos se adaptan explícitamente a Contador Engine y no se presentan como observaciones.

## Tabla técnica

Coordenadas aproximadas relativas a la cápsula original de 860 × 170 px. Los rangos temporales se miden desde el primer cambio visible.

| Elemento | Posición inicial → final | Tamaño inicial → final | Transformación | Duración estimada | Retraso estimado | Curva inferida | Orden |
|---|---|---|---|---|---|---|---|
| Superficie exterior | Fija, centrada | ≈860 × 170 → similar | Sin expansión de fondo/panel | — | — | — | Permanente |
| Etiqueta saliente | A la derecha del icono activo → mismo entorno, recortada | Ancho de texto → 0 espacio reservado | Opacidad 1 → 0 y contracción horizontal del espacio | 80–120 ms | 0 | Salida rápida | 1 |
| Pastilla única, Home → Saved | x≈12 → x≈175; y≈12 | ≈350 × 144 → ≈340 × 144; intermedio ≈260 × 144 | Traslación + contracción y expansión de ancho | 450–550 ms | 0–30 ms | Aceleración breve, desaceleración larga | 2 |
| Iconos y celdas | Home x≈90 → ≈90; Saved x≈440 → ≈260 | Iconos ≈54–60 px, constantes | Redistribución horizontal por cambio de ancho; contorno/sólido bajo máscara | 300–450 ms | ≈40 ms | Desaceleración | 2, solapado |
| Etiqueta entrante | A la derecha del nuevo icono, dentro de la celda | Espacio 0 → ancho medido del texto | Recorte/revelado + opacidad 0 → 1 | 140–200 ms | ≈230–280 ms | Suave, sin rebote | 3 |
| Pastilla Profile → Home | x≈490 → x≈12 | ≈365 × 144 → ≈350 × 144; intermedio casi 144 × 144 | Recorrido largo y contracción mayor, sin duplicarse | 450–550 ms | 0 | Misma desaceleración | 2 |
| Iconos atravesados | Centros móviles de sus celdas | Constante | Cambio de apariencia dentro de la pastilla | Depende de la intersección | Sin temporizador propio | Máscara geométrica | Durante recorrido |

## Implementación

- Mismo orden de movimiento y una sola pastilla; superficie blanca/secundaria `#FAFAFC`, foco `#F1E4FF`, iconos activos `#8D45E8`, interacción `#B976FF`, texto `#191620`/`#77717F`.
- Altura exterior 64 dp y pastilla de 52 dp; iconos de 24 dp. Ancho ajustado a etiquetas reales y espacio disponible; texto únicamente en la opción activa. Objetivos táctiles de al menos 48 dp en tamaños móviles habituales.
- Secuencia total de 560 ms, incluida la estabilización; desaparición inicial de texto, viaje y redistribución solapados, nueva etiqueta en el tramo final. Son parámetros de reconstrucción, no mediciones exactas.
- Hover mediante color del icono, presión mediante escala de 120 ms; sin otra superficie de selección, halo, ripple ni cristal.
- Gerencia: Inicio, Solicitudes, Cartera, Perfil. Solicitantes: Inicio, Mis solicitudes, Perfil. Se conservan callbacks y contenido existente.
- Interrupciones: se toma la geometría visible como origen del siguiente viaje. Redimensionamiento proporcional, navegación por teclado, semántica y movimiento reducido.

## Validación

- Componente `lib/widgets/morphing_navigation.dart`, integrado en el shell de ambos recorridos. Una sola geometría de selección recorta también los iconos sólidos y las etiquetas; los iconos delineados usan su máscara inversa.
- La comparación de seis instantes de apertura de la etiqueta reveló una contracción demasiado tardía. Se adelantó el mínimo de ancho a unos 140 ms, se ajustó la traslación a una salida rápida con desaceleración y se elevó el texto a 16 dp. La pastilla vuelve a expandirse antes de revelar la etiqueta.
- Hoja comparativa: `.review/menu-reference/comparison-forward.png`. Usa el mismo renderizador Flutter y cuatro destinos; las etiquetas españolas requieren anchuras distintas a Home/Saved. Se conserva la secuencia, no se afirma una copia píxel a píxel ni una curva original conocida.
- `flutter analyze --no-pub`: sin incidencias. `flutter test --no-pub --reporter expanded`: **66 pruebas correctas**, incluidos recorrido, contracción, retorno, continuidad al interrumpir, teclado, semántica, RTL, movimiento reducido y tamaños adaptables. La suite también verifica los flujos financieros existentes.
- Compilación nativa Windows correcta y ejecución del binario Release. Grabación real de la sesión visible de Cumplimiento (Inicio/Bandeja/Perfil), con ida, retorno y cambios separados por aproximadamente 80 ms. Se conservaron su sesión y datos. Las cuatro opciones de gerencia y las tres de solicitantes se cubren en las pruebas de widgets.
- Grabaciones: `.review/menu-reference/windows-final-demo.gif` (ventana completa) y `windows-final-menu.gif` (detalle del menú), **160 fotogramas en 8,512 s**. Es la frecuencia del capturador, no una medición de FPS de Flutter. Capturas de estados `windows-final-state-0.png` a `windows-final-state-6.png`; ventana estrecha `windows-final-390.png`.
- Después de la petición de refinamiento visual, el componente del menú se conservó. El shell reserva su altura para evitar solapamiento; el tema, las tarjetas y los indicadores del contenido se documentan en `refinamiento-visual-neutral.md`.
