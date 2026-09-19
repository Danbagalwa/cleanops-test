import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/core/router/app_router.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/reception/presentation/reception_sections.dart';

Employee _avec(RoleType role) => Employee(
      id: 'id',
      nom: 'N',
      prenom: 'P',
      slug: 's',
      role: role,
      isActif: true,
    );

void main() {
  // Toutes les destinations de l'application, plus des chemins inconnus.
  const routes = <String, String>{
    'planning': '/planning',
    'planning (employé ciblé)': '/planning?employeeId=abc',
    'employés': '/employes',
    'chat d\'équipe': '/chat',
    'mémo': '/memo',
    'statistiques': '/statistiques',
    'demandes d\'équipe (responsable)': '/demandes/equipe',
    'mes demandes d\'équipe': '/mes-demandes-equipe',
    'demandes résidents': '/demandes/residents',
    'absences / présences': '/presences',
    'progression du jour': '/progression-jour',
    'tableau de bord responsable': '/employeur',
    'tableau de bord préposée': '/dashboard',
    'ma journée': '/journee',
    'appartements': '/appartements',
    'résidents': '/residents',
    'aires communes': '/aire-commune',
    'aires communes (config)': '/aire-commune/config',
    'messages de la semaine': '/messages-semaine',
    'tâches disponibles': '/taches-disponibles',
    'pdf': '/pdf',
    'profil': '/profil',
    'notifications': '/notifications',
    'espace résident': '/resident',
    'espace résident (demandes)': '/resident/demandes',
    'écran de démarrage': '/splash',
    'chemin inconnu': '/nimporte-quoi',
    'chemin inconnu profond': '/a/b/c',
  };

  group('Réception : une seule destination, tout le reste est refusé', () {
    final reception = _avec(RoleType.reception);

    for (final entree in {
      ...routes,
      'connexion': AppRoutes.login,
    }.entries) {
      test('${entree.key} (${entree.value}) renvoie vers l\'écran Réception',
          () {
        expect(
          redirectionSelonAcces(employee: reception, location: entree.value),
          AppRoutes.reception,
        );
      });
    }

    test('son accueil est accessible', () {
      expect(
        redirectionSelonAcces(
            employee: reception, location: AppRoutes.reception),
        isNull,
      );
    });

    for (final section in receptionSections) {
      test('la section ${section.titre} (${section.route}) est accessible',
          () {
        expect(
          redirectionSelonAcces(employee: reception, location: section.route),
          isNull,
        );
      });
    }

    test('des chemins qui ressemblent à /reception ne sont PAS accessibles',
        () {
      for (final piege in [
        '/receptionniste',
        '/reception-x',
        '/reception2',
        '/receptio',
      ]) {
        expect(
          redirectionSelonAcces(employee: reception, location: piege),
          AppRoutes.reception,
          reason: piege,
        );
      }
    });

    test('la route d\'accueil du routeur et celle des sections coïncident',
        () {
      expect(AppRoutes.reception, receptionAccueilRoute);
    });

    test('n\'est jamais aiguillée vers un écran du responsable ni de la préposée',
        () {
      for (final chemin in [
        AppRoutes.splash,
        AppRoutes.login,
        '/employeur',
        '/dashboard',
        '/planning',
      ]) {
        final cible =
            redirectionSelonAcces(employee: reception, location: chemin);
        expect(cible, AppRoutes.reception, reason: chemin);
        expect(cible, isNot(AppRoutes.employerDashboard));
        expect(cible, isNot(AppRoutes.employeeDashboard));
      }
    });
  });

  group('L\'écran Réception est réservé à la Réception', () {
    const reception = AppRoutes.reception;

    test('les responsables sont renvoyés vers leur tableau de bord', () {
      for (final role in [
        RoleType.admin,
        RoleType.direction,
        RoleType.superviseurMenage,
      ]) {
        expect(
          redirectionSelonAcces(employee: _avec(role), location: reception),
          AppRoutes.employerDashboard,
          reason: '$role',
        );
      }
    });

    test('la préposée est renvoyée vers son tableau de bord', () {
      expect(
        redirectionSelonAcces(
            employee: _avec(RoleType.employe), location: reception),
        AppRoutes.employeeDashboard,
      );
    });

    test('le résident est renvoyé vers son espace', () {
      expect(
        redirectionSelonAcces(
            employee: _avec(RoleType.resident), location: reception),
        AppRoutes.residentDashboard,
      );
    });

    test('un visiteur non connecté est renvoyé vers la connexion', () {
      expect(
        redirectionSelonAcces(employee: null, location: reception),
        AppRoutes.login,
      );
    });
  });

  group('Responsables : comportement inchangé', () {
    for (final role in [
      RoleType.admin,
      RoleType.direction,
      RoleType.superviseurMenage,
    ]) {
      final employee = _avec(role);

      test('$role : connexion et démarrage vers le tableau de bord', () {
        expect(
          redirectionSelonAcces(employee: employee, location: AppRoutes.login),
          AppRoutes.employerDashboard,
        );
        expect(
          redirectionSelonAcces(employee: employee, location: AppRoutes.splash),
          AppRoutes.employerDashboard,
        );
      });

      test('$role : accède au planning, aux employés, au chat et au mémo', () {
        for (final chemin in [
          '/planning',
          '/employes',
          '/chat',
          '/memo',
          '/statistiques',
          '/demandes/equipe',
          '/employeur',
        ]) {
          expect(
            redirectionSelonAcces(employee: employee, location: chemin),
            isNull,
            reason: '$role sur $chemin',
          );
        }
      });
    }
  });

  group('Préposée : comportement inchangé', () {
    final employee = _avec(RoleType.employe);

    test('connexion vers son tableau de bord', () {
      expect(
        redirectionSelonAcces(employee: employee, location: AppRoutes.login),
        AppRoutes.employeeDashboard,
      );
    });

    test('la route responsable lui est refusée', () {
      expect(
        redirectionSelonAcces(employee: employee, location: '/employeur'),
        AppRoutes.employeeDashboard,
      );
    });

    test('ses écrans ne sont pas redirigés', () {
      for (final chemin in ['/journee', '/planning', '/chat', '/memo']) {
        expect(
          redirectionSelonAcces(employee: employee, location: chemin),
          isNull,
          reason: chemin,
        );
      }
    });
  });

  group('Résident : comportement inchangé', () {
    final employee = _avec(RoleType.resident);

    test('confiné à /resident/*', () {
      expect(
        redirectionSelonAcces(employee: employee, location: '/planning'),
        AppRoutes.residentDashboard,
      );
      expect(
        redirectionSelonAcces(employee: employee, location: '/resident/demandes'),
        isNull,
      );
      expect(
        redirectionSelonAcces(employee: employee, location: AppRoutes.login),
        AppRoutes.residentDashboard,
      );
    });
  });

  group('Non authentifié : comportement inchangé', () {
    test('une route protégée renvoie à la connexion', () {
      for (final chemin in ['/planning', '/employes', '/chat', '/resident']) {
        expect(
          redirectionSelonAcces(employee: null, location: chemin),
          AppRoutes.login,
          reason: chemin,
        );
      }
    });

    test('la connexion elle-même n\'est pas redirigée', () {
      expect(
        redirectionSelonAcces(employee: null, location: AppRoutes.login),
        isNull,
      );
    });
  });
}
