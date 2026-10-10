import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/local_database_service.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'providers/debt_provider.dart';
import 'services/local_cache_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/credit_portal_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'widgets/app_ui.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cache local (offline-first): debe estar listo antes de que el provider
  // intente leer/escribir en él.
  await LocalCacheService().init();
  await NotificationService().init();

  await LocalDatabaseService().init();

  // Set orientation and overlay styles for mobile
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DebtProvider()..fetchAll()),
      ],
      child: const ContadorEngineApp(),
    ),
  );
}

class ContadorEngineApp extends StatefulWidget {
  const ContadorEngineApp({super.key});

  @override
  State<ContadorEngineApp> createState() => _ContadorEngineAppState();
}

class _ContadorEngineAppState extends State<ContadorEngineApp> {
  late final dynamic _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = LocalDatabaseService().authStateChanges.listen((data) {
      if (!mounted) return;
      final session = data;
      final provider = Provider.of<DebtProvider>(context, listen: false);

      if (session != null) {
        provider.fetchAll();
      } else if (session == null) {
        appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        provider.clearData();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Contador Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => HeroMode(
          enabled: !MediaQuery.disableAnimationsOf(context),
          child: WelcomeEntrance(child: child!)),
      home: StreamBuilder<LocalUser?>(
        stream: LocalDatabaseService().authStateChanges,
        initialData: LocalDatabaseService().currentUser,
        builder: (context, snapshot) {
          final session = snapshot.data;
          if (session != null) {
            return AppLockGate(
              key: ValueKey(session.id),
              child: session.role == UserRole.manager
                  ? const HomeScreen()
                  : const CreditPortalScreen(),
            );
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class RotatingLogoScreen extends StatefulWidget {
  const RotatingLogoScreen({super.key});

  @override
  State<RotatingLogoScreen> createState() => _RotatingLogoScreenState();
}

class _RotatingLogoScreenState extends State<RotatingLogoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Image.asset(
            'assets/icons/contador_engine_logo.png',
            width: 100,
            height: 100,
          ),
        ),
      ),
    );
  }
}
