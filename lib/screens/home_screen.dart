import 'dart:async';
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
import '../utils/shared_styles.dart';

Color _avatarColorFor(String name) => const Color(0xFF7C3AED);

void showAddCustomerDialog(BuildContext context) {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cedulaController = TextEditingController();

  showBlurDialog(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: dialogShape(),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Text('Nuevo cliente',
          style: AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
      content: dialogContent([
        Text(
            'Completa los datos para registrar un nuevo cliente en el sistema.',
            style: AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 20),
        TextField(
          controller: nameController,
          decoration: minimalFieldDecoration(label: 'Nombre completo'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: phoneController,
          decoration: minimalFieldDecoration(
            label: 'Teléfono',
            hint: 'Ej: 61234567',
            helper: 'Se guarda como +507 para enviar por WhatsApp',
            prefixText: '$panamaCountryCode  ',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: cedulaController,
          decoration: minimalFieldDecoration(label: 'Cédula / ID'),
        ),
      ]),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text('Cancelar',
              style: AppFonts.inter(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              Provider.of<DebtProvider>(context, listen: false).addCustomer(
                  nameController.text,
                  normalizePanamaPhone(phoneController.text),
                  cedulaController.text);
              Navigator.pop(context);
            }
          },
          style: solidActionButtonStyle(context),
          child: const Text('Registrar'),
        ),
      ],
    ),
  ).whenComplete(() {
    nameController.dispose();
    phoneController.dispose();
    cedulaController.dispose();
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  /// Busca una versión nueva al entrar al home. Silencioso si ya está al día.
  Future<void> _checkForUpdate() async {
    final release = await UpdateService().checkForUpdate();
    if (release == null || !mounted) return;
    await showUpdateDialog(context, release);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onCategoryTapped(int pageIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = pageIndex;
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _toggleMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _isMenuOpen = !_isMenuOpen);
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
    return PopScope(
      canPop: !_isMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMenuOpen) {
          _toggleMenu();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: 4,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _DashboardView(onCategoryTap: _onCategoryTapped);
                  case 1:
                    return const _HistoryView();
                  case 2:
                    return const _StatisticsView();
                  case 3:
                    return const _SettingsView();
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),

            // Flat overlay is much cheaper than runtime blur on modest phones.
            if (_isMenuOpen)
              GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black.withAlpha(38),
                ),
              ),

            // FAB Menu Options (Dynamic "Rain of Ideas" Style)
            _FloatingMenuOption(
              isOpen: _isMenuOpen,
              index: 0,
              icon: Icons.person_add_rounded,
              label: 'CLIENTE',
              color: const Color(0xFF7C3AED),
              offsetX: -95,
              offsetY: 24,
              onTap: () {
                _toggleMenu();
                showAddCustomerDialog(context);
              },
            ),
            _FloatingMenuOption(
              isOpen: _isMenuOpen,
              index: 1,
              icon: Icons.file_download_rounded,
              label: 'EXPORTAR',
              color: const Color(0xFF6D28D9),
              offsetX: 0,
              offsetY: 96,
              onTap: () {
                _toggleMenu();
                _showExportFormatSheet(context);
              },
            ),
            _FloatingMenuOption(
              isOpen: _isMenuOpen,
              index: 2,
              icon: Icons.add_chart_rounded,
              label: 'PRÉSTAMO',
              color: const Color(0xFF8B5CF6),
              offsetX: 95,
              offsetY: 24,
              onTap: () {
                _toggleMenu();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddLoanScreen()),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: _AnimatedSpotlightNavBar(
          currentIndex: _currentIndex,
          isMenuOpen: _isMenuOpen,
          onTap: (index) {
            HapticFeedback.selectionClick();
            if (_isMenuOpen) _toggleMenu();
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
            );
          },
          onAddPressed: _toggleMenu,
        ),
      ),
    );
  }
}

class _FloatingMenuOption extends StatelessWidget {
  final bool isOpen;
  final int index;
  final IconData icon;
  final String label;
  final Color color;
  final double offsetX;
  final double offsetY;
  final VoidCallback onTap;

  const _FloatingMenuOption({
    required this.isOpen,
    required this.index,
    required this.icon,
    required this.label,
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double elementWidth = 120; // Expected width of the option column
    // Staggered but smooth: each option settles slightly after the previous one.
    final duration = Duration(milliseconds: 260 + (index * 70));

    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeOutCubic,
      bottom: isOpen ? (80 + offsetY) : 30,
      left: (screenWidth / 2) + offsetX - (elementWidth / 2),
      width: elementWidth,
      child: IgnorePointer(
        ignoring: !isOpen,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutCubic,
          scale: isOpen ? 1 : 0.6,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOut,
            opacity: isOpen ? 1 : 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(51),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(13), blurRadius: 10)
                      ],
                    ),
                    child: Text(
                      label,
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  final Function(int) onCategoryTap;
  const _DashboardView({required this.onCategoryTap});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
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
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final theme = Theme.of(context);

    // Dynamic Greeting Setup
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Buenos días';
    } else if (hour >= 12 && hour < 19) {
      greeting = 'Buenas tardes';
    } else if (hour >= 19 && hour < 24) {
      greeting = 'Buenas noches';
    } else {
      greeting = 'Buenas noches';
    }

    // Attempt to extract User Name
    final user = LocalDatabaseService().currentUser;
    String userName = 'Contador';
    if (user != null) {
      final metaName = user.userMetadata?['name'];
      if (metaName != null && metaName.toString().trim().isNotEmpty) {
        userName = metaName.toString();
      } else if (user.email != null) {
        userName = user.email!.split('@').first;
        if (userName.isNotEmpty) {
          userName =
              userName[0].toUpperCase() + userName.substring(1).toLowerCase();
        }
      }
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 18,
            left: 28,
            right: 28,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
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
                        Text(
                          'Hola, $userName',
                          style: AppFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          greeting,
                          style: AppFonts.inter(
                            color: Colors.white.withAlpha(179),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer<DebtProvider>(
                    builder: (context, provider, child) {
                      final overdueCount = provider.overdueCount;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => _showNotificationsSheet(context),
                              icon: Icon(
                                overdueCount > 0
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            if (overdueCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    overdueCount > 9 ? '9+' : '$overdueCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      () => Provider.of<DebtProvider>(context, listen: false)
                          .fetchCustomersNextPage(
                              reset: true, search: _searchQuery),
                    );
                  },
                  style: AppFonts.inter(
                      color: theme.colorScheme.primary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente o cédula...',
                    hintStyle:
                        AppFonts.inter(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: theme.colorScheme.primary, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: () =>
                Provider.of<DebtProvider>(context, listen: false).fetchAll(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Consumer<DebtProvider>(
                    builder: (context, provider, child) {
                      if (!provider.isOffline && provider.pendingCount == 0) {
                        return const SizedBox.shrink();
                      }
                      final color = provider.isOffline
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981);
                      final text = provider.isOffline
                          ? (provider.pendingCount > 0
                              ? 'Sin conexión — ${provider.pendingCount} cambio(s) pendientes de sincronizar'
                              : 'Sin conexión — los cambios se guardan en el celular')
                          : 'Sincronizando ${provider.pendingCount} cambio(s) pendientes...';
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: color.withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withAlpha(77)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                provider.isOffline
                                    ? Icons.cloud_off_rounded
                                    : Icons.sync_rounded,
                                color: color,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  text,
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Consumer<DebtProvider>(
                      builder: (context, provider, child) {
                        final currencyFormat = NumberFormat.currency(
                            symbol: '\$', decimalDigits: 2);
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withAlpha(20),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 24),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: -95,
                                    right: -95,
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.colorScheme.primary
                                            .withAlpha(10),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      children: [
                                        Text(
                                          'Disponible',
                                          style: AppFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[500],
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _AnimatedCurrency(
                                          value: provider.moneyInHand,
                                          format: currencyFormat,
                                          style: AppFonts.inter(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _CountPill(
                                              icon: Icons.people_alt_rounded,
                                              label:
                                                  '${provider.customers.length} Clientes',
                                              background: theme
                                                  .colorScheme.primary
                                                  .withAlpha(26),
                                              foreground:
                                                  theme.colorScheme.primary,
                                            ),
                                            _CountPill(
                                              icon: Icons.description_rounded,
                                              label:
                                                  '${provider.allLoans.length} Préstamos',
                                              background: Colors.grey[200]!,
                                              foreground:
                                                  const Color(0xFF475569),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Consumer<DebtProvider>(
                            builder: (context, provider, child) {
                              return _QuickActionCard(
                                icon: Icons.event_available_rounded,
                                color: const Color(0xFF7C3AED),
                                label: 'Cobros de hoy',
                                badgeCount: provider.todaysCollections.length,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const TodaysCollectionsScreen()),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.fact_check_rounded,
                            color: const Color(0xFF64748B),
                            label: 'Cierre del día',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DailyClosingScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mis Clientes',
                            style: AppFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () {
                            final provider = Provider.of<DebtProvider>(context,
                                listen: false);
                            if (provider.hasMoreCustomers) {
                              provider.fetchCustomersNextPage(
                                  search: _searchQuery);
                            }
                          },
                          child: Text('Ver todos',
                              style: AppFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                Consumer<DebtProvider>(
                  builder: (context, provider, child) {
                    final customers = [...provider.paginatedCustomers]
                      ..sort((a, b) {
                        final aOwes = provider
                            .getLoansByCustomer(a.id!)
                            .any((l) => provider.currentDebt(l) > 0);
                        final bOwes = provider
                            .getLoansByCustomer(b.id!)
                            .any((l) => provider.currentDebt(l) > 0);
                        if (aOwes == bOwes) return 0;
                        return aOwes ? -1 : 1;
                      });

                    if (customers.isEmpty && provider.isLoading) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverToBoxAdapter(
                          child: _Shimmer(
                            child: Column(
                              children: List.generate(
                                  3, (_) => const _CustomerCardSkeleton()),
                            ),
                          ),
                        ),
                      );
                    }

                    if (customers.isEmpty && !provider.isLoading) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 40),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.primary.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.people_outline_rounded,
                                    size: 40, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 16),
                              Text('Aún no tienes clientes',
                                  style: AppFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(
                                'Toca el "+" de abajo para registrar tu primer cliente y su préstamo.',
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final customer = customers[index];
                            final loans =
                                provider.getLoansByCustomer(customer.id!);
                            double totalDebt = 0;
                            for (var l in loans) {
                              // Un préstamo saldado (o pagado de más) no debe
                              // restar del total pendiente de otros préstamos
                              // activos del mismo cliente.
                              final debt = provider.currentDebt(l);
                              if (debt > 0) totalDebt += debt;
                            }
                            final isOverdue = provider.overdueLoans
                                .any((l) => l.customerId == customer.id);
                            final isPaidOff =
                                loans.isNotEmpty && totalDebt <= 0;

                            return _FadeSlideIn(
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.black.withAlpha(15)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withAlpha(13),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8))
                                  ],
                                ),
                                child: Material(
                                  color: isPaidOff
                                      ? Colors.grey[200]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  CustomerDetailScreen(
                                                      customer: customer)));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                    color: _avatarColorFor(
                                                            customer.name)
                                                        .withAlpha(26),
                                                    shape: BoxShape.circle),
                                                child: Center(
                                                    child: Text(
                                                        customer.name[0]
                                                            .toUpperCase(),
                                                        style: AppFonts.inter(
                                                            color:
                                                                _avatarColorFor(
                                                                    customer
                                                                        .name),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18))),
                                              ),
                                              if (isOverdue)
                                                Positioned(
                                                  top: -3,
                                                  right: -3,
                                                  child: Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFEF4444),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.white,
                                                          width: 2),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(customer.name,
                                                    style: AppFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                        color: const Color(
                                                            0xFF1E293B))),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    if (customer.cedula !=
                                                            null &&
                                                        customer
                                                            .cedula!.isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .primary
                                                              .withAlpha(20),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                            customer.cedula!,
                                                            style: AppFonts.inter(
                                                                fontSize: 11,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                      ),
                                                    Text(
                                                        '${loans.length} transacciones',
                                                        style: AppFonts.inter(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.grey)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(currencyFormat.format(totalDebt),
                                              style: AppFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPaidOff
                                                      ? Colors.grey[400]
                                                      : theme.colorScheme
                                                          .primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: customers.length,
                        ),
                      ),
                    );
                  },
                ),
                // Pagination Button
                Consumer<DebtProvider>(
                  builder: (context, provider, child) {
                    if (!provider.hasMoreCustomers ||
                        provider.paginatedCustomers.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: TextButton.icon(
                          onPressed: provider.isFetchingMoreCustomers
                              ? null
                              : () {
                                  provider.fetchCustomersNextPage(
                                      search: _searchQuery);
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.white,
                            foregroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color:
                                      theme.colorScheme.primary.withAlpha(77)),
                            ),
                          ),
                          icon: provider.isFetchingMoreCustomers
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary))
                              : Icon(Icons.expand_more_rounded,
                                  size: 18, color: theme.colorScheme.primary),
                          label: Text(
                            provider.isFetchingMoreCustomers
                                ? 'Cargando...'
                                : 'Ver más clientes',
                            style: AppFonts.inter(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Consumer<DebtProvider>(
                  builder: (context, provider, _) {
                    if (provider.customers.length >= 5) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _AddCustomerCard(
                            onTap: () => showAddCustomerDialog(context)),
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: color.withAlpha(26),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

// _CardOverlay removed as per request.

class _AnimatedSpotlightNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isMenuOpen;
  final Function(int) onTap;
  final VoidCallback onAddPressed;

  const _AnimatedSpotlightNavBar({
    required this.currentIndex,
    required this.isMenuOpen,
    required this.onTap,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = [
      Icons.home_filled,
      Icons.receipt_long_rounded,
      Icons.auto_graph_rounded,
      Icons.settings_rounded,
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 80 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 30,
              offset: const Offset(0, -10))
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            left: _calculateIndicatorLeftPosition(context),
            top: 15,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(31),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(26),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildTab(0, tabs[0], 'Inicio', context)),
                Expanded(child: _buildTab(1, tabs[1], 'Cobros', context)),

                // Central FAB
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: onAddPressed,
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isMenuOpen ? 0.125 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMenuOpen
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: (isMenuOpen
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.secondary)
                                    .withAlpha(89),
                                blurRadius: 12,
                                offset: const Offset(0, 5))
                          ],
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),

                Expanded(child: _buildTab(2, tabs[2], 'Análisis', context)),
                Expanded(child: _buildTab(3, tabs[3], 'Config', context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      int index, IconData icon, String label, BuildContext context) {
    bool isActive = currentIndex == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isActive ? 1.1 : 1.0,
                child: Icon(
                  icon,
                  color:
                      isActive ? theme.colorScheme.primary : Colors.grey[400],
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppFonts.inter(
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isActive ? theme.colorScheme.primary : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateIndicatorLeftPosition(BuildContext context) {
    double totalWidth = MediaQuery.of(context).size.width;
    double tabWidth = (totalWidth - 16 - 70) / 4;
    double indicatorWidth = 55;

    double centerX = 0;
    switch (currentIndex) {
      case 0:
        centerX = 8 + (tabWidth / 2);
        break;
      case 1:
        centerX = 8 + tabWidth + (tabWidth / 2);
        break;
      case 2:
        centerX = 8 + (tabWidth * 2) + 70 + (tabWidth / 2);
        break;
      case 3:
        centerX = 8 + (tabWidth * 3) + 70 + (tabWidth / 2);
        break;
    }

    return centerX - (indicatorWidth / 2);
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
    final theme = Theme.of(context);

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
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial de Cobros',
                style: AppFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppFonts.inter(
                      color: theme.colorScheme.primary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente...',
                    hintStyle:
                        AppFonts.inter(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: theme.colorScheme.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
                              fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 15,
                            offset: const Offset(0, 8)),
                      ],
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
                                            color: const Color(0xFF1E293B))),
                                    const SizedBox(height: 4),
                                    Text(
                                      receiptCount == 0
                                          ? 'Sin comprobantes aún'
                                          : '$receiptCount comprobante${receiptCount == 1 ? '' : 's'}',
                                      style: AppFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey[400]),
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
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 20,
            left: 28,
            right: 28,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Análisis de Datos',
                  style: AppFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<DebtProvider>(
            builder: (context, provider, child) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3310B981),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -18,
                            right: -10,
                            child: Icon(
                              Icons.trending_up_rounded,
                              size: 90,
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(38),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.payments_rounded,
                                        color: Colors.white, size: 13),
                                    const SizedBox(width: 6),
                                    Text(
                                      'TUS GANANCIAS',
                                      style: AppFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                currencyFormat.format(provider.realizedProfit),
                                style: AppFonts.inter(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ganancia neta ya cobrada, descontando el capital recuperado.',
                                style: AppFonts.inter(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Métricas clave',
                      style: AppFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Resumen financiero detallado',
                    style:
                        AppFonts.inter(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Capital total',
                          value: currencyFormat.format(provider.initialCapital),
                          color: const Color(0xFF6D28D9),
                          icon: Icons.account_balance_rounded,
                          caption: 'Total',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Capital disponible',
                          value: currencyFormat.format(provider.moneyInHand),
                          color: const Color(0xFF10B981),
                          icon: Icons.account_balance_wallet_rounded,
                          caption: 'Disponible',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Capital prestado',
                          value: currencyFormat.format(provider.activeCapital),
                          color: const Color(0xFF7C3AED),
                          icon: Icons.monetization_on_rounded,
                          caption: 'En préstamo',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Ganancia cobrada',
                          value: currencyFormat.format(provider.realizedProfit),
                          color: const Color(0xFF10B981),
                          icon: Icons.savings_rounded,
                          caption: 'Cobrado',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 380,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(5), blurRadius: 20)
                      ],
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
                              ? _buildYearlyChart(provider.allPayments, context,
                                  currency: currencyFormat)
                              : _buildDailyChart(
                                  provider.allPayments,
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
                        '${provider.allLoans.where((l) => provider.currentDebt(l) <= 0).length}',
                    label: 'Préstamos liquidados',
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final liquidados = provider.allLoans
                        .where((l) => provider.currentDebt(l) <= 0)
                        .length;
                    final total = provider.allLoans.length;
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
                        color: Colors.grey[500]),
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

class _SettingsSectionLabel extends StatelessWidget {
  final String text;
  const _SettingsSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: sectionCaptionStyle());
  }
}

/// Divisor que ignora el padding horizontal del [_SettingsCard] para llegar
/// de borde a borde de la tarjeta, igual que las listas agrupadas nativas.
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
  Widget build(BuildContext context) {
    const radius = 16.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withAlpha(15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }
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
        backgroundColor: const Color(0xFF7C3AED),
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
                    style:
                        AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
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
                style: AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
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
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 20,
            left: 28,
            right: 28,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Configuración',
                style: AppFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ---------------- Negocio ----------------
              const _SettingsSectionLabel('Negocio'),
              const SizedBox(height: 8),
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
                                      size: 36, color: Colors.grey[500])
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
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
                  style: AppFonts.inter(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saveBusinessName,
                    child: Text('Guardar',
                        style: AppFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),

              const SizedBox(height: 28),

              // ---------------- Capital ----------------
              const _SettingsSectionLabel('Capital'),
              const SizedBox(height: 8),
              Consumer<DebtProvider>(
                builder: (context, provider, child) {
                  final currency =
                      NumberFormat.currency(symbol: '\$ ', decimalDigits: 2);
                  final preview = provider.capitalHistory.take(3).toList();

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
                              color: theme.colorScheme.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text('Agregar',
                                    style: AppFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: theme.colorScheme.primary)),
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
                          color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    if (preview.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Todavía no hay movimientos de capital.',
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
                            color: theme.colorScheme.primary.withAlpha(13),
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
                                            : Icons.arrow_downward_rounded,
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
                                            (entry.note ?? 'Sin descripción')
                                                .toUpperCase(),
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[600],
                                                letterSpacing: 0.3),
                                          ),
                                          Text(
                                            DateFormat('dd MMM, yyyy')
                                                .format(entry.createdAt),
                                            style: AppFonts.inter(
                                                fontSize: 10,
                                                color: Colors.grey[400]),
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
                                        size: 18, color: Colors.grey[400]),
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
                                builder: (_) => const CapitalHistoryScreen()),
                          );
                        },
                        child: Text('Ver historial completo →',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 28),

              // ---------------- Cobros ----------------
              const _SettingsSectionLabel('Cobros'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF7C3AED),
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
                  activeTrackColor: const Color(0xFF7C3AED),
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
                  activeTrackColor: const Color(0xFF7C3AED),
                  secondary: Icon(Icons.phone_android_rounded,
                      color: theme.colorScheme.primary),
                  value: _dailyReminderEnabled,
                  onChanged: (value) {
                    setState(() => _dailyReminderEnabled = value);
                    LocalCacheService().setDailyReminderEnabled(value);
                    if (value) {
                      NotificationService().requestPermission();
                      final count =
                          Provider.of<DebtProvider>(context, listen: false)
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
                                  fontWeight: FontWeight.w600, fontSize: 15)),
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
                                        .setOverdueGraceDays(_overdueGraceDays);
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            _overdueGraceDays == 0
                                ? 'Sin margen'
                                : '$_overdueGraceDays día(s)',
                            style: AppFonts.inter(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          IconButton(
                            onPressed: _overdueAlertsEnabled &&
                                    _overdueGraceDays < 7
                                ? () {
                                    setState(() => _overdueGraceDays++);
                                    LocalCacheService()
                                        .setOverdueGraceDays(_overdueGraceDays);
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

              const SizedBox(height: 28),

              // ---------------- Seguridad ----------------
              const _SettingsSectionLabel('Seguridad'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF7C3AED),
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
                    activeTrackColor: const Color(0xFF7C3AED),
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
                      style:
                          AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ]),

              const SizedBox(height: 28),

              // ---------------- Cuenta ----------------
              const _SettingsSectionLabel('Respaldo'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_upload_rounded,
                      color: theme.colorScheme.primary),
                  title: Text('Exportar respaldo',
                      style: AppFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text('Guardar copia de seguridad en JSON',
                      style:
                          AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2),
                  onTap: () => requireSensitiveActionUnlock(
                    context,
                    reason: 'Vas a exportar una copia completa de tus datos.',
                    onUnlocked: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Generando respaldo...')),
                      );
                      final path = await Provider.of<DebtProvider>(context,
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
                            content: Text('No se pudo generar el respaldo.'),
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
                      style:
                          AppFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2),
                  onTap: () => showImportBackupFlow(context),
                ),
              ]),

              const SizedBox(height: 28),

              // ---------------- Actualizaciones ----------------
              const _SettingsSectionLabel('Actualizaciones'),
              const SizedBox(height: 8),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.chevron_right_rounded,
                          color: Colors.grey[400]),
                  onTap: _checkingUpdate ? null : _checkForUpdateManually,
                ),
              ]),

              const SizedBox(height: 28),

              const _SettingsSectionLabel('Cuenta'),
              const SizedBox(height: 8),
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

              const SizedBox(height: 28),

              // ---------------- Sobre la aplicación ----------------
              Center(
                child: Text(
                    _appVersion.isEmpty
                        ? 'Contador Engine'
                        : 'Contador Engine v$_appVersion',
                    style:
                        AppFonts.inter(fontSize: 12, color: Colors.grey[500])),
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
      duration: const Duration(milliseconds: 600),
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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
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

class _FadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curved);

    // Staggered by list position, capped so long lists don't feel sluggish.
    final delay = Duration(milliseconds: 25 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _AddCustomerCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withAlpha(10),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: primary.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withAlpha(60), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primary.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar cliente',
                      style: AppFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registra un nuevo cliente',
                      style: AppFonts.inter(
                          fontSize: 12, color: primary.withAlpha(140)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline_rounded,
                  color: primary.withAlpha(120), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _CountPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int? badgeCount;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.label,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withAlpha(15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeCount! > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
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
                    color: Colors.grey[400],
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
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
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
                    color: const Color(0xFF1E293B),
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
                    color: Colors.grey[500],
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
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
                  color: Colors.grey[500],
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
