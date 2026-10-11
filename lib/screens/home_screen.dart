import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/local_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/payment.dart';
import '../providers/debt_provider.dart';
import '../services/local_database_service.dart';
import '../services/local_cache_service.dart';
import '../services/app_lock_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../utils/receipt_share_helper.dart';
import '../utils/phone_helper.dart';
import '../utils/sensitive_action_guard.dart';
import '../utils/import_backup_flow.dart';
import '../widgets/capital_alerts_banner.dart';
import '../widgets/update_dialog.dart';
import 'customer_detail_screen.dart';
import 'customer_receipts_screen.dart';
import 'add_loan_screen.dart';
import 'account_settings_screen.dart';
import 'capital_history_screen.dart';
import 'todays_collections_screen.dart';
import 'daily_closing_screen.dart';
import 'credit_portal_screen.dart';
import '../widgets/role_shell.dart';
import '../widgets/credit_account_tile.dart';
import '../utils/shared_styles.dart';
import '../utils/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_search_field.dart';
import '../widgets/finance_ui.dart';

Color _avatarColorFor(String name) => const Color(0xFF7935C8);

void showAddCustomerDialog(BuildContext context) {
  final provider = context.read<DebtProvider>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final id = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  showBlurDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                scrollable: true,
                title: const Text('Añadir cliente'),
                content: Form(
                    key: form,
                    child: SizedBox(
                        width: 360,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: name,
                              enabled: !saving,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  labelText: 'Nombre completo'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Escribe el nombre del cliente.'
                                      : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: phone,
                              enabled: !saving,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  labelText: 'Teléfono',
                                  prefixText: '+507 ',
                                  hintText: '61234567',
                                  helperText:
                                      'Para compartir comprobantes por WhatsApp.')),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: id,
                              enabled: !saving,
                              decoration: const InputDecoration(
                                  labelText: 'Cédula o identificación')),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ]))),
                actions: [
                  TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              update(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                await provider.addCustomer(
                                    name.text.trim(),
                                    normalizePanamaPhone(phone.text),
                                    id.text.trim());
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              } catch (_) {
                                if (dialogContext.mounted) {
                                  update(() => error =
                                      'No pudimos guardar el cliente. Intenta nuevamente.');
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  update(() => saving = false);
                                }
                              }
                            },
                      child: Text(saving ? 'Guardando…' : 'Guardar cliente')),
                ],
              ))).whenComplete(() {
    name.dispose();
    phone.dispose();
    id.dispose();
  });
}

class HomeScreen extends StatefulWidget {
  final bool embedded;
  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.embedded) _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final release = await UpdateService().checkForUpdate();
    if (release != null && mounted) await showUpdateDialog(context, release);
  }

  void _onCategoryTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _showExportFormatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Exportar reporte',
                    style: AppFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Elige el formato para tu reporte de cartera.',
                    style: AppFonts.inter(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(26),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.table_chart_rounded,
                        color: Color(0xFF10B981)),
                  ),
                  title: Text('CSV (Excel)',
                      style: AppFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Movimientos detallados y cartera por cliente.',
                      style: AppFonts.inter(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _exportAndShare(context, isPdf: false);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(26),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEF4444)),
                  ),
                  title: Text('PDF',
                      style: AppFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Resumen de cartera listo para imprimir o enviar.',
                      style: AppFonts.inter(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _exportAndShare(context, isPdf: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportAndShare(BuildContext context,
      {required bool isPdf}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generando reporte ${isPdf ? "PDF" : "CSV"}...')),
    );

    final provider = Provider.of<DebtProvider>(context, listen: false);
    final path =
        isPdf ? await provider.exportPDF() : await provider.exportData();
    if (!context.mounted) return;

    if (path != null && path.startsWith('download:')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Descarga iniciada.')));
      return;
    }
    if (path != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          title: 'Reporte de Contador Engine',
          text: 'Reporte listo para compartir o guardar.',
        ),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Reporte listo. Puedes guardarlo o compartirlo desde el menú que se abrió.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el reporte. Intenta nuevamente.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded) {
      return RoleShell(
          index: _currentIndex,
          labels: const ['Inicio', 'Solicitudes', 'Cartera', 'Perfil'],
          selectedIcons: const [
            Icons.home_rounded,
            Icons.description_rounded,
            Icons.account_balance_wallet_rounded,
            Icons.person_rounded
          ],
          icons: const [
            Icons.home_outlined,
            Icons.description_outlined,
            Icons.account_balance_wallet_outlined,
            Icons.person_outline
          ],
          onSelected: _onCategoryTapped,
          child: TabContent(index: _currentIndex, children: [
            CreditPortalScreen(
                embedded: true, initialTab: 0, onNavigate: _onCategoryTapped),
            const CreditPortalScreen(embedded: true, initialTab: 1),
            const HomeScreen(embedded: true),
            const CreditPortalScreen(embedded: true, initialTab: 2),
          ]));
    }
    final pages = <Widget>[
      _DashboardView(
          onCategoryTap: _onCategoryTapped,
          onExport: () => _showExportFormatSheet(context)),
      const _HistoryView(),
      const _StatisticsView(),
      const _SettingsView(),
    ];
    return Column(children: [
      SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                      label: Text(const ['Clientes', 'Cobros', 'Informes'][i]),
                      labelStyle: TextStyle(
                          fontFamily: 'AppRoboto',
                          fontSize: 13,
                          color: _currentIndex == i
                              ? AppTheme.primary
                              : AppTheme.muted,
                          fontWeight: _currentIndex == i
                              ? FontWeight.w700
                              : FontWeight.w500),
                      selected: _currentIndex == i,
                      onSelected: (_) => _onCategoryTapped(i)),
              ]))),
      Expanded(
          child: PageFrame(
              child: TabContent(index: _currentIndex, children: pages))),
    ]);
  }
}

class BusinessSettingsScreen extends StatelessWidget {
  const BusinessSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ajustes del negocio')),
      body: const PageFrame(child: _SettingsView()));
}

class _DashboardView extends StatefulWidget {
  final Function(int) onCategoryTap;
  final VoidCallback onExport;
  const _DashboardView({required this.onCategoryTap, required this.onExport});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context) {
    final provider = Provider.of<DebtProvider>(context, listen: false);
    final overdue = provider.overdueLoans;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CapitalAlertsBanner(
                    padding: EdgeInsets.zero,
                    onTapAlert: () => Navigator.pop(sheetContext),
                  ),
                  Text('Clientes atrasados',
                      style: AppFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'No registran cobro dentro de su ciclo esperado (diario, semanal, etc.)',
                    style: AppFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: overdue.isEmpty
                        ? Center(
                            child: Text(
                                '¡Estás al día! No hay clientes atrasados.',
                                style: AppFonts.inter(color: Colors.grey)),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: overdue.length,
                            itemBuilder: (context, index) {
                              final loan = overdue[index];
                              final customer =
                                  provider.getCustomerById(loan.customerId);
                              final daysSince = DateTime.now()
                                  .difference(provider.lastActivityDate(loan))
                                  .inDays;

                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFEF4444).withAlpha(26),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFEF4444)),
                                ),
                                title: Text(customer?.name ?? 'Cliente',
                                    style: AppFonts.inter(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Sin cobro hace $daysSince día(s) · ${loan.title}',
                                  style: AppFonts.inter(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currency
                                          .format(provider.currentDebt(loan)),
                                      style: AppFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFEF4444)),
                                    ),
                                    if (customer != null) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.chat_rounded,
                                            size: 18, color: Color(0xFF10B981)),
                                        tooltip: 'Recordar por WhatsApp',
                                        onPressed: () {
                                          ReceiptShareHelper
                                              .sendOverdueReminder(
                                            context: context,
                                            customer: customer,
                                            loan: loan,
                                            daysSince: daysSince,
                                            remaining:
                                                provider.currentDebt(loan),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  if (customer != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CustomerDetailScreen(
                                              customer: customer)),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final query = _searchQuery.trim().toLowerCase();
    final customers = provider.customers
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            (c.cedula ?? '').toLowerCase().contains(query))
        .toList();
    return RefreshIndicator(
      onRefresh: provider.fetchAll,
      child: CustomScrollView(
        key: const PageStorageKey('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
              child: PageHeading(
            title: provider.businessName?.trim().isNotEmpty == true
                ? provider.businessName!
                : 'Tu cartera',
            subtitle: 'Todo lo importante, en un lugar.',
            trailing: IconButton(
              tooltip: 'Avisos de cobro',
              onPressed: () => _showNotificationsSheet(context),
              icon: Badge(
                  isLabelVisible: provider.overdueCount > 0,
                  label: Text('${provider.overdueCount}'),
                  child: const Icon(Icons.notifications_none_rounded)),
            ),
          )),
          SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                  child: Reveal(
                      delayMilliseconds: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (provider.isOffline || provider.pendingCount > 0)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                    provider.isOffline
                                        ? 'Trabajando sin conexión. Tus cambios se guardan en este equipo.'
                                        : 'Guardando ${provider.pendingCount} cambios…',
                                    style: const TextStyle(
                                        color: AppTheme.muted))),
                          PortfolioBalanceCard(
                              available: currency.format(provider.moneyInHand),
                              receivable:
                                  currency.format(provider.totalReceivable),
                              customers: provider.customers.length,
                              onReport: () => widget.onCategoryTap(2),
                              onLoan: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => const AddLoanScreen()))),
                          const SizedBox(height: 16),
                          TouchSurface(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const TodaysCollectionsScreen())),
                              child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(children: [
                                    const Icon(Icons.today_outlined,
                                        color: AppTheme.primary),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          const Text('Cobros de hoy',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 3),
                                          Text(
                                              provider.todaysCollections.isEmpty
                                                  ? 'No hay visitas pendientes'
                                                  : '${provider.todaysCollections.length} préstamos para revisar',
                                              style: const TextStyle(
                                                  color: AppTheme.muted,
                                                  fontSize: 13)),
                                        ])),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppTheme.muted),
                                  ]))),
                          if (provider.capitalAlerts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ExpansionTile(
                                title: Text(provider.capitalAlerts.length == 1
                                    ? '1 aviso de cartera'
                                    : '${provider.capitalAlerts.length} avisos de cartera'),
                                children: const [
                                  CapitalAlertsBanner(padding: EdgeInsets.zero)
                                ]),
                          ],
                          const SizedBox(height: 28),
                          if (provider.activeCreditAccounts.isNotEmpty) ...[
                            Text('Créditos activados',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            for (final account
                                in provider.activeCreditAccounts.where((a) {
                              final customer =
                                  provider.getCustomerById(a['customerId']);
                              return query.isEmpty ||
                                  (customer?.name
                                          .toLowerCase()
                                          .contains(query) ??
                                      false) ||
                                  (customer?.cedula
                                          ?.toLowerCase()
                                          .contains(query) ??
                                      false);
                            }))
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: CreditAccountTile(
                                      account: account,
                                      customerName: provider
                                          .getCustomerById(
                                              account['customerId'])
                                          ?.name)),
                            const SizedBox(height: 20),
                          ],
                          Row(children: [
                            const Expanded(
                                child: Text('Clientes',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700))),
                            TextButton.icon(
                                onPressed: () => showAddCustomerDialog(context),
                                icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 18),
                                label: const Text('Añadir')),
                            PopupMenuButton<String>(
                                tooltip: 'Más herramientas',
                                onSelected: (value) {
                                  if (value == 'export') widget.onExport();
                                  if (value == 'closing') {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const DailyClosingScreen()));
                                  }
                                },
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'export',
                                          child: Text('Exportar reporte')),
                                      PopupMenuItem(
                                          value: 'closing',
                                          child: Text('Cierre del día')),
                                    ]),
                          ]),
                          const SizedBox(height: 10),
                          AppSearchField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              hint: 'Buscar por nombre o cédula'),
                          const SizedBox(height: 16),
                        ],
                      )))),
          if (provider.isLoading && customers.isEmpty)
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: LinearProgressIndicator()))
          else if (customers.isEmpty)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.people_outline_rounded,
                          size: 36, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                          query.isEmpty
                              ? 'Tu primer cliente empieza aquí'
                              : 'No encontramos coincidencias',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                          query.isEmpty
                              ? 'Añade sus datos para registrar un préstamo.'
                              : 'Prueba con otro nombre o cédula.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.muted)),
                      if (query.isEmpty)
                        TextButton(
                            onPressed: () => showAddCustomerDialog(context),
                            child: const Text('Añadir cliente')),
                    ])))
          else
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final loans = provider.getLoansByCustomer(customer.id!);
                      final debt = loans.fold<double>(0, (sum, loan) {
                        final value = provider.currentDebt(loan);
                        return sum + (value > 0 ? value : 0);
                      });
                      final overdue = provider.overdueLoans
                          .any((loan) => loan.customerId == customer.id);
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TouchSurface(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => CustomerDetailScreen(
                                          customer: customer))),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Hero(
                                        tag: 'customer-${customer.id}',
                                        child: CircleAvatar(
                                            backgroundColor: AppTheme.neutral,
                                            foregroundColor: AppTheme.primary,
                                            child: Text(customer.name.isEmpty
                                                ? '?'
                                                : customer.name[0]
                                                    .toUpperCase()))),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(customer.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(
                                              overdue
                                                  ? 'Cobro pendiente'
                                                  : loans.isEmpty
                                                      ? 'Sin préstamos'
                                                      : debt <= 0
                                                          ? 'Al día'
                                                          : loans.length == 1
                                                              ? '1 préstamo'
                                                              : '${loans.length} préstamos',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: overdue
                                                      ? const Color(0xFFB54738)
                                                      : AppTheme.muted)),
                                        ])),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(currency.format(debt),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600))),
                                  ]))));
                    })),
          SliverToBoxAdapter(
              child:
                  SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 20,
            left: 28,
            right: 28,
          ),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comprobantes',
                style: AppFonts.inter(
                    color: AppTheme.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              AppSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                hint: 'Buscar cliente…',
              ),
            ],
          ),
        ),

        // Cada cliente lleva a sus propios comprobantes (CustomerReceiptsScreen).
        Expanded(
          child: Consumer<DebtProvider>(
            builder: (context, provider, child) {
              final query = _searchQuery.trim().toLowerCase();
              final customers = provider.customers.where((c) {
                if (query.isEmpty) return true;
                return c.name.toLowerCase().contains(query) ||
                    (c.cedula ?? '').toLowerCase().contains(query);
              }).toList()
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (provider.isLoading && customers.isEmpty) {
                return _Shimmer(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    children:
                        List.generate(5, (_) => const _CustomerCardSkeleton()),
                  ),
                );
              }

              if (customers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No se encontraron clientes.',
                          style: AppFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('Toca un cliente para ver sus comprobantes.',
                          style: AppFonts.inter(
                              fontSize: 12, color: AppTheme.muted)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  final receiptCount = LocalCacheService()
                      .receiptsForCustomer(customer.id.toString())
                      .length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerReceiptsScreen(customer: customer),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: _avatarColorFor(customer.name)
                                        .withAlpha(26),
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    customer.name[0].toUpperCase(),
                                    style: AppFonts.inter(
                                        color: _avatarColorFor(customer.name),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer.name,
                                        style: AppFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: AppTheme.ink)),
                                    const SizedBox(height: 4),
                                    Text(
                                      receiptCount == 0
                                          ? 'Sin comprobantes aún'
                                          : '$receiptCount comprobante${receiptCount == 1 ? '' : 's'}',
                                      style: AppFonts.inter(
                                          fontSize: 12, color: AppTheme.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _StatsPeriod { week, month, year }

extension on _StatsPeriod {
  String get label {
    switch (this) {
      case _StatsPeriod.week:
        return '7D';
      case _StatsPeriod.month:
        return '30D';
      case _StatsPeriod.year:
        return 'Año';
    }
  }

  String get subtitle {
    switch (this) {
      case _StatsPeriod.week:
        return 'Cobros de los últimos 7 días';
      case _StatsPeriod.month:
        return 'Cobros de los últimos 30 días';
      case _StatsPeriod.year:
        return 'Cobros por mes, últimos 12 meses';
    }
  }
}

class _StatisticsView extends StatefulWidget {
  const _StatisticsView();

  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView> {
  _StatsPeriod _period = _StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return Column(
      children: [
        const PageHeading(
            title: 'Informes', subtitle: 'Entiende cómo se mueve tu dinero.'),
        Expanded(
          child: Consumer<DebtProvider>(
            builder: (context, provider, child) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ganancia cobrada',
                                    style: TextStyle(color: AppTheme.muted)),
                                const SizedBox(height: 10),
                                Text(
                                    currencyFormat
                                        .format(provider.realizedProfit),
                                    style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Interés recibido, descontando el capital recuperado.',
                                    style: TextStyle(
                                        color: AppTheme.muted, fontSize: 13)),
                              ]))),
                  const SizedBox(height: 28),
                  Text('Métricas clave',
                      style: AppFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Resumen financiero detallado',
                    style: AppFonts.inter(fontSize: 12, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  ExpansionTile(
                      title: const Text('Desglose del capital'),
                      children: [
                        AdaptiveGrid(children: [
                          _MetricCard(
                            label: 'Capital total',
                            value:
                                currencyFormat.format(provider.initialCapital),
                            color: const Color(0xFF6D28D9),
                            icon: Icons.account_balance_rounded,
                            caption: 'Total',
                          ),
                          _MetricCard(
                            label: 'Capital disponible',
                            value: currencyFormat.format(provider.moneyInHand),
                            color: const Color(0xFF10B981),
                            icon: Icons.account_balance_wallet_rounded,
                            caption: 'Disponible',
                          ),
                          _MetricCard(
                            label: 'Capital prestado',
                            value:
                                currencyFormat.format(provider.activeCapital),
                            color: const Color(0xFF7935C8),
                            icon: Icons.monetization_on_rounded,
                            caption: 'En préstamo',
                          )
                        ])
                      ]),
                  const SizedBox(height: 24),
                  Container(
                    height: 380,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Flujo de cobros',
                                      style: AppFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text(_period.subtitle,
                                      style: AppFonts.inter(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: _StatsPeriod.values.map((p) {
                            final selected = p == _period;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _period = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    p.label,
                                    style: AppFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _period == _StatsPeriod.year
                              ? _buildYearlyChart(
                                  provider.portfolioPayments, context,
                                  currency: currencyFormat)
                              : _buildDailyChart(
                                  provider.portfolioPayments,
                                  context,
                                  days: _period == _StatsPeriod.week ? 7 : 30,
                                  currency: currencyFormat,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BigNumberCard(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    value:
                        '${provider.allLoans.where((l) => provider.currentDebt(l) <= 0).length + provider.settledCreditCount}',
                    label: 'Préstamos liquidados',
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final liquidados = provider.allLoans
                            .where((l) => provider.currentDebt(l) <= 0)
                            .length +
                        provider.settledCreditCount;
                    final total = provider.allLoans.length +
                        provider.activeCreditAccounts.length;
                    final rate = total == 0 ? 0.0 : liquidados / total;
                    return _ProgressMetricCard(
                      label: 'Tasa de cobro',
                      percentText: total == 0
                          ? '—'
                          : '${(rate * 100).toStringAsFixed(0)}%',
                      progress: rate,
                      color: const Color(0xFF6D28D9),
                      description: total == 0
                          ? 'Todavía no hay préstamos registrados.'
                          : rate >= 0.8
                              ? 'Excelente desempeño operativo. La mayoría de los préstamos ya están liquidados.'
                              : 'Seguimiento en curso. Revisa los préstamos activos para mejorar la tasa de cobro.',
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(List<Payment> payments, BuildContext context,
      {required int days, required NumberFormat currency}) {
    final theme = Theme.of(context);
    final spots = _generateDailySpots(payments, days);
    final maxY = spots.fold(0.0, (m, s) => s.y > m ? s.y : m);
    const dayAbbr = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    // En vistas largas mostramos menos etiquetas para que no se encimen.
    final labelStep = days <= 7 ? 1 : (days / 6).ceil();
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipBorder: BorderSide(color: Colors.grey.shade200),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      currency.format(s.y),
                      AppFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: theme.colorScheme.primary),
                    ))
                .toList(),
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i % labelStep != 0) return const SizedBox.shrink();
                final day =
                    DateTime.now().subtract(Duration(days: days - 1 - i));
                final label = days <= 7
                    ? dayAbbr[(day.weekday - 1) % 7]
                    : DateFormat('d/M').format(day);
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    label,
                    style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY > 0 ? maxY * 1.25 : 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withAlpha(60),
                  theme.colorScheme.primary.withAlpha(0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateDailySpots(List<Payment> payments, int days) {
    final List<FlSpot> spots = [];
    for (int i = 0; i < days; i++) {
      final day = DateTime.now().subtract(Duration(days: days - 1 - i));
      final amount = payments
          .where((p) =>
              p.date.year == day.year &&
              p.date.month == day.month &&
              p.date.day == day.day)
          .fold(0.0, (sum, p) => sum + p.amount);
      spots.add(FlSpot(i.toDouble(), amount));
    }
    return spots;
  }

  Widget _buildYearlyChart(List<Payment> payments, BuildContext context,
      {required NumberFormat currency}) {
    final theme = Theme.of(context);
    const monthAbbr = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final now = DateTime.now();
    final totals = <double>[];
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final amount = payments
          .where(
              (p) => p.date.year == month.year && p.date.month == month.month)
          .fold(0.0, (sum, p) => sum + p.amount);
      totals.add(amount);
    }
    final maxY = totals.fold(0.0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipBorder: BorderSide(color: Colors.grey.shade200),
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              currency.format(rod.toY),
              AppFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: theme.colorScheme.primary),
            ),
          ),
        ),
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY > 0 ? maxY * 1.25 : 10,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final month = DateTime(now.year, now.month - (11 - i), 1);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthAbbr[month.month - 1],
                    style: AppFonts.inter(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < totals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totals[i],
                  color: theme.colorScheme.primary,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FullBleedDivider extends StatelessWidget {
  const _FullBleedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 1,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: constraints.maxWidth + 40,
            alignment: Alignment.center,
            child: const Divider(
                height: 1, thickness: 1, color: Color(0xFFEDEEEF)),
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final TextEditingController _businessNameController = TextEditingController();
  late bool _autoShareReceipt;
  late bool _overdueAlertsEnabled;
  late bool _dailyReminderEnabled;
  late int _overdueGraceDays;
  bool _appLockEnabled = false;
  bool _appLockUseBiometrics = false;
  bool _canUseBiometrics = false;
  String _appVersion = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DebtProvider>(context, listen: false);
    _businessNameController.text = provider.businessName ?? '';
    _autoShareReceipt = LocalCacheService().autoShareReceipt;
    _overdueAlertsEnabled = LocalCacheService().overdueAlertsEnabled;
    _dailyReminderEnabled = LocalCacheService().dailyReminderEnabled;
    _overdueGraceDays = LocalCacheService().overdueGraceDays;
    _loadAppLockState();
    _loadAppVersion();
    if (_dailyReminderEnabled) {
      NotificationService().requestPermission();
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      // Sin la versión, la sección sigue funcionando; solo no la muestra.
    }
  }

  /// Comprobación manual de actualización desde Ajustes. A diferencia del
  /// chequeo silencioso del arranque, informa siempre el resultado.
  Future<void> _checkForUpdateManually() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final result = await UpdateService().checkForUpdateDetailed();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await showUpdateDialog(context, result.release!);
        break;
      case UpdateCheckStatus.upToDate:
        _showUpdateSnack('Ya tienes la última versión instalada.');
        break;
      case UpdateCheckStatus.notSupported:
        _showUpdateSnack(
            'La actualización dentro de la app solo está disponible en Android.');
        break;
      case UpdateCheckStatus.failed:
        _showUpdateSnack(
            'No se pudo comprobar. Revisa tu conexión e inténtalo de nuevo.');
        break;
    }
  }

  void _showUpdateSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7935C8),
      ),
    );
  }

  Future<void> _loadAppLockState() async {
    final enabled = await AppLockService().isEnabled;
    final useBio = await AppLockService().useBiometrics;
    final canBio = await AppLockService().canUseBiometrics;
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _appLockUseBiometrics = useBio;
      _canUseBiometrics = canBio;
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  void _saveBusinessName() {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) return;
    Provider.of<DebtProvider>(context, listen: false).setBusinessName(name);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nombre del negocio actualizado.')),
    );
  }

  Future<void> _pickBusinessLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final provider = Provider.of<DebtProvider>(context, listen: false);
    final dir = await getApplicationSupportDirectory();
    final ext = picked.path.split('.').last;
    final saved =
        await File(picked.path).copy('${dir.path}/business_logo.$ext');

    await provider.setBusinessLogoPath(saved.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imagen del negocio actualizada.')),
    );
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    showBlurDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: dialogShape(),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              title: Text('Crear PIN',
                  style: AppFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 17)),
              content: dialogContent([
                Text('Elegí un PIN de 4 a 6 dígitos para desbloquear la app.',
                    style: AppFonts.inter(fontSize: 13, color: AppTheme.muted)),
                const SizedBox(height: 20),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: minimalFieldDecoration(label: 'PIN'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: minimalFieldDecoration(label: 'Confirmar PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFEF4444), fontSize: 12)),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Guarda tu PIN y un respaldo externo. Los datos están en este dispositivo; reinstalar la app puede borrarlos.',
                    style: AppFonts.inter(
                        fontSize: 11, color: const Color(0xFF92400E)),
                  ),
                ),
              ]),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text('Cancelar',
                      style: AppFonts.inter(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text;
                    if (pin.length < 4) {
                      setDialogState(() =>
                          error = 'El PIN debe tener al menos 4 dígitos.');
                      return;
                    }
                    if (pin != confirmController.text) {
                      setDialogState(() => error = 'Los PIN no coinciden.');
                      return;
                    }
                    await AppLockService().setPin(pin);
                    await AppLockService().setEnabled(true);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    setState(() => _appLockEnabled = true);
                  },
                  style: solidActionButtonStyle(context),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      pinController.dispose();
      confirmController.dispose();
    });
  }

  void _showAddCapitalDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSaving = false;

    showBlurDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: dialogShape(),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          title: Text('Agregar capital',
              style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
          content: dialogContent([
            Text(
                'Registra un nuevo aporte al presupuesto de préstamos. Esto aumentará tu capital disponible.',
                style: AppFonts.inter(fontSize: 13, color: AppTheme.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: minimalFieldDecoration(label: 'Monto a agregar'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              decoration: minimalFieldDecoration(
                label: 'Motivo / Descripción',
                hint: 'Ej: Préstamo familiar, ahorro personal...',
              ),
            ),
          ]),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Text('Cancelar',
                  style: AppFonts.inter(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final amount =
                          double.tryParse(amountController.text) ?? 0;
                      final note = noteController.text.trim();

                      if (amount <= 0 || note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor ingresa monto y motivo.'),
                            backgroundColor: Color(0xFFF59E0B),
                          ),
                        );
                        return;
                      }

                      setState(() => isSaving = true);
                      // Se capturan antes del await: este diálogo se puede
                      // cerrar tocando afuera mientras se espera la
                      // respuesta, y no hay que volver a resolver el
                      // BuildContext después de ese salto asíncrono.
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await Provider.of<DebtProvider>(context, listen: false)
                            .addCapitalEntry(amount, note);
                        if (!context.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Capital agregado correctamente.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setState(() => isSaving = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Error al guardar el capital.'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              style: solidActionButtonStyle(context),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const PageHeading(
            title: 'Ajustes', subtitle: 'Tu negocio, a tu manera.'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SettingsGroup(
                  title: 'Negocio',
                  subtitle: 'Nombre e imagen de tus comprobantes',
                  children: [
                    _SettingsCard(children: [
                      Center(
                        child: Consumer<DebtProvider>(
                          builder: (context, provider, child) {
                            final logoPath = provider.businessLogoPath;
                            return GestureDetector(
                              onTap: _pickBusinessLogo,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: logoPath != null
                                        ? FileImage(File(logoPath))
                                        : null,
                                    child: logoPath == null
                                        ? Icon(Icons.storefront_rounded,
                                            size: 36, color: AppTheme.muted)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.edit_rounded,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _businessNameController,
                        decoration: minimalFieldDecoration(
                          label: 'Nombre del negocio',
                          hint: 'Ej: Préstamos Ana',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Así vas a firmar los comprobantes que le llegan a tus clientes por WhatsApp.',
                        style: AppFonts.inter(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _saveBusinessName,
                          child: Text('Guardar',
                              style:
                                  AppFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ]),
              SettingsGroup(
                  title: 'Capital',
                  subtitle: 'Disponible y movimientos',
                  children: [
                    Consumer<DebtProvider>(
                      builder: (context, provider, child) {
                        final currency = NumberFormat.currency(
                            symbol: '\$ ', decimalDigits: 2);
                        final preview =
                            provider.capitalHistory.take(3).toList();

                        return _SettingsCard(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Presupuesto disponible',
                                  style: AppFonts.inter(
                                      fontSize: 13, color: Colors.grey[600])),
                              GestureDetector(
                                onTap: () => _showAddCapitalDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.primary.withAlpha(26),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          size: 16,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text('Agregar',
                                          style: AppFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color:
                                                  theme.colorScheme.primary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _AnimatedCurrency(
                            value: provider.initialCapital,
                            format: currency,
                            style: AppFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                                color: AppTheme.ink),
                          ),
                          const SizedBox(height: 16),
                          if (preview.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                  'Todavía no hay movimientos de capital.',
                                  style: AppFonts.inter(
                                      fontSize: 12, color: Colors.grey)),
                            )
                          else
                            ...preview.map((entry) {
                              final isPositive = entry.amount >= 0;
                              final color = isPositive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color:
                                      theme.colorScheme.primary.withAlpha(13),
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const CapitalHistoryScreen()),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: color.withAlpha(26),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isPositive
                                                  ? Icons.arrow_upward_rounded
                                                  : Icons
                                                      .arrow_downward_rounded,
                                              size: 14,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (entry.note ??
                                                          'Sin descripción')
                                                      .toUpperCase(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey[600],
                                                      letterSpacing: 0.3),
                                                ),
                                                Text(
                                                  DateFormat('dd MMM, yyyy')
                                                      .format(entry.createdAt),
                                                  style: AppFonts.inter(
                                                      fontSize: 10,
                                                      color: AppTheme.muted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${isPositive ? '+' : ''}${currency.format(entry.amount)}',
                                            style: AppFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right_rounded,
                                              size: 18, color: AppTheme.muted),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const CapitalHistoryScreen()),
                                );
                              },
                              child: Text('Ver historial completo →',
                                  style: AppFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ]),
              SettingsGroup(
                  title: 'Cobros',
                  subtitle: 'Comprobantes, alertas y recordatorios',
                  children: [
                    _SettingsCard(children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF7935C8),
                        secondary: Icon(Icons.receipt_long_rounded,
                            color: theme.colorScheme.primary),
                        value: _autoShareReceipt,
                        onChanged: (value) {
                          setState(() => _autoShareReceipt = value);
                          LocalCacheService().setAutoShareReceipt(value);
                        },
                        title: Text('Enviar comprobante',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      const _FullBleedDivider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF7935C8),
                        secondary: Icon(Icons.notifications_rounded,
                            color: theme.colorScheme.primary),
                        value: _overdueAlertsEnabled,
                        onChanged: (value) {
                          setState(() => _overdueAlertsEnabled = value);
                          LocalCacheService().setOverdueAlertsEnabled(value);
                        },
                        title: Text('Avisos de atraso',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      const _FullBleedDivider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF7935C8),
                        secondary: Icon(Icons.phone_android_rounded,
                            color: theme.colorScheme.primary),
                        value: _dailyReminderEnabled,
                        onChanged: (value) {
                          setState(() => _dailyReminderEnabled = value);
                          LocalCacheService().setDailyReminderEnabled(value);
                          if (value) {
                            NotificationService().requestPermission();
                            final count = Provider.of<DebtProvider>(context,
                                    listen: false)
                                .todaysCollections
                                .length;
                            NotificationService()
                                .scheduleDailyCollectionsReminder(count);
                          } else {
                            NotificationService().cancelDailyReminder();
                          }
                        },
                        title: Text('Recordatorio diario',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: Text(
                            'Notificación en el celular avisando cuántos clientes tocan cobrar hoy, aunque la app esté cerrada.',
                            style: AppFonts.inter(
                                fontSize: 12, color: Colors.grey[600])),
                      ),
                      const _FullBleedDivider(),
                      Opacity(
                        opacity: _overdueAlertsEnabled ? 1 : 0.4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_rounded,
                                    size: 20, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                Text('Margen de aviso',
                                    style: AppFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _overdueAlertsEnabled &&
                                          _overdueGraceDays > 0
                                      ? () {
                                          setState(() => _overdueGraceDays--);
                                          LocalCacheService()
                                              .setOverdueGraceDays(
                                                  _overdueGraceDays);
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  _overdueGraceDays == 0
                                      ? 'Sin margen'
                                      : '$_overdueGraceDays día(s)',
                                  style: AppFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                IconButton(
                                  onPressed: _overdueAlertsEnabled &&
                                          _overdueGraceDays < 7
                                      ? () {
                                          setState(() => _overdueGraceDays++);
                                          LocalCacheService()
                                              .setOverdueGraceDays(
                                                  _overdueGraceDays);
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ]),
              SettingsGroup(
                  title: 'Seguridad',
                  subtitle: 'PIN y acceso biométrico',
                  children: [
                    _SettingsCard(children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF7935C8),
                        secondary: Icon(Icons.lock_rounded,
                            color: theme.colorScheme.primary),
                        value: _appLockEnabled,
                        onChanged: (value) async {
                          if (value) {
                            _showSetPinDialog();
                          } else {
                            await AppLockService().setEnabled(false);
                            if (!mounted) return;
                            setState(() {
                              _appLockEnabled = false;
                              _appLockUseBiometrics = false;
                            });
                          }
                        },
                        title: Text('Bloqueo con PIN',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (_appLockEnabled && _canUseBiometrics) ...[
                        const _FullBleedDivider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: Colors.white,
                          activeTrackColor: const Color(0xFF7935C8),
                          secondary: Icon(Icons.fingerprint_rounded,
                              color: theme.colorScheme.primary),
                          value: _appLockUseBiometrics,
                          onChanged: (value) async {
                            await AppLockService().setUseBiometrics(value);
                            if (!mounted) return;
                            setState(() => _appLockUseBiometrics = value);
                          },
                          title: Text('Usar también huella / Face ID',
                              style: AppFonts.inter(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(
                            'Además del PIN, para entrar más rápido',
                            style: AppFonts.inter(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ]),
                  ]),
              SettingsGroup(
                  title: 'Respaldo',
                  subtitle: 'Guardar o recuperar tus datos',
                  children: [
                    _SettingsCard(children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.cloud_upload_rounded,
                            color: theme.colorScheme.primary),
                        title: Text('Exportar respaldo',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: Text(
                            'Clientes, solicitudes, créditos, pagos y capital',
                            style: AppFonts.inter(
                                fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2),
                        onTap: () => requireSensitiveActionUnlock(
                          context,
                          reason:
                              'Vas a exportar una copia completa de tus datos.',
                          onUnlocked: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Generando respaldo...')),
                            );
                            final path = await Provider.of<DebtProvider>(
                                    context,
                                    listen: false)
                                .exportBackup();
                            if (!context.mounted) return;
                            if (path != null && path.startsWith('download:')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Descarga iniciada.')));
                              return;
                            }
                            if (path != null) {
                              await SharePlus.instance.share(
                                ShareParams(
                                  files: [XFile(path)],
                                  title: 'Respaldo de Contador Engine',
                                  text: 'Copia de seguridad de tus datos.',
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('No se pudo generar el respaldo.'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const _FullBleedDivider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.cloud_download_rounded,
                            color: theme.colorScheme.primary),
                        title: Text('Importar respaldo',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: Text('Restaurar datos desde archivo',
                            style: AppFonts.inter(
                                fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2),
                        onTap: () => showImportBackupFlow(context),
                      ),
                    ]),
                  ]),
              SettingsGroup(
                  title: 'Actualizaciones',
                  subtitle: 'Versión y nuevas mejoras',
                  children: [
                    _SettingsCard(children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.system_update_rounded,
                            color: theme.colorScheme.primary),
                        title: Text('Buscar actualización',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: Text(
                            _appVersion.isEmpty
                                ? 'Comprueba si hay una versión nueva disponible.'
                                : 'Versión actual $_appVersion. Toca para comprobar si hay una nueva.',
                            style: AppFonts.inter(
                                fontSize: 12, color: Colors.grey[600])),
                        trailing: _checkingUpdate
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.chevron_right_rounded,
                                color: AppTheme.muted),
                        onTap: _checkingUpdate ? null : _checkForUpdateManually,
                      ),
                    ]),
                  ]),
              SettingsGroup(
                  title: 'Cuenta',
                  subtitle: 'Sesión y administración avanzada',
                  children: [
                    _SettingsCard(children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout_rounded,
                            color: Color(0xFFEF4444)),
                        title: Text('Cerrar sesión',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFFEF4444))),
                        onTap: () {
                          final pending =
                              Provider.of<DebtProvider>(context, listen: false)
                                  .pendingCount;
                          requireSensitiveActionUnlock(
                            context,
                            reason: pending > 0
                                ? 'Tienes $pending cambio(s) sin sincronizar. Si cierras sesión ahora, podrías perder acceso a ellos hasta volver a iniciar sesión.'
                                : 'Vas a cerrar tu sesión en este dispositivo.',
                            onUnlocked: () {
                              LocalDatabaseService().signOut();
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                          );
                        },
                      ),
                      const _FullBleedDivider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_forever_rounded,
                            color: Color(0xFFEF4444)),
                        title: Text('Empezar de cero',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: const Color(0xFFEF4444))),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountSettingsScreen()),
                          );
                        },
                      ),
                    ]),
                  ]),
              // ---------------- Sobre la aplicación ----------------
              Center(
                child: Text(
                    _appVersion.isEmpty
                        ? 'Contador Engine'
                        : 'Contador Engine v$_appVersion',
                    style: AppFonts.inter(fontSize: 12, color: AppTheme.muted)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedCurrency extends StatelessWidget {
  final double value;
  final NumberFormat format;
  final TextStyle? style;

  const _AnimatedCurrency(
      {required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.duration(context, 260),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) =>
          Text(format.format(animatedValue), style: style),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-1 - t * 2, 0),
            end: Alignment(1 - t * 2, 0),
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

class _CustomerCardSkeleton extends StatelessWidget {
  const _CustomerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SkeletonBox(
              width: 50, height: 50, borderRadius: BorderRadius.circular(16)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 120, height: 14),
                const SizedBox(height: 8),
                _SkeletonBox(width: 80, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _SkeletonBox(width: 50, height: 14),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? caption;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (caption != null)
                Text(
                  caption!.toUpperCase(),
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppFonts.inter(
              fontSize: 11.5,
              color: AppTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BigNumberCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _BigNumberCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ink,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: AppFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetricCard extends StatelessWidget {
  final String label;
  final String percentText;
  final double progress;
  final Color color;
  final String description;

  const _ProgressMetricCard({
    required this.label,
    required this.percentText,
    required this.progress,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                percentText,
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
