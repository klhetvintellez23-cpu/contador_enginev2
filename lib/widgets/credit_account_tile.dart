import 'package:flutter/material.dart';
import '../services/credit_service.dart';
import '../screens/credit_portal_screen.dart';
import '../utils/app_theme.dart';
import 'app_ui.dart';

class CreditAccountTile extends StatelessWidget {
  final Map<String, dynamic> account;
  final String? customerName;
  const CreditAccountTile(
      {super.key, required this.account, this.customerName});
  @override
  Widget build(BuildContext context) {
    final service = CreditService();
    final app = service.applications
        .firstWhere((a) => a['id'] == account['applicationId']);
    final remaining = service
        .balance(app)
        .fold<int>(0, (s, r) => s + (r['remainingCents'] as int));
    return TouchSurface(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => CreditDetailScreen(id: app['id'] as String))),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(customerName ?? app['applicant'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        '${account['legacy'] == true ? 'Crédito conciliado' : 'Crédito amortizado'} · '
                        '${account['terms']['method'] == 'french' ? 'Francés' : 'Alemán'}',
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(remaining == 0
                        ? 'Saldado'
                        : 'Saldo contractual: USD ${(remaining / 100).toStringAsFixed(2)}')
                  ])),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted)
            ])));
  }
}
