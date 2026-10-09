import 'dart:ui';
import 'package:flutter/material.dart';
import 'local_fonts.dart';

/// Estilos compartidos por los modales, formularios y tarjetas de la app,
/// para mantener una misma estética "pill" en toda la aplicación.

const Color kFieldFill = Color(0xFFF3F4F8);

/// Input plano tipo "pill": sin borde, relleno gris claro, ícono en una
/// insignia circular de color. Usado en diálogos y formularios.
InputDecoration flatFieldDecoration({
  required String label,
  String? hint,
  String? helper,
  int? helperMaxLines,
  IconData? icon,
  String? prefixText,
  Color? iconColor,
}) {
  final accent = iconColor ?? const Color(0xFF7C3AED);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: helperMaxLines ?? 2,
    labelStyle: AppFonts.inter(color: Colors.grey[600], fontSize: 14),
    hintStyle: AppFonts.inter(color: Colors.grey[400], fontSize: 13),
    prefixIcon: icon != null
        ? Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
          )
        : null,
    prefixText: prefixText,
    filled: true,
    fillColor: kFieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
    ),
  );
}

/// Botón principal sólido y ancho, estilo "Continue" de la referencia.
ButtonStyle solidActionButtonStyle(BuildContext context, {Color? color}) {
  return ElevatedButton.styleFrom(
    backgroundColor: color ?? Theme.of(context).colorScheme.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor:
        (color ?? Theme.of(context).colorScheme.primary).withAlpha(120),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5),
  );
}

/// Diálogo base compartido: tarjeta blanca muy redondeada, consistente en
/// todos los modales de la app.
ShapeBorder dialogShape() =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

/// Muestra un diálogo con fondo difuminado y animación scale+fade de entrada.
/// Reemplaza [showDialog] en toda la app para una experiencia más premium.
Future<T?> showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withAlpha(50),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8 * anim.value,
          sigmaY: 8 * anim.value,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Campo minimalista: solo línea inferior, sin relleno ni ícono decorativo.
InputDecoration minimalFieldDecoration({
  required String label,
  String? hint,
  String? helper,
  int? helperMaxLines,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: helperMaxLines ?? 2,
    prefixText: prefixText,
    labelStyle: AppFonts.inter(color: Colors.grey[500], fontSize: 14),
    hintStyle: AppFonts.inter(color: Colors.grey[400], fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
    border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
    ),
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
    ),
  );
}

/// Cuerpo de diálogo con separador completo entre título y contenido.
/// Inserta un Divider de ancho completo y aplica el padding lateral estándar.
Widget dialogContent(List<Widget> children) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 1, color: Color(0xFFEEF0F5)),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ],
  );
}

/// Etiqueta de sección en mayúsculas tipo caption, usada como título de
/// bloques de formulario (p. ej. "SELECCIÓN DE CLIENTE").
TextStyle sectionCaptionStyle() => AppFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.grey[500],
      letterSpacing: 0.8,
    );

/// Botón/tarjeta "pill" tocable con ícono circular + texto + chevron,
/// usado por ejemplo para seleccionar un cliente.
class PillSelector extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const PillSelector({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF7C3AED),
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kFieldFill,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPlaceholder
                        ? Colors.grey[500]
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}
