import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/credit_account.dart';
import '../models/credit_engine.dart';
import '../services/credit_service.dart';
import '../services/local_database_service.dart';
import '../utils/app_theme.dart';
import '../utils/document_files.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_search_field.dart';
import '../widgets/role_shell.dart';
import '../widgets/finance_ui.dart';
import 'credit_portal_screen.dart';
import 'home_screen.dart';
import 'todays_collections_screen.dart';

class CreditWorkspace extends StatefulWidget {
  final bool embedded;
  final int initialTab;
  final ValueChanged<int>? onNavigate;
  const CreditWorkspace(
      {super.key, this.embedded = false, this.initialTab = 0, this.onNavigate});
  @override
  State<CreditWorkspace> createState() => _CreditWorkspaceState();
}

class _CreditWorkspaceState extends State<CreditWorkspace> {
  final service = CreditService();
  final search = TextEditingController();
  StreamSubscription<void>? subscription;
  late int tab = widget.initialTab;
  bool busy = false;
  String filter = 'all';
  final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  LocalUser get user => service.db.currentUser!;
  @override
  void initState() {
    super.initState();
    subscription = service.db.businessChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                e.toString().replaceFirst(RegExp(r'^\w+(?: \w+)*: '), ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(int value) {
    if (widget.embedded && widget.onNavigate != null) {
      widget.onNavigate!(value);
    } else {
      setState(() => tab = value);
    }
  }

  Future<void> open(Map<String, dynamic> app) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CreditDetailScreen(id: app['id'] as String)));
    if (mounted) setState(() {});
  }

  Future<void> create() async {
    final data = await Navigator.push<Map<String, dynamic>>(context,
        MaterialPageRoute(builder: (_) => const CreditApplicationForm()));
    if (data == null || !mounted) return;
    await run(() async {
      final id = await service.create(data['purpose'] as String,
          data['terms'] as CreditTerms, data['profile'] as FinancialProfile);
      if (data['send'] == true) {
        try {
          await service.submit(id);
        } catch (_) {
          throw StateError(
              'El borrador quedó guardado. Ábrelo en Mis solicitudes para reintentar el envío.');
        }
      }
      if (mounted) setState(() => tab = 1);
    },
        success: data['send'] == true
            ? 'Solicitud enviada. Puedes consultar su avance.'
            : 'Borrador guardado.');
  }

  List<Map<String, dynamic>> get applications => service.applications
    ..sort((a, b) => (b['createdAt'] ?? b['approvedAt'] ?? '')
        .toString()
        .compareTo((a['createdAt'] ?? a['approvedAt'] ?? '').toString()));
  String get stage => switch (user.role) {
        UserRole.analyst => 'submitted',
        UserRole.compliance => 'compliance',
        UserRole.manager => 'management',
        _ => 'draft'
      };
  Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subtitle,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
          const SizedBox(height: 7),
          Text(title,
              style: const TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1)),
        ])),
        const SizedBox(width: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/icons/contador_engine_icon_source.png',
                width: 44, height: 44, cacheWidth: 88)),
      ]));
  Widget card(Widget child) => FinanceCard(child: child);

  Widget row(Map<String, dynamic> app) {
    final terms = app['terms'] as Map;
    final applicant = app['applicant'] as String;
    return TouchSurface(
        onTap: () => open(app),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                    radius: 23,
                    backgroundColor: AppTheme.neutral,
                    foregroundColor: AppTheme.ink,
                    child: Text(applicant.isEmpty ? '?' : applicant[0],
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          user.role == UserRole.client
                              ? app['purpose'] as String
                              : applicant,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          user.role == UserRole.client
                              ? 'Solicitud de crédito'
                              : app['purpose'] as String,
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 12)),
                    ])),
                const SizedBox(width: 6),
                const IconMedallion(Icons.arrow_outward_rounded, size: 32),
              ]),
              const SizedBox(height: 20),
              Text(money.format(terms['principal']),
                  style: const TextStyle(
                      fontSize: 29,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.9)),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(Icons.schedule_rounded, '${terms['months']} meses'),
                    CreditStatusBadge(status: app['status'] as String),
                  ]),
              if (app['status'] == 'approved') ...[
                const SizedBox(height: 10),
                Text(service.lifecycle(app).label,
                    style:
                        const TextStyle(color: AppTheme.muted, fontSize: 12)),
              ],
            ])));
  }

  Widget _pill(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
          color: AppTheme.neutral, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted))),
      ]));

  Widget _applicationsGrid(List<Map<String, dynamic>> apps) => FinanceGrid(
      minItemWidth: 290, columns: 2, children: apps.map(row).toList());

  void _openPortfolio() => widget.onNavigate != null
      ? widget.onNavigate!(2)
      : Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => const HomeScreen()));

  Widget _quickAction(
          String title, String caption, IconData icon, VoidCallback action,
          {bool compact = false}) =>
      TouchSurface(
          onTap: action,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(children: [
                            IconMedallion(icon),
                            const Spacer(),
                            const Icon(Icons.arrow_outward_rounded,
                                size: 18, color: AppTheme.muted)
                          ]),
                          const SizedBox(height: 16),
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(caption,
                              style: const TextStyle(
                                  color: AppTheme.muted, fontSize: 12)),
                        ])
                  : Row(children: [
                      IconMedallion(icon),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(caption,
                                style: const TextStyle(
                                    color: AppTheme.muted, fontSize: 12)),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          size: 19, color: AppTheme.muted),
                    ])));

  Widget _portfolioSummary(Map<String, dynamic>? featured) {
    final balance =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        IconMedallion(Icons.account_balance_wallet_outlined),
        SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tu cartera',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Disponible para prestar',
              style: TextStyle(color: AppTheme.muted, fontSize: 13)),
        ])),
      ]),
      const SizedBox(height: 14),
      Text(
          money.format(
              PortfolioLedger.availableCash(service.db.readPortfolio())),
          style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -1.2)),
    ]);
    final actions = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
              onPressed: _openPortfolio,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('Abrir cartera')),
          OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const TodaysCollectionsScreen())),
              icon: const Icon(Icons.today_outlined, size: 19),
              label: const Text('Cobros de hoy')),
          if (featured != null)
            TextButton(
                onPressed: () => open(featured),
                child: const Text('Revisar solicitud')),
        ]);
    return FinanceCard(
      key: const ValueKey('home-portfolio-summary'),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 720 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18
              ? Row(children: [
                  Expanded(child: balance),
                  const SizedBox(width: 24),
                  Flexible(
                      child: Align(
                          alignment: Alignment.centerRight, child: actions)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  balance,
                  const SizedBox(height: 18),
                  actions,
                ])),
    );
  }

  Widget _requestSummary(List<Map<String, dynamic>> apps) {
    final inReview = apps
        .where((a) =>
            ['submitted', 'compliance', 'management'].contains(a['status']))
        .length;
    final active = apps
        .where((a) =>
            a['status'] == 'approved' &&
            service.lifecycle(a) == CreditLifecycle.active)
        .length;
    final summary = [
      (Icons.description_outlined, '${apps.length}', 'Solicitudes'),
      (Icons.timelapse_rounded, '$inReview', 'En revisión'),
      (Icons.account_balance_wallet_outlined, '$active', 'Activadas'),
    ];
    return FinanceGrid(
      key: const ValueKey('request-summary'),
      columns: 3,
      minItemWidth: 88,
      children: [
        for (var i = 0; i < summary.length; i++)
          FinanceCard(
              key: ValueKey('request-metric-$i'),
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconMedallion(summary[i].$1, size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(summary[i].$2,
                                  style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700)))),
                    ]),
                    const SizedBox(height: 8),
                    Text(summary[i].$3,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)),
                  ])),
      ],
    );
  }

  Widget _recentApplication(Map<String, dynamic> app) {
    final terms = app['terms'] as Map;
    final applicant = app['applicant'] as String;
    return TouchSurface(
      key: ValueKey('recent-application-${app['id']}'),
      onTap: () => open(app),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.neutral,
                  foregroundColor: AppTheme.primary,
                  child: Text(applicant.isEmpty ? '?' : applicant[0],
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        user.role == UserRole.client
                            ? app['purpose'] as String
                            : applicant,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                        user.role == UserRole.client
                            ? 'Solicitud de crédito'
                            : app['purpose'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)),
                  ])),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_outward_rounded,
                  size: 18, color: AppTheme.primary),
            ]),
            const SizedBox(height: 12),
            Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(money.format(terms['principal']),
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5)),
                  _pill(Icons.schedule_rounded, '${terms['months']} meses'),
                  CreditStatusBadge(status: app['status'] as String),
                ]),
            if (app['status'] == 'approved') ...[
              const SizedBox(height: 8),
              Text(service.lifecycle(app).label,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ],
          ])),
    );
  }

  Widget overview() {
    final apps = applications;
    final client = user.role == UserRole.client;
    final manager = user.role == UserRole.manager;
    final pending = apps.where((a) => a['status'] == stage).toList();
    final featured = client
        ? (apps.isEmpty ? null : apps.first)
        : (pending.isEmpty ? null : pending.first);
    final hero = FinanceCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const IconMedallion(Icons.account_balance_wallet_outlined),
        const SizedBox(width: 12),
        Expanded(
            child: Text(client ? 'Tu próximo paso' : 'Tu bandeja',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14))),
        if (client && featured != null)
          Flexible(
              child: CreditStatusBadge(status: featured['status'] as String)),
      ]),
      const SizedBox(height: 16),
      Text(
          featured != null
              ? featured['purpose'] as String
              : client
                  ? 'Dale forma a tu próximo proyecto.'
                  : 'Decisiones pendientes',
          style: TextStyle(
              fontSize: client && featured == null ? 28 : 14,
              fontWeight: client && featured == null
                  ? FontWeight.w700
                  : FontWeight.w500,
              height: 1.2,
              color: client && featured == null ? AppTheme.ink : AppTheme.muted,
              letterSpacing: client && featured == null ? -.9 : 0)),
      if (featured != null || !client) ...[
        const SizedBox(height: 8),
        Text(
            featured != null
                ? money.format((featured['terms'] as Map)['principal'])
                : '${pending.length}',
            style: const TextStyle(
                fontSize: 42,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.6)),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (client && featured == null)
          _pill(Icons.description_outlined, 'Solicitud en 3 pasos')
        else if (client)
          _pill(Icons.schedule_rounded,
              '${(featured!['terms'] as Map)['months']} meses')
        else
          _pill(Icons.inbox_outlined, '${pending.length} por revisar'),
        if (client && featured != null && featured['status'] == 'approved')
          Text(service.lifecycle(featured).label,
              style: const TextStyle(color: AppTheme.muted)),
      ]),
      const SizedBox(height: 20),
      FilledButton.icon(
          onPressed: busy
              ? null
              : client
                  ? create
                  : featured != null
                      ? () => open(featured)
                      : () => select(1),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          label: Text(client
              ? 'Solicitar préstamo'
              : featured != null
                  ? 'Revisar solicitud'
                  : 'Ver solicitudes')),
      if (client && featured != null)
        TextButton(
            onPressed: () => open(featured),
            child: const Text('Ver mi solicitud')),
    ]));
    return ListView(
        padding: EdgeInsets.fromLTRB(
            22, 24, 22, 24 + MediaQuery.paddingOf(context).bottom),
        key: PageStorageKey('overview-${user.role.name}'),
        children: [
          heading(client ? 'Tu próximo paso.' : 'Tu día, en orden.',
              'Hola, ${user.name}.'),
          Reveal(child: manager ? _portfolioSummary(featured) : hero),
          const SizedBox(height: 8),
          SectionHeading(client ? 'Tus solicitudes' : 'Solicitudes recientes',
              action: TextButton(
                  onPressed: () => select(1), child: const Text('Ver todas'))),
          if (apps.isEmpty)
            _quickAction(
                client ? 'Mis solicitudes' : 'Todo al día',
                client
                    ? 'Aquí podrás seguir su avance'
                    : 'Aún no hay solicitudes registradas',
                Icons.description_outlined,
                () => select(1))
          else
            FinanceGrid(
                minItemWidth: 290,
                columns: 2,
                children: apps.take(3).map(_recentApplication).toList()),
        ]);
  }

  Widget requests() {
    final apps = applications;
    final visible = apps.where((a) {
      final status = a['status'];
      final matches = filter == 'all' ||
          (filter == 'priority'
              ? status == stage
              : filter == 'review'
                  ? ['submitted', 'compliance', 'management'].contains(status)
                  : filter == 'draft'
                      ? ['draft', 'returned'].contains(status)
                      : status == filter);
      return matches &&
          '${a['applicant']} ${a['purpose']}'
              .toLowerCase()
              .contains(search.text.toLowerCase());
    }).toList();
    final filters = user.role == UserRole.client
        ? {'all': 'Todas', 'review': 'En revisión', 'draft': 'Borradores'}
        : {
            'all': 'Todas',
            'priority': 'Para revisar',
            'review': 'En revisión',
            'approved': 'Aprobadas'
          };
    return ListView(
        padding: EdgeInsets.fromLTRB(
            22, 24, 22, 24 + MediaQuery.paddingOf(context).bottom),
        key: PageStorageKey('requests-${user.role.name}'),
        children: [
          heading(
              user.role == UserRole.client ? 'Mis solicitudes' : 'Solicitudes',
              'Cada proyecto tiene su próximo paso.'),
          _requestSummary(apps),
          const SizedBox(height: 16),
          if (user.role == UserRole.client) ...[
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: busy ? null : create,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Solicitar préstamo'))),
            const SizedBox(height: 18)
          ],
          AppSearchField(
              controller: search,
              hint: 'Buscar solicitud',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters.entries
                  .map((e) => ChoiceChip(
                      label: Text(e.value),
                      labelStyle: TextStyle(
                          fontFamily: 'AppRoboto',
                          fontSize: 13,
                          color: filter == e.key
                              ? AppTheme.primary
                              : AppTheme.muted,
                          fontWeight: filter == e.key
                              ? FontWeight.w700
                              : FontWeight.w500),
                      selected: filter == e.key,
                      onSelected: (_) => setState(() => filter = e.key)))
                  .toList()),
          SectionHeading(visible.length == 1
              ? '1 solicitud'
              : '${visible.length} solicitudes'),
          if (visible.isEmpty)
            card(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconMedallion(Icons.inbox_outlined),
              const SizedBox(height: 16),
              const Text('Todo al día',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('No hay solicitudes en esta vista.',
                  style: TextStyle(color: AppTheme.muted)),
              if (filter != 'all' || search.text.isNotEmpty)
                TextButton(
                    onPressed: () => setState(() {
                          filter = 'all';
                          search.clear();
                        }),
                    child: const Text('Ver todas las solicitudes')),
            ]))
          else
            _applicationsGrid(visible),
        ]);
  }

  Future<void> security() => showDialog<void>(
      context: context, builder: (_) => const AccountSecurityDialog());
  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('¿Cerrar sesión?'),
                content: const Text(
                    'Tus datos permanecerán guardados en este equipo.'),
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

  Future<void> share(String? path) async {
    if (path == null) throw StateError('No se pudo generar el documento.');
    if (!path.startsWith('download:')) {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    }
  }

  Future<void> restore() async {
    final bytes = await DocumentFiles.pickJson();
    if (bytes == null) return;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Respaldo inválido.');
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Restaurar respaldo completo'),
                content: const Text(
                    'Reemplazará los datos del negocio de este equipo. Las cuentas y la evidencia en la bitácora se conservan.'),
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

  Future<void> audit() => showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
              title: const Text('Bitácora de operaciones'),
              content: SizedBox(
                  width: 720,
                  height: 480,
                  child: ListView(
                      children: service.db
                          .auditLog()
                          .map((event) =>
                              ExpansionTile(
                                  title: Text(event['action'].toString()),
                                  subtitle: Text(
                                      '${event['date']} · ${event['role']}'),
                                  children: [
                                    SelectableText(
                                        const JsonEncoder.withIndent('  ')
                                            .convert(event))
                                  ]))
                          .toList())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cerrar'))
              ]));
  Widget tool(String label, VoidCallback action, {String? subtitle}) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: busy ? null : action);
  Widget profile() => ListView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          key: const PageStorageKey('credit-profile'),
          children: [
            heading(
                'Perfil', 'Tu acceso y tus preferencias, en un solo lugar.'),
            card(Row(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.neutral,
                  foregroundColor: AppTheme.primary,
                  child: Text(user.name.isEmpty ? '?' : user.name[0])),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(user.email ?? '',
                        style: const TextStyle(color: AppTheme.muted)),
                    Text(user.role.label,
                        style: const TextStyle(color: AppTheme.primary))
                  ]))
            ])),
            const SizedBox(height: 20),
            card(tool('Seguridad de cuenta', security,
                subtitle: 'Contraseña y autenticación en dos pasos')),
            if (user.role == UserRole.manager) ...[
              const SizedBox(height: 12),
              card(tool(
                  'Ajustes del negocio',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const BusinessSettingsScreen())),
                  subtitle:
                      'Capital, cobros, bloqueo, respaldo y actualizaciones')),
              const SizedBox(height: 20),
              SettingsGroup(
                  title: 'Administración avanzada',
                  subtitle: 'Bitácora, respaldo completo y reglas financieras',
                  children: [
                    tool('Auditoría', () => run(audit)),
                    tool(
                        'Respaldar negocio completo',
                        () => run(() async {
                              await share(await DocumentFiles.save(
                                  'ContadorEngine_respaldo_v3.json',
                                  utf8.encode(jsonEncode(
                                      service.db.exportBusinessBackup()))));
                            })),
                    tool('Restaurar negocio completo', () => run(restore)),
                    tool(
                        'Reglas de evaluación',
                        () => run(() async {
                              final current =
                                  ((service.db.readWorkflow()['scoring_rules']
                                          as Map)['maxDti'] as num) *
                                      100;
                              final text = await requestText(
                                  context,
                                  'Umbral DTI · actual ${current.toStringAsFixed(0)}%',
                                  'Nuevo umbral (%)');
                              if (text != null) {
                                await service.configureRules(
                                    double.parse(text.replaceAll(',', '.')) /
                                        100);
                              }
                            })),
                  ]),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
                onPressed: busy ? null : logout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión')),
            const SizedBox(height: 20),
            const Text(
                'Datos guardados en este equipo. Para compartir solicitudes entre dispositivos se necesita activar un servicio de sincronización.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.muted, height: 1.5)),
          ]);
  @override
  Widget build(BuildContext context) {
    if (service.db.currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final pages = [overview(), requests(), profile()];
    final content = Column(children: [
      if (busy) const LinearProgressIndicator(),
      Expanded(child: TabContent(index: tab, children: pages))
    ]);
    if (widget.embedded) return content;
    return RoleShell(
        index: tab,
        selectedIcons: const [
          Icons.home_rounded,
          Icons.description_rounded,
          Icons.person_rounded
        ],
        labels: [
          'Inicio',
          user.role == UserRole.client ? 'Mis solicitudes' : 'Bandeja',
          'Perfil'
        ],
        icons: const [
          Icons.home_outlined,
          Icons.description_outlined,
          Icons.person_outline
        ],
        onSelected: select,
        child: content);
  }
}
