import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'glass_surface.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  const AppSearchField(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.hint});

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassSurface(
        radius: 28,
        highlighted: _focus.hasFocus,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppTheme.ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: AppTheme.neutral.withValues(alpha: .65),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefixIcon: Icon(Icons.search_rounded,
                size: 22,
                color: _focus.hasFocus ? AppTheme.primary : AppTheme.muted),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                      _focus.requestFocus();
                    }),
          ),
        ),
      );
}
