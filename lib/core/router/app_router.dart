import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/employee_dashboard/presentation/screens/employee_dashboard_screen.dart';
import '../../features/employer_dashboard/presentation/screens/employer_dashboard_screen.dart';
import '../../features/tache_jour/presentation/screens/tache_jour_screen.dart';
import '../../features/appartements/presentation/screens/appartements_screen.dart';
import '../../features/planning/presentation/screens/planning_screen.dart';
import '../../features/memo/presentation/screens/memo_screen.dart';
import '../../features/chat_groupe/presentation/screens/chat_groupe_screen.dart';
import '../../features/pdf/presentation/screens/pdf_preview_screen.dart';
import '../../features/statistiques/presentation/screens/statistiques_screen.dart';
import '../../features/employes/presentation/screens/employes_screen.dart';
import '../../features/presences/presentation/screens/absences_screen.dart';
import '../../features/taches_disponibles/presentation/screens/taches_disponibles_screen.dart';
import '../../features/employer_dashboard/presentation/screens/progression_jour_screen.dart';
import '../../features/aire_commune/presentation/screens/aire_commune_screen.dart';
import '../../features/aire_commune/presentation/screens/aire_commune_config_screen.dart';
import '../../features/messages_semaine/presentation/screens/messages_semaine_screen.dart';
import '../../features/residents/presentation/screens/residents_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_accueil_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_demandes_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_profil_screen.dart';
import '../../features/resident_espace/presentation/screens/demandes_residents_responsable_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reception/presentation/screens/reception_en_construction_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/demandes_equipe/presentation/screens/demandes_equipe_responsable_screen.dart';
import '../../features/demandes_equipe/presentation/screens/mes_demandes_equipe_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/splash_screen.dart';

// ── Navigation retour sécurisée ────────────────────────────
/// Revient à l'écran précédent (context.pop) s'il existe une page à
/// dépiler, sinon navigue vers [fallback]. Nécessaire car plusieurs
/// écrans secondaires sont atteints via context.go() (pas push()),
/// qui ne laisse rien à dépiler pour un simple context.pop().
extension GoRouterBackX on BuildContext {
  void backOrHome(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}

// ── Routes ────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/';
  static const String employeeDashboard = '/dashboard';
  static const String employerDashboard = '/employeur';
  static const String tacheJour = '/journee';
  static const String appartements = '/appartements';
  static const String planning = '/planning';
  static const String memo = '/memo';
  static const String chatGroupe = '/chat';
  static const String pdfPreview = '/pdf';
  static const String statistiques = '/statistiques';
  static const String employes = '/employes';

  static const String presences = '/presences';
  static const String tachesDisponibles = '/taches-disponibles';
  static const String progressionJour = '/progression-jour';

  static const String reception = '/reception';

  static const String residentDashboard = '/resident';
  static const String residentDemandes = '/resident/demandes';
  static const String residentProfil = '/resident/profil';

  // Routes privées — à venir
  static const String aireCommune = '/aire-commune';
  static const String messagesSemaine = '/messages-semaine';
  static const String residents = '/residents';
  static const String demandesResidents = '/demandes/residents';
  static const String demandesEquipe = '/demandes/equipe';
  static const String mesDemandesEquipe = '/mes-demandes-equipe';
  static const String profil = '/profil';
  static const String notifications = '/notifications';

  static String loginSlug(String slug) => '/$slug';
}

// ── Routes protégées ──────────────────────────────────────
const _routesProtegees = [
  '/dashboard',
  '/employeur',
  '/journee',
  '/appartements',
  '/planning',
  '/memo',
  '/chat',
  '/pdf',
  '/statistiques',
  '/employes',
  '/presences',
  '/taches-disponibles',
  '/progression-jour',
  '/aire-commune',
  '/messages-semaine',
  '/residents',
  '/demandes',
  '/mes-demandes-equipe',
  '/profil',
  '/notifications',
  '/resident',
  '/reception',
];

// ── Redirection selon le profil d'accès ───────────────────
/// Décide de la redirection d'une navigation selon l'utilisateur connecté.
///
/// Fonction pure (sans GoRouter) : testée directement. Le `switch` sur le
/// profil est EXHAUSTIF, donc un profil ne peut jamais retomber par défaut sur
/// celui d'un autre (c'était le cas de la Réception, traitée en responsable).
@visibleForTesting
String? redirectionSelonAcces({
  required Employee? employee,
  required String location,
}) {
  final isOnSplash = location == AppRoutes.splash;
  final isOnLogin = location == AppRoutes.login;
  final isProtege = _routesProtegees.any((r) => location.startsWith(r));

  // Non authentifié sur route protégée → login
  if (employee == null) {
    return isProtege ? AppRoutes.login : null;
  }

  return switch (employee.profil) {
    // Réception : ACCÈS FERMÉ PAR DÉFAUT. Elle n'a qu'UNE destination, l'écran
    // « vue Réception en construction » (option A) : toute autre page lui est
    // refusée, sans exception (routes protégées, inconnues, sous-routes, et
    // aussi la connexion et le démarrage une fois connectée). Elle n'hérite
    // d'aucun droit du responsable.
    ProfilAcces.reception =>
      location == AppRoutes.reception ? null : AppRoutes.reception,

    // Résident — confiné à /resident/* (donc jamais /reception)
    ProfilAcces.resident => isOnSplash || isOnLogin
        ? AppRoutes.residentDashboard
        : (location.startsWith(AppRoutes.residentDashboard)
            ? null
            : AppRoutes.residentDashboard),

    // Responsable — tableau de bord à la connexion, accès aux routes, sauf
    // l'écran réservé à la Réception
    ProfilAcces.responsable => isOnSplash ||
            isOnLogin ||
            location.startsWith(AppRoutes.reception)
        ? AppRoutes.employerDashboard
        : null,

    // Préposée — tableau de bord à la connexion, jamais la route responsable
    // ni l'écran réservé à la Réception
    ProfilAcces.preposee => isOnSplash ||
            isOnLogin ||
            location.startsWith('/employeur') ||
            location.startsWith(AppRoutes.reception)
        ? AppRoutes.employeeDashboard
        : null,
  };
}

// ── Router provider ───────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    // ── Redirection globale ───────────────────────────────
    redirect: (context, state) => redirectionSelonAcces(
      employee: ref.read(authNotifierProvider).employee,
      location: state.matchedLocation,
    ),

    errorBuilder: (context, state) => const _ErrorScreen(),

    routes: [
      // ── Splash ─────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Login ──────────────────────────────────────────
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),

      // ── Réception (destination temporaire, hors menu) ───
      // Volontairement HORS du ShellRoute : aucun menu, aucune navigation vers
      // les écrans du responsable ou de la préposée.
      GoRoute(
        path: AppRoutes.reception,
        builder: (context, state) => const ReceptionEnConstructionScreen(),
      ),

      // ── Shell — routes protégées ────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          // Dashboard préposée
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const EmployeeDashboardScreen(),
          ),

          // Dashboard responsable
          GoRoute(
            path: '/employeur',
            builder: (context, state) => const EmployerDashboardScreen(),
          ),

          // Journée
          GoRoute(
            path: '/journee',
            builder: (context, state) {
              final date = state.uri.queryParameters['date'];
              return TacheJourScreen(date: date);
            },
          ),

          // Appartements
          GoRoute(
            path: '/appartements',
            builder: (context, state) => const AppartementsScreen(),
          ),

          // Planning
          GoRoute(
            path: '/planning',
            builder: (context, state) {
              final employeeId = state.uri.queryParameters['employeeId'];
              return PlanningScreen(employeeId: employeeId);
            },
          ),

          // Mémo
          GoRoute(
            path: '/memo',
            builder: (context, state) {
              final employeeId = state.uri.queryParameters['employeeId'];
              final date = state.uri.queryParameters['date'];
              return MemoScreen(employeeId: employeeId, date: date);
            },
          ),

          // Chat groupe
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatGroupeScreen(),
          ),

          // PDF
          GoRoute(
            path: '/pdf',
            builder: (context, state) {
              final employeeId = state.uri.queryParameters['employeeId'];
              final numeroSemaine = state.uri.queryParameters['semaine'];
              return PdfPreviewScreen(
                employeeId: employeeId,
                numeroSemaine:
                    numeroSemaine != null ? int.tryParse(numeroSemaine) : null,
              );
            },
          ),

          // Statistiques
          GoRoute(
            path: '/statistiques',
            builder: (context, state) => const StatistiquesScreen(),
          ),

          // Employés
          GoRoute(
            path: '/employes',
            builder: (context, state) => const EmployesScreen(),
          ),

          // Absences (responsable)
          GoRoute(
            path: '/presences',
            builder: (context, state) => const AbsencesScreen(),
          ),

          // Tâches disponibles (préposée)
          GoRoute(
            path: '/taches-disponibles',
            builder: (context, state) => const TachesDisponiblesScreen(),
          ),

          // Progression du jour (responsable)
          GoRoute(
            path: '/progression-jour',
            builder: (context, state) => const ProgressionJourScreen(),
          ),

          // Aires communes (préposées + responsable)
          GoRoute(
            path: '/aire-commune',
            builder: (context, state) => const AireCommuneScreen(),
            routes: [
              GoRoute(
                path: 'config',
                builder: (context, state) => const AireCommuneConfigScreen(),
              ),
            ],
          ),

          // Messages de la semaine (responsable)
          GoRoute(
            path: '/messages-semaine',
            builder: (context, state) => const MessagesSemaineScreen(),
          ),

          GoRoute(
            path: '/profil',
            builder: (context, state) => const ProfileScreen(),
          ),

          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),

          // Résidents (responsable)
          GoRoute(
            path: '/residents',
            builder: (context, state) => const ResidentsScreen(),
          ),

          // Demandes résidents (responsable)
          GoRoute(
            path: '/demandes/residents',
            builder: (context, state) =>
                const DemandesResidentsResponsableScreen(),
          ),

          // Demandes équipe — congé / absence planifiée (responsable)
          GoRoute(
            path: '/demandes/equipe',
            builder: (context, state) =>
                const DemandesEquipeResponsableScreen(),
          ),

          // Mes demandes d'équipe (tout employé)
          GoRoute(
            path: '/mes-demandes-equipe',
            builder: (context, state) => const MesDemandesEquipeScreen(),
          ),

          // ── Espace résident ─────────────────────────────
          GoRoute(
            path: '/resident',
            builder: (context, state) => const ResidentAccueilScreen(),
          ),
          GoRoute(
            path: '/resident/demandes',
            builder: (context, state) => const ResidentDemandesScreen(),
          ),
          GoRoute(
            path: '/resident/profil',
            builder: (context, state) => const ResidentProfilScreen(),
          ),
        ],
      ),

      // ── Slug employé — TOUJOURS EN DERNIER ─────────────
      GoRoute(
        path: '/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug'] ?? '';
          return LoginScreen(slug: slug);
        },
      ),
    ],
  );
});

// ── Écran d'erreur ────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Cette page n\'existe pas.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
