import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/credit_engine.dart';
import '../services/credit_service.dart';
import '../services/local_database_service.dart';
import '../services/totp_service.dart';
import '../utils/app_theme.dart';
import '../utils/document_files.dart';
import '../utils/credit_documents.dart';
import 'home_screen.dart';

class CreditPortalScreen extends StatefulWidget {
  const CreditPortalScreen({super.key});
  @override
  State<CreditPortalScreen> createState() => _CreditPortalScreenState();
}

class _CreditPortalScreenState extends State<CreditPortalScreen> {
  final service = CreditService();
  bool busy = false;
  String filter = 'all';
  String search = '';
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  LocalUser get user => service.db.currentUser!;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> share(String? path) async {
    if (path == null) throw StateError('No se pudo generar el documento.');
    if (path.startsWith('download:')) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  Future<void> create() async {
    final data = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const CreditApplicationForm());
    if (data == null) return;
    await run(() async {
      await service.create(data['purpose'] as String,
          data['terms'] as CreditTerms, data['profile'] as FinancialProfile);
    });
  }

  Future<void> security() async {
    await showDialog<void>(
        context: context, builder: (_) => const AccountSecurityDialog());
  }

  Future<void> audit() async {
    final events = service.db.auditLog();
    await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Bitácora de operaciones'),
                content: SizedBox(
                    width: 720,
                    height: 480,
                    child: ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (_, i) {
                          final e = events[i];
                          return ExpansionTile(
                              title: Text(e['action'].toString()),
                              subtitle: Text(
                                  '${e['date']} · ${e['actor']} · ${e['role'] ?? ''}'),
                              children: [
                                SelectableText(
                                    const JsonEncoder.withIndent('  ')
                                        .convert(e))
                              ]);
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cerrar'))
                ]));
  }

  Future<void> restore() async {
    final bytes = await DocumentFiles.pickJson();
    if (bytes == null) return;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Formato de respaldo inválido.');
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Restaurar respaldo completo'),
                content: const Text(
                    'Reemplazará los datos del negocio. Se conservará una evidencia del estado anterior en la bitácora. Las cuentas no cambian. ¿Continuar?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Restaurar'))
                ]));
    if (confirmed == true) await service.db.restoreBusinessBackup(decoded);
  }

  int tab = 0;

  Widget actionTile(
          IconData icon, String title, String subtitle, VoidCallback? action) =>
      ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Icon(icon, color: AppTheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: action);

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('¿Cerrar sesión?'),
                content:
                    const Text('Tus datos quedarán guardados en este equipo.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Cerrar sesión'))
                ]));
    if (confirmed == true) await run(service.db.signOut);
  }

  @override
  Widget build(BuildContext context) {
    if (service.db.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final apps = service.applications;
    final role = user.role;
    final manager = role == UserRole.manager;
    final account = tab == (manager ? 2 : 1);
    final tools = manager && tab == 1;
    final summary = service.portfolioSummary;
    final visible = apps
        .where((a) =>
            (filter == 'all' || a['status'] == filter) &&
            '${a['purpose']} ${a['applicant']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    final text = Theme.of(context).textTheme;
    final guidance = switch (role) {
      UserRole.client =>
        'Crea tu solicitud y sigue cada etapa hasta la aprobación.',
      UserRole.analyst =>
        'Revisa los ingresos y calcula la capacidad de pago antes de aprobar la etapa.',
      UserRole.compliance =>
        'Revisa los expedientes recibidos y registra el motivo de tu decisión.',
      UserRole.manager =>
        'Decide sobre las solicitudes revisadas y administra los pagos de créditos aprobados.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Contador Engine'), actions: [
        Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
                tooltip: 'Mi cuenta',
                onPressed:
                    busy ? null : () => setState(() => tab = manager ? 2 : 1),
                icon: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE7FA),
                    foregroundColor: AppTheme.primary,
                    child: Icon(Icons.person_outline)))),
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected:
              busy ? null : (value) => setState(() => tab = value),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Solicitudes'),
            if (manager)
              const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Herramientas'),
            const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Mi cuenta'),
          ]),
      body: SafeArea(
          child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(key: ValueKey(tab), slivers: [
            if (busy)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: SliverToBoxAdapter(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(
                          account
                              ? 'Mi cuenta'
                              : tools
                                  ? 'Herramientas'
                                  : role == UserRole.client
                                      ? 'Mis solicitudes'
                                      : 'Solicitudes de crédito',
                          style: text.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          account
                              ? 'Administra tu acceso y seguridad.'
                              : tools
                                  ? 'Control y configuración del negocio.'
                                  : 'Hola, ${user.name}.',
                          style: const TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: 24),
                      if (account) ...[
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Color(0xFFEDE7FA),
                                          child: Icon(Icons.person_outline,
                                              color: AppTheme.primary)),
                                      const SizedBox(height: 16),
                                      Text(user.name, style: text.titleLarge),
                                      const SizedBox(height: 4),
                                      Text(user.email ?? ''),
                                      const SizedBox(height: 12),
                                      Text(role.label,
                                          style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold)),
                                    ]))),
                        const SizedBox(height: 16),
                        Card(
                            child: actionTile(
                                Icons.lock_outline,
                                'Seguridad de cuenta',
                                'Contraseña y autenticación en dos pasos',
                                busy ? null : security)),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                            onPressed: busy ? null : logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Cerrar sesión')),
                        const SizedBox(height: 24),
                        const Text(
                            'Simulación académica. La información se guarda en este equipo; no se realizan operaciones bancarias reales.',
                            style:
                                TextStyle(color: AppTheme.muted, height: 1.5)),
                      ] else if (tools) ...[
                        Card(
                            child: Column(children: [
                          actionTile(
                              Icons.history,
                              'Auditoría',
                              'Consulta quién hizo cada cambio y cuándo.',
                              busy ? null : () => run(audit)),
                          const Divider(height: 1),
                          actionTile(
                              Icons.file_download_outlined,
                              'Respaldar',
                              'Guarda una copia de los datos del negocio.',
                              busy
                                  ? null
                                  : () => run(() async {
                                        await share(await DocumentFiles.save(
                                            'ContadorEngine_respaldo.json',
                                            utf8.encode(jsonEncode(service.db
                                                .exportBusinessBackup()))));
                                      })),
                          const Divider(height: 1),
                          actionTile(
                              Icons.restore,
                              'Restaurar',
                              'Recupera los datos de un respaldo. Requiere confirmación.',
                              busy ? null : () => run(restore)),
                        ])),
                        const SizedBox(height: 16),
                        Card(
                            child: Column(children: [
                          actionTile(
                              Icons.tune,
                              'Reglas de evaluación',
                              'Configura el límite de endeudamiento (DTI).',
                              busy
                                  ? null
                                  : () => run(() async {
                                        final value = await requestText(
                                            context,
                                            'DTI máximo (%)',
                                            'Porcentaje de 1 a 100');
                                        if (value != null) {
                                          await service.configureRules(
                                              double.parse(value.replaceAll(
                                                      ',', '.')) /
                                                  100);
                                        }
                                      })),
                          const Divider(height: 1),
                          actionTile(
                              Icons.inventory_2_outlined,
                              'Cartera anterior',
                              'Consulta los préstamos del módulo histórico.',
                              busy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => const HomeScreen()))),
                        ])),
                      ] else ...[
                        LayoutBuilder(
                            builder: (context, constraints) =>
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  metric(
                                      'Solicitudes',
                                      '${apps.length}',
                                      Icons.folder_outlined,
                                      (constraints.maxWidth - 12) / 2),
                                  metric(
                                      'Saldo pendiente',
                                      'USD ${(summary['balanceCents']! / 100).toStringAsFixed(2)}',
                                      Icons.account_balance_wallet_outlined,
                                      (constraints.maxWidth - 12) / 2),
                                ])),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEDE7FA),
                                borderRadius: BorderRadius.circular(18)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tu siguiente paso',
                                      style: text.titleSmall?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(guidance,
                                      style: const TextStyle(height: 1.5)),
                                  if (role == UserRole.client) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                        onPressed: busy ? null : create,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Nueva solicitud'))
                                  ],
                                ])),
                        if (summary['overdue']! > 0)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                  '${summary['overdue']} créditos tienen cuotas vencidas. Abre el expediente para revisar los pagos.',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 24),
                        TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                                labelText: 'Buscar solicitud',
                                hintText: 'Solicitante o destino del crédito',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) =>
                                setState(() => search = value)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            key: ValueKey(filter),
                            initialValue: filter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Estado',
                                prefixIcon: Icon(Icons.filter_list)),
                            items: [
                              const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Todos los estados')),
                              ...ApplicationStatus.values.map((s) =>
                                  DropdownMenuItem(
                                      value: s.name, child: Text(s.label)))
                            ],
                            onChanged: (value) =>
                                setState(() => filter = value!)),
                        const SizedBox(height: 20),
                        Text(
                            '${visible.length} ${visible.length == 1 ? 'solicitud' : 'solicitudes'}',
                            style: text.titleSmall),
                      ],
                    ]))),
            if (!account && !tools)
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: visible.isEmpty
                      ? SliverToBoxAdapter(
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(children: [
                                    const Icon(Icons.folder_open_rounded,
                                        size: 42, color: AppTheme.muted),
                                    const SizedBox(height: 12),
                                    Text(
                                        apps.isEmpty
                                            ? 'Todo empieza con una solicitud'
                                            : 'Sin coincidencias',
                                        style: text.titleMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                        apps.isEmpty
                                            ? (role == UserRole.client
                                                ? 'Pulsa Nueva solicitud para crear tu primer borrador.'
                                                : 'Aquí aparecerán las solicitudes cuando se registren.')
                                            : 'Prueba con otro nombre o cambia el estado.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: AppTheme.muted,
                                            height: 1.5)),
                                    if (apps.isNotEmpty)
                                      TextButton(
                                          onPressed: () => setState(() {
                                                filter = 'all';
                                                search = '';
                                                searchController.clear();
                                              }),
                                          child: const Text(
                                              'Ver todas las solicitudes')),
                                  ]))))
                      : SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final a = visible[i];
                            final terms = a['terms'] as Map;
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                        onTap: busy
                                            ? null
                                            : () async {
                                                await Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            CreditDetailScreen(
                                                                id: a['id']
                                                                    as String)));
                                                if (mounted) setState(() {});
                                              },
                                        child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CreditStatusBadge(
                                                      status: a['status']
                                                          as String),
                                                  const SizedBox(height: 12),
                                                  Text(a['purpose'] as String,
                                                      style: text.titleMedium
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                  const SizedBox(height: 6),
                                                  Text(a['applicant'] as String,
                                                      style: const TextStyle(
                                                          color:
                                                              AppTheme.muted)),
                                                  const SizedBox(height: 16),
                                                  Wrap(
                                                      spacing: 16,
                                                      runSpacing: 8,
                                                      children: [
                                                        Text(
                                                            'USD ${(terms['principal'] as num).toStringAsFixed(2)}',
                                                            style: text
                                                                .titleMedium),
                                                        Text(
                                                            '${terms['months']} meses · ${terms['method'] == 'french' ? 'Francés' : 'Alemán'}'),
                                                      ]),
                                                  const SizedBox(height: 12),
                                                  const Row(children: [
                                                    Expanded(
                                                        child: Text(
                                                            'Ver solicitud',
                                                            style: TextStyle(
                                                                color: AppTheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold))),
                                                    Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 20,
                                                        color: AppTheme.primary)
                                                  ]),
                                                ])))));
                          })),
          ]),
        ),
      )),
    );
  }

  Widget metric(String label, String value, IconData icon, double width) =>
      SizedBox(
          width: width,
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppTheme.primary, size: 22),
                        const SizedBox(height: 12),
                        Text(value,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: const TextStyle(color: AppTheme.muted)),
                      ]))));
}

class CreditStatusBadge extends StatelessWidget {
  final String status;
  const CreditStatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF176C4A),
      'rejected' => const Color(0xFFB3261E),
      'returned' => const Color(0xFF8A5100),
      _ => AppTheme.primary
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20)),
        child: Text(ApplicationStatus.values.byName(status).label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)));
  }
}

class CreditProgress extends StatelessWidget {
  final String status;
  const CreditProgress({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      'submitted' => 1,
      'compliance' => 2,
      'management' => 3,
      'approved' => 4,
      _ => 0,
    };
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final (index, label) in [
        'Solicitud',
        'Análisis',
        'Cumplimiento',
        'Gerencia',
        'Aprobación'
      ].indexed)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              index < current
                  ? Icons.check_circle
                  : index == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 18,
              color: index <= current ? AppTheme.primary : AppTheme.muted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: index <= current ? AppTheme.primary : AppTheme.muted)),
        ]),
    ]);
  }
}

Future<String?> requestText(
    BuildContext context, String title, String label) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  decoration: InputDecoration(labelText: label),
                  autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialog, controller.text.trim()),
                    child: const Text('Confirmar'))
              ]));
  // El controlador se libera después de que termine la animación del diálogo.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

class CreditDetailScreen extends StatefulWidget {
  final String id;
  const CreditDetailScreen({super.key, required this.id});
  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen> {
  final service = CreditService();
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = service.applications.firstWhere((a) => a['id'] == widget.id);
    final role = service.db.currentUser!.role;
    final status = app['status'];
    final evaluation = app['evaluation'] as Map?;
    final canDecide = (role == UserRole.analyst && status == 'submitted') ||
        (role == UserRole.compliance && status == 'compliance') ||
        (role == UserRole.manager && status == 'management');
    final balances =
        status == 'approved' ? service.balance(app) : <Map<String, dynamic>>[];
    final total =
        balances.fold<int>(0, (sum, r) => sum + (r['remainingCents'] as int));
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de crédito')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (busy) const LinearProgressIndicator(),
                        Text(app['purpose'] as String,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(app['applicant'] as String,
                            style: const TextStyle(color: AppTheme.muted)),
                        const SizedBox(height: 16),
                        CreditStatusBadge(status: status as String),
                        const SizedBox(height: 16),
                        if (!['rejected', 'returned'].contains(status))
                          CreditProgress(status: status),
                        const SizedBox(height: 16),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('¿Qué sigue?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 6),
                                      Text(
                                          switch (status) {
                                            'draft' =>
                                              'Revisa tus datos y pulsa Enviar a análisis. Mientras sea un borrador puedes editarlo.',
                                            'returned' =>
                                              'Revisa el motivo de devolución al final del expediente y corrige la solicitud para enviarla de nuevo.',
                                            'submitted' =>
                                              'El analista debe calcular la capacidad de pago y registrar su decisión.',
                                            'compliance' =>
                                              'Cumplimiento revisará el expediente antes de enviarlo a gerencia.',
                                            'management' =>
                                              'Gerencia debe registrar la decisión final para generar el plan de pagos.',
                                            'approved' =>
                                              'Consulta las cuotas y los pagos registrados. Gerencia puede registrar un nuevo pago.',
                                            _ =>
                                              'Esta solicitud fue rechazada. Consulta el motivo en el historial de decisiones.',
                                          },
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              height: 1.5)),
                                    ]))),
                        const SizedBox(height: 12),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Resumen de la solicitud',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 12),
                                      Text(
                                          'Monto solicitado: USD ${(app['terms'] as Map)['principal']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Plazo: ${(app['terms'] as Map)['months']} meses · Tasa nominal anual: ${(app['terms'] as Map)['annualRate']}%'),
                                      const Divider(height: 28),
                                      Text(
                                          'Ingresos mensuales: USD ${(app['profile'] as Map)['income']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Gastos: USD ${(app['profile'] as Map)['expenses']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Cuotas de otras deudas: USD ${(app['profile'] as Map)['debtPayments']}'),
                                    ]))),
                        const SizedBox(height: 12),
                        if (evaluation != null)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'DTI: ${((evaluation['dti'] as num) * 100).toStringAsFixed(2)}% · Puntaje: ${evaluation['score']}/100'),
                                        Text(
                                            'Disponible tras cuota: USD ${(evaluation['disposableIncome'] as num).toStringAsFixed(2)}'),
                                        Text(evaluation['eligible'] == true
                                            ? 'Recomendación favorable'
                                            : 'Recomendación no favorable'),
                                        Text(
                                            'Reglas v${evaluation['rulesVersion']}: ${evaluation['explanation']}'),
                                      ]))),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (role == UserRole.client &&
                              ['draft', 'returned'].contains(status))
                            OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          final data = await showDialog<
                                                  Map<String, dynamic>>(
                                              context: context,
                                              builder: (_) =>
                                                  CreditApplicationForm(
                                                      application: app));
                                          if (data != null) {
                                            await service.revise(
                                                widget.id,
                                                data['purpose'] as String,
                                                data['terms'] as CreditTerms,
                                                data['profile']
                                                    as FinancialProfile);
                                          }
                                        }),
                                child: const Text('Editar solicitud')),
                          if (role == UserRole.client && status == 'draft')
                            FilledButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                        run(() => service.submit(widget.id)),
                                child: const Text('Enviar a análisis')),
                          if (role == UserRole.analyst && status == 'submitted')
                            FilledButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                        run(() => service.evaluate(widget.id)),
                                child: const Text('Calcular DTI y scoring')),
                          if (canDecide)
                            ...{
                              'advance': 'Aprobar etapa',
                              'return': 'Devolver',
                              'reject': 'Rechazar'
                            }.entries.map((e) => OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          final reason = await requestText(
                                              context,
                                              e.value,
                                              'Motivo obligatorio');
                                          if (reason != null) {
                                            await service.decide(
                                                widget.id, e.key, reason);
                                          }
                                        }),
                                child: Text(e.value))),
                          ...[false, true].map((pdf) => OutlinedButton.icon(
                              icon: const Icon(Icons.download),
                              label:
                                  Text(pdf ? 'Exportar PDF' : 'Exportar JSON'),
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        final path =
                                            await CreditDocuments.export(
                                                service, app,
                                                pdf: pdf);
                                        if (path == null) {
                                          throw StateError(
                                              'No se pudo exportar.');
                                        }
                                        if (!path.startsWith('download:')) {
                                          await SharePlus.instance.share(
                                              ShareParams(
                                                  files: [XFile(path)]));
                                        }
                                      }))),
                        ]),
                        if (status == 'approved') ...[
                          const SizedBox(height: 16),
                          Text(
                              total == 0
                                  ? 'Préstamo saldado'
                                  : 'Saldo contractual: USD ${(total / 100).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge),
                          const Text(
                              'Las cuotas incluyen cargos pactados. Los anticipos adelantan cuotas completas o parciales; esta simulación no recalcula intereses por prepago.'),
                          if (role == UserRole.manager && total > 0)
                            FilledButton.icon(
                                icon: const Icon(Icons.payments),
                                label: const Text('Registrar pago'),
                                onPressed: busy
                                    ? null
                                    : () => run(() async {
                                          final amount = await requestText(
                                              context,
                                              'Registrar pago',
                                              'Monto USD');
                                          if (amount == null) return;
                                          if (!context.mounted) return;
                                          final ref = await requestText(
                                              context,
                                              'Referencia del pago',
                                              'Recibo o referencia única');
                                          if (ref == null) return;
                                          await service.pay(
                                              widget.id,
                                              double.parse(
                                                  amount.replaceAll(',', '.')),
                                              ref);
                                        })),
                          const SizedBox(height: 16),
                          if (MediaQuery.sizeOf(context).width < 650)
                            ...balances.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                    child: ExpansionTile(
                                  title: Text(
                                      'Cuota ${r['number']} · USD ${((r['remainingCents'] as num) / 100).toStringAsFixed(2)}'),
                                  subtitle: Text(
                                      'Vence ${r['due'].toString().substring(0, 10)}'),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    for (final item in {
                                      'principalCents': 'Capital',
                                      'interestCents': 'Interés',
                                      'insuranceCents': 'Seguro',
                                      'feeCents': 'Comisión',
                                      'lateCents': 'Mora'
                                    }.entries)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(children: [
                                            Expanded(child: Text(item.value)),
                                            Text(
                                                'USD ${((r[item.key] as num) / 100).toStringAsFixed(2)}'),
                                          ])),
                                  ],
                                ))))
                          else
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                    columns: [
                                      'Cuota',
                                      'Vence',
                                      'Capital',
                                      'Interés',
                                      'Seguro',
                                      'Comisión',
                                      'Mora',
                                      'Pendiente'
                                    ]
                                        .map((s) => DataColumn(label: Text(s)))
                                        .toList(),
                                    rows: balances
                                        .map((r) => DataRow(cells: [
                                              DataCell(Text('${r['number']}')),
                                              DataCell(Text(r['due']
                                                  .toString()
                                                  .substring(0, 10))),
                                              ...[
                                                'principalCents',
                                                'interestCents',
                                                'insuranceCents',
                                                'feeCents',
                                                'lateCents',
                                                'remainingCents'
                                              ].map((k) => DataCell(Text(
                                                  ((r[k] as num) / 100)
                                                      .toStringAsFixed(2)))),
                                            ]))
                                        .toList())),
                          const SizedBox(height: 16),
                          Text('Historial de pagos',
                              style: Theme.of(context).textTheme.titleLarge),
                          ...service.payments(widget.id).map((p) => ListTile(
                              title: Text(
                                  '${p['reference']} · USD ${((p['amountCents'] as num) / 100).toStringAsFixed(2)}'),
                              subtitle: Text(
                                  '${p['date']} · ${p['voided'] == true ? 'Anulado: ${p['voidReason']}' : 'Registrado'}'),
                              trailing: role == UserRole.manager &&
                                      p['voided'] != true
                                  ? TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => run(() async {
                                                final reason =
                                                    await requestText(
                                                        context,
                                                        'Anular pago',
                                                        'Motivo obligatorio');
                                                if (reason != null) {
                                                  await service.voidPayment(
                                                      p['id'] as String,
                                                      reason);
                                                }
                                              }),
                                      child: const Text('Anular'))
                                  : null)),
                        ],
                        const SizedBox(height: 20),
                        Text('Historial de decisiones',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (((app['decisions'] as List?) ?? []).isEmpty)
                          const Text('Todavía no se han registrado decisiones.',
                              style: TextStyle(color: AppTheme.muted)),
                        ...((app['decisions'] as List?) ?? []).map((d) => ListTile(
                            leading: const Icon(Icons.fact_check),
                            title: Text(
                                '${UserRole.values.byName(d['role'] as String).label} · ${ApplicationStatus.values.byName(d['to'] as String).label}'),
                            subtitle: Text(
                                '${d['reason']}\n${d['date']} · ${d['actor']}'))),
                        const SizedBox(height: 24),
                        SelectableText('Referencia: ${app['id']}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.muted)),
                      ])))),
    );
  }
}

class CreditApplicationForm extends StatefulWidget {
  final Map<String, dynamic>? application;
  const CreditApplicationForm({super.key, this.application});
  @override
  State<CreditApplicationForm> createState() => _CreditApplicationFormState();
}

class _CreditApplicationFormState extends State<CreditApplicationForm> {
  final fields = <String, TextEditingController>{};
  AmortizationMethod method = AmortizationMethod.french;
  String? error;
  static const labels = {
    'purpose': 'Destino del crédito',
    'principal': 'Monto solicitado (USD)',
    'annualRate': 'Tasa nominal anual (%)',
    'months': 'Plazo en meses',
    'income': 'Ingresos mensuales',
    'expenses': 'Gastos mensuales sin deudas',
    'debtPayments': 'Cuotas mensuales de otras deudas',
    'monthlyInsurance': 'Seguro por mes (USD)',
    'openingFee': 'Comisión única (USD)',
    'lateFee': 'Mora única por cuota vencida (USD)'
  };
  @override
  void initState() {
    super.initState();
    final a = widget.application;
    final values = <String, dynamic>{
      'principal': 1000,
      'annualRate': 12,
      'months': 12,
      'monthlyInsurance': 0,
      'openingFee': 0,
      'lateFee': 0,
      if (a != null) ...Map<String, dynamic>.from(a['terms'] as Map),
      if (a != null) ...Map<String, dynamic>.from(a['profile'] as Map),
      if (a != null) 'purpose': a['purpose']
    };
    for (final key in labels.keys) {
      fields[key] = TextEditingController(text: values[key]?.toString() ?? '');
    }
    if (a != null) {
      method = AmortizationMethod.values
          .byName((a['terms'] as Map)['method'] as String);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double number(String key) =>
      double.parse(fields[key]!.text.trim().replaceAll(',', '.'));
  void submit() {
    try {
      final terms = CreditTerms(
          principal: number('principal'),
          annualRate: number('annualRate'),
          months: int.parse(fields['months']!.text.trim()),
          method: method,
          monthlyInsurance: number('monthlyInsurance'),
          openingFee: number('openingFee'),
          lateFee: number('lateFee'));
      final profile = FinancialProfile(
          income: number('income'),
          expenses: number('expenses'),
          debtPayments: number('debtPayments'));
      terms.validate();
      profile.validate();
      if (fields['purpose']!.text.trim().length < 5) {
        throw ArgumentError('Explica el destino del crédito.');
      }
      Navigator.pop(context, {
        'purpose': fields['purpose']!.text.trim(),
        'terms': terms,
        'profile': profile
      });
    } catch (e) {
      setState(() => error = 'Revisa los campos. ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.application == null
              ? 'Nueva solicitud'
              : 'Corregir solicitud'),
          content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Guarda tus datos como borrador. Podrás revisarlos antes de enviarlos a análisis.',
                    style: TextStyle(color: AppTheme.muted, height: 1.5)),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('1. Tu crédito',
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 16),
                DropdownButtonFormField<AmortizationMethod>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Sistema de amortización'),
                    items: AmortizationMethod.values
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m == AmortizationMethod.french
                                ? 'Francés'
                                : 'Alemán')))
                        .toList(),
                    onChanged: (m) => setState(() => method = m!)),
                const SizedBox(height: 8),
                Text(
                    method == AmortizationMethod.french
                        ? 'Cuota base constante durante el plazo.'
                        : 'Capital constante; las cuotas disminuyen.',
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ...['purpose', 'principal', 'annualRate', 'months'].map(field),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('2. Tu capacidad de pago',
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 8),
                const Text(
                    'Indica valores mensuales en USD. Escribe 0 si no tienes gastos o deudas.',
                    style: TextStyle(color: AppTheme.muted)),
                ...['income', 'expenses', 'debtPayments'].map(field),
                const SizedBox(height: 20),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('3. Cargos adicionales'),
                    subtitle: const Text('Opcionales · Inicialmente en cero'),
                    children: [
                      ...['monthlyInsurance', 'openingFee', 'lateFee']
                          .map(field),
                      const SizedBox(height: 12),
                    ]),
                if (error != null)
                  Semantics(
                      liveRegion: true,
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: submit, child: const Text('Guardar borrador'))
          ]);

  Widget field(String key) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: TextField(
          controller: fields[key],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
              label: Text(labels[key]!),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: key == 'purpose'
                  ? 'Ej. Compra de equipo para mi negocio'
                  : '0',
              helperText: key == 'purpose'
                  ? 'Describe para qué necesitas el crédito.'
                  : null),
          keyboardType: key == 'purpose'
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true)));
}

class AccountSecurityDialog extends StatefulWidget {
  const AccountSecurityDialog({super.key});
  @override
  State<AccountSecurityDialog> createState() => _AccountSecurityDialogState();
}

class _AccountSecurityDialogState extends State<AccountSecurityDialog> {
  final old = TextEditingController(),
      next = TextEditingController(),
      code = TextEditingController();
  String? secret, message;
  bool busy = false;
  @override
  void dispose() {
    old.dispose();
    next.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => message = 'Cambio guardado.');
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Seguridad de cuenta'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: old,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Contraseña actual')),
                const SizedBox(height: 18),
                TextField(
                    controller: next,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                        helperText: 'Usa al menos 12 caracteres.')),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() => LocalDatabaseService()
                            .changePassword(old.text, next.text)),
                    child: const Text('Cambiar contraseña')),
                const Divider(height: 32),
                const Text(
                    'Segundo factor con aplicación autenticadora (TOTP). Guarda el secreto en un lugar seguro para recuperar el acceso.'),
                if (secret == null)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => secret = TotpService.secret()),
                      child: const Text('Configurar autenticador')),
                if (secret != null) ...[
                  SelectableText(secret!),
                  TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: secret!)),
                      child: const Text('Copiar secreto')),
                  const Text(
                      'Añade esta clave manualmente al autenticador: TOTP, 6 dígitos, 30 segundos, SHA1.'),
                  TextField(
                      controller: code,
                      decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos'),
                      keyboardType: TextInputType.number),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () => run(() => LocalDatabaseService()
                              .enableTotp(secret!, code.text.trim())),
                      child: const Text('Activar 2FA')),
                ],
                if (message != null) Text(message!),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'))
          ]);
}
