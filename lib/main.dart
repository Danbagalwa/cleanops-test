import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jazz_teasdale/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_widget.dart';

const String _supabaseUrl = 'https://fmicnzmjrwqtgkplsehm.supabase.co';
const String _supabaseAnonKey =
    'sb_publishable_XA3b--cmQ2zTDJfScL4N-A_-a2G2WDN';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureFlutterErrors();

  // Affiche la première frame sans attendre le réseau ni le stockage local.
  runApp(const _BootstrapApp());
}

void _configureFlutterErrors() {
  ErrorWidget.builder = (_) => const Material(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppErrorNotice(
                error: 'Impossible d’afficher cette partie pour le moment. '
                    'Vous pouvez revenir à l’écran précédent et réessayer.',
              ),
            ),
          ),
        ),
      );
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  SharedPreferences? _preferences;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _initializationError = null);

    try {
      final preferencesFuture = SharedPreferences.getInstance();
      await initializeDateFormatting('fr_FR', null);
      final preferences = await preferencesFuture;
      await SupabaseService.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );

      if (!mounted) return;
      setState(() => _preferences = preferences);
    } catch (error) {
      if (!mounted) return;
      setState(() => _initializationError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;

    if (preferences != null) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const JazzTeasdaleApp(),
      );
    }

    return MaterialApp(
      title: 'CleanOps',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _StartupScreen(
        hasError: _initializationError != null,
        onRetry: _initialize,
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.hasError,
    required this.onRetry,
  });

  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.rouge,
              AppColors.rougeFonce,
              AppColors.rougeLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: hasError
                    ? _StartupError(onRetry: onRetry)
                    : const _StartupLoading(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Préparation de votre espace de travail',
      child: Column(
        key: const ValueKey('loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'CLEANOPS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Préparation de votre espace…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 34),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('error'),
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 35,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 42,
            color: AppColors.rouge,
          ),
          const SizedBox(height: 16),
          const Text(
            'La connexion prend plus de temps que prévu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vos données sont en sécurité. Vérifiez votre connexion puis '
            'réessayez.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class JazzTeasdaleApp extends ConsumerWidget {
  const JazzTeasdaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CleanOps',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en'),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1),
          ),
          child: child!,
        );
      },
    );
  }
}
