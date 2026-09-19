import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/core/router/app_router.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';

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

  group('Réception : accès fermé par défaut', () {
    final reception = _avec(RoleType.reception);

    for (final entree in routes.entries) {
      test('${entree.key} (${entree.value}) est refusée', () {
        expect(
          redirectionSelonAcces(employee: reception, location: entree.value),
          AppRoutes.login,
        );
      });
    }

    test('seule la page de connexion n\'est pas redirigée', () {
      expect(
        redirectionSelonAcces(employee: reception, location: AppRoutes.login),
        isNull,
      );
    });

    test('n\'est jamais aiguillée vers un écran du responsable ni de la préposée',
        () {
      for (final chemin in [AppRoutes.splash, AppRoutes.login]) {
        final cible =
            redirectionSelonAcces(employee: reception, location: chemin);
        expect(cible, isNot(AppRoutes.employerDashboard));
        expect(cible, isNot(AppRoutes.employeeDashboard));
      }
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
