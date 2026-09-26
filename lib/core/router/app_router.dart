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
import '../../features/resident_espace/presentation/screens/resident_calendrier_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_menage_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_demandes_screen.dart';
import '../../features/resident_espace/presentation/screens/resident_profil_screen.dart';
import '../../features/resident_espace/presentation/screens/demandes_residents_responsable_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reception/presentation/reception_sections.dart';
import '../../features/reception/presentation/screens/reception_dashboard_screen.dart';
import '../../features/reception/presentation/screens/reception_a_aviser_screen.dart';
import '../../features/reception/presentation/screens/reception_equipe_screen.dart';
import '../../features/reception/presentation/screens/reception_fiche_screen.dart';
import '../../features/reception/presentation/screens/reception_messages_screen.dart';
import '../../features/reception/presentation/screens/reception_pin_screen.dart';
import '../../features/reception/presentation/screens/reception_residents_screen.dart';
import '../../features/reception/presentation/screens/reception_section_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/demandes_equipe/presentation/screens/demandes_equipe_responsable_screen.dart';
import '../../features/demandes_equipe/presentation/screens/mes_demandes_equipe_screen.dart';
import '../../features/demandes_equipe/presentation/screens/partage_demande_screen.dart';
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

/// Accueil vers lequel revenir depuis un écran partagé (profil, notifications),
/// selon le profil d'accès.
///
/// `switch` exhaustif : un nouveau profil oblige à choisir sa destination, et la
/// Réception ne retombe jamais sur l'accueil d'un autre profil (elle n'y a pas
/// accès).
String accueilDe(Employee employee) => switch (employee.profil) {
      ProfilAcces.reception => receptionAccueilRoute,
      ProfilAcces.responsable => AppRoutes.employerDashboard,
      ProfilAcces.preposee => AppRoutes.employeeDashboard,
      ProfilAcces.resident => AppRoutes.residentDashboard,
    };

/// « Mon profil » du profil d'accès (la Réception a le sien, dans son périmètre).
String profilDe(Employee employee) => switch (employee.profil) {
      ProfilAcces.reception => receptionProfilRoute,
      ProfilAcces.resident => AppRoutes.residentProfil,
      ProfilAcces.responsable || ProfilAcces.preposee => AppRoutes.profil,
    };

/// Écran des notifications du profil d'accès ; `null` pour le résident, qui
/// n'en a pas (ses réponses arrivent dans « Mes demandes »).
String? notificationsDe(Employee employee) => switch (employee.profil) {
      ProfilAcces.reception => receptionNotificationsRoute,
      ProfilAcces.resident => null,
      ProfilAcces.responsable ||
      ProfilAcces.preposee =>
        AppRoutes.notifications,
    };

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
  static const String residentCalendrier = '/resident/calendrier';

  /// Détail d'une date du calendrier du résident.
  static String residentMenage(DateTime date) =>
      '$residentCalendrier/${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // Routes privées — à venir
  static const String aireCommune = '/aire-commune';
  static const String messagesSemaine = '/messages-semaine';
  static const String residents = '/residents';
  static const String demandesResidents = '/demandes/residents';

  /// Valeur du paramètre `onglet` qui ouvre « Messages de la réception ».
  static const String ongletMessagesReception = 'messages';

  /// Demandes résidents, directement sur l'onglet « Messages de la réception ».
  static const String demandesResidentsMessages =
      '$demandesResidents?onglet=$ongletMessagesReception';
  static const String demandesEquipe = '/demandes/equipe';
  static const String mesDemandesEquipe = '/mes-demandes-equipe';
  static const String profil = '/profil';
  static const String notifications = '/notifications';

  static String loginSlug(String slug) => '/$slug';

  /// Page publique d'un lien de partage de demande : /partage/{jeton}.
  static const String partage = '/partage';
}

// ── Lien d'ouverture (lien partagé, page rechargée…) ──────
String? _lienDemarrage;

/// Mémorise l'adresse demandée à l'ouverture de l'app. À appeler dans
/// `main()` AVANT tout affichage : l'écran provisoire de démarrage remplace
/// ensuite l'adresse du navigateur par « / », que le routeur lirait à tort.
void memoriserLienDemarrage(String route) {
  var lien = routeDepuisLien(route) ?? '';
  if (lien.isEmpty || lien == '/' || lien == AppRoutes.splash) {
    // Web : l'adresse est parfois seulement dans le fragment (#/…).
    final fragment = Uri.base.fragment;
    lien = fragment.startsWith('/') ? fragment : '';
  }
  _lienDemarrage =
      lien.isEmpty || lien == '/' || lien == AppRoutes.splash ? null : lien;
}

/// Route de l'app contenue dans un lien reçu : « /#/partage/x » (lien web
/// ouvert par Android), « https://…/#/partage/x », « cleanops://app/partage/x »
/// ou simplement « /partage/x ». `null` si rien d'exploitable.
String? routeDepuisLien(String lien) {
  final uri = Uri.tryParse(lien.trim());
  if (uri == null) return null;
  if (uri.fragment.startsWith('/')) return uri.fragment;
  final chemin = sansDossierWeb(uri.path.isEmpty ? '/' : uri.path);
  return uri.hasQuery ? '$chemin?${uri.query}' : chemin;
}

/// Dossier de l'app web sur GitHub Pages (nom du dépôt, voir
/// .github/workflows/deploy-pages.yml et AndroidManifest.xml).
const kDossierAppWeb = '/cleanops-test';

/// Retire le dossier de l'app web d'un chemin reçu par l'app mobile
/// (« /cleanops-test/ » → « / ») : sinon « cleanops-test » serait pris pour
/// un identifiant de connexion (route /:slug).
String sansDossierWeb(String chemin) {
  if (chemin != kDossierAppWeb && !chemin.startsWith('$kDossierAppWeb/')) {
    return chemin;
  }
  final reste = chemin.substring(kDossierAppWeb.length);
  return reste.isEmpty ? '/' : reste;
}

/// Rend le lien d'ouverture (une seule fois) ; `null` s'il n'y en a pas.
String? consommerLienDemarrage() {
  final lien = _lienDemarrage;
  _lienDemarrage = null;
  return lien;
}

/// Un lien de partage s'ouvre directement, sans passer par le démarrage
/// (session, tableau de bord) : sa page est publique.
String? _consommerLienPublic() {
  final lien = _lienDemarrage;
  if (lien == null || !lien.startsWith('${AppRoutes.partage}/')) return null;
  _lienDemarrage = null;
  return lien;
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

/// Un identifiant sert aussi d'adresse de connexion (`/:slug`) : il ne doit
/// pas pouvoir être pris pour une page de l'app (les routes protégées sont
/// reconnues par leur début, d'où `startsWith`).
bool estSlugReserve(String slug) {
  final chemin = '/$slug';
  return chemin == AppRoutes.splash ||
      chemin == AppRoutes.partage ||
      _routesProtegees.any(chemin.startsWith);
}

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
  // Lien de partage : page publique, ouverte telle quelle quel que soit le
  // profil connecté (ou sans connexion). C'est son jeton qui en donne l'accès.
  if (location.startsWith('${AppRoutes.partage}/')) return null;

  final isOnSplash = location == AppRoutes.splash;
  final isOnLogin = location == AppRoutes.login;
  final isProtege = _routesProtegees.any((r) => location.startsWith(r));

  // Non authentifié sur route protégée → login
  if (employee == null) {
    return isProtege ? AppRoutes.login : null;
  }

  return switch (employee.profil) {
    // Réception : ACCÈS FERMÉ PAR DÉFAUT. Elle n'accède qu'à son écran d'accueil
    // et à ses 5 sections (`estRouteReception`) : toute autre page lui est
    // refusée, sans exception (routes protégées, inconnues, sous-routes, et
    // aussi la connexion et le démarrage une fois connectée). Elle n'hérite
    // d'aucun droit du responsable.
    ProfilAcces.reception =>
      estRouteReception(location) ? null : AppRoutes.reception,

    // Résident — confiné à /resident/* (donc jamais /reception)
    ProfilAcces.resident => isOnSplash || isOnLogin
        ? AppRoutes.residentDashboard
        : (location.startsWith(AppRoutes.residentDashboard)
            ? null
            : AppRoutes.residentDashboard),

    // Responsable — tableau de bord à la connexion, accès aux routes, sauf
    // l'écran réservé à la Réception
    ProfilAcces.responsable =>
      isOnSplash || isOnLogin || location.startsWith(AppRoutes.reception)
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
    // Lien de partage : ouvert directement. Sinon, démarrage (session) puis
    // éventuellement le lien d'ouverture (voir SplashScreen).
    initialLocation: _consommerLienPublic() ?? AppRoutes.splash,
    overridePlatformDefaultLocation: true,
    debugLogDiagnostics: true,

    // ── Redirection globale ───────────────────────────────
    redirect: (context, state) {
      // Lien web reçu par l'app mobile déjà ouverte (App Link Android) :
      // « /#/partage/x » → « /partage/x ».
      final fragment = state.uri.fragment;
      if (fragment.startsWith('/')) return fragment;
      // Adresse d'accueil de l'app web (…/cleanops-test/) : même chose.
      final chemin = sansDossierWeb(state.uri.path);
      if (chemin != state.uri.path) return chemin;
      return redirectionSelonAcces(
        employee: ref.read(authNotifierProvider).employee,
        location: state.matchedLocation,
      );
    },

    errorBuilder: (context, state) => const _ErrorScreen(),

    routes: [
      // ── Splash ─────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Login ──────────────────────────────────────────
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),

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
            builder: (context, state) => DemandesResidentsResponsableScreen(
              ouvrirMessages: state.uri.queryParameters['onglet'] ==
                  AppRoutes.ongletMessagesReception,
            ),
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

          // ── Réception : accueil + 5 sections ────────────
          // Routes À PLAT (pas imbriquées) : aucune pile parasite. Le routeur
          // n'y laisse entrer que la Réception (voir redirectionSelonAcces).
          GoRoute(
            path: receptionAccueilRoute,
            builder: (context, state) => const ReceptionDashboardScreen(),
          ),
          for (final section in receptionSections)
            GoRoute(
              path: section.route,
              // Sections construites : Résidents et Équipe ; les autres sont
              // provisoires.
              builder: (context, state) => switch (section.route) {
                receptionResidentsRoute => const ReceptionResidentsScreen(),
                receptionEquipeRoute => const ReceptionEquipeScreen(),
                receptionAAviserRoute => const ReceptionAAviserScreen(),
                receptionPinRoute => const ReceptionPinScreen(),
                receptionMessagesRoute => const ReceptionMessagesScreen(),
                _ => ReceptionSectionScreen(section: section),
              },
            ),
          GoRoute(
            path: receptionProfilRoute,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: receptionNotificationsRoute,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: receptionMesDemandesEquipeRoute,
            builder: (context, state) => const MesDemandesEquipeScreen(),
          ),
          GoRoute(
            path: receptionFichePattern,
            builder: (context, state) => ReceptionFicheScreen(
              appartementId: state.pathParameters['appartementId'] ?? '',
            ),
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
          GoRoute(
            path: AppRoutes.residentCalendrier,
            builder: (context, state) => ResidentCalendrierScreen(
              mois: DateTime.tryParse(state.uri.queryParameters['mois'] ?? ''),
            ),
          ),
          GoRoute(
            path: '${AppRoutes.residentCalendrier}/:date',
            builder: (context, state) => ResidentMenageScreen(
              date: DateTime.tryParse(state.pathParameters['date'] ?? '') ??
                  DateTime.now(),
            ),
          ),
        ],
      ),

      // ── Lien de partage d'une demande (public) ─────────
      GoRoute(
        path: '/partage/:jeton',
        builder: (context, state) =>
            PartageDemandeScreen(jeton: state.pathParameters['jeton'] ?? ''),
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
