import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PortfolioBalanceCard extends StatelessWidget {
  final String available;
  final String receivable;
  final int customers;
  final VoidCallback onLoan;
  final VoidCallback onReport;
  const PortfolioBalanceCard(
      {super.key,
      required this.available,
      required this.receivable,
      required this.customers,
      required this.onLoan,
      required this.onReport});
  @override
  Widget build(BuildContext context) {
    final balance =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        IconMedallion(Icons.account_balance_wallet_outlined),
        SizedBox(width: 12),
        Expanded(
            child: Text('Disponible para prestar',
                style: TextStyle(color: AppTheme.muted, fontSize: 14)))
      ]),
      const SizedBox(height: 16),
      Text(available,
          style: const TextStyle(
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4)),
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: onLoan,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo préstamo')),
    ]);
    final summary =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinanceGrid(children: [
        FinanceMetric(label: 'Por cobrar', value: receivable),
        FinanceMetric(label: 'Clientes', value: '$customers')
      ]),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: onReport,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Ver informe'))),
    ]);
    return FinanceCard(
        child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 680
                ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: balance),
                    const SizedBox(width: 24),
                    Expanded(child: summary)
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [balance, const SizedBox(height: 20), summary])));
  }
}

/// Soft, bounded modules shared by the portfolio and credit workspace.
class FinanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const FinanceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      this.color});
  @override
  Widget build(BuildContext context) =>
      Card(color: color, child: Padding(padding: padding, child: child));
}

class IconMedallion extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconMedallion(this.icon, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: AppTheme.neutral,
          borderRadius: BorderRadius.circular(size * .38)),
      child: Icon(icon, size: size * .48, color: AppTheme.primary));
}

class FinanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool prominent;
  const FinanceMetric(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.prominent = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.neutral, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, color: AppTheme.muted, size: 19),
          const SizedBox(height: 12)
        ],
        Text(value,
            style: TextStyle(
                fontSize: prominent ? 28 : 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
                height: 1.15)),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: AppTheme.muted, fontSize: 12, height: 1.3)),
      ]));
}

/// Wraps instead of squeezing financial values at narrow widths or large text.
class FinanceGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int columns;
  const FinanceGrid(
      {super.key,
      required this.children,
      this.minItemWidth = 125,
      this.columns = 2});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final count = ((box.maxWidth + 10) / (minItemWidth * scale + 10))
            .floor()
            .clamp(1, columns);
        final width = (box.maxWidth - 10 * (count - 1)) / count;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final child in children) SizedBox(width: width, child: child)
        ]);
      });
}

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeading(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5))),
        if (action != null) action!
      ]));
}

class DetailRows extends StatelessWidget {
  final Map<String, String> values;
  const DetailRows(this.values, {super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final entry in values.entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final label = Text(entry.key,
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 13));
                final value = Text(entry.value,
                    textAlign: narrow ? TextAlign.start : TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14));
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [label, const SizedBox(height: 4), value])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: label),
                            const SizedBox(width: 16),
                            Flexible(child: value)
                          ]);
              }))
      ]);
}
