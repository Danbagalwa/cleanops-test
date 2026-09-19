import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';

void main() {
  const attendu = <RoleType, ProfilAcces>{
    RoleType.employe: ProfilAcces.preposee,
    RoleType.superviseurMenage: ProfilAcces.responsable,
    RoleType.direction: ProfilAcces.responsable,
    RoleType.admin: ProfilAcces.responsable,
    RoleType.reception: ProfilAcces.reception,
    RoleType.resident: ProfilAcces.resident,
  };

  test('chaque rôle a un profil d\'accès décidé explicitement', () {
    // Si un rôle est ajouté sans profil, le switch du code ne compile plus ;
    // ce test garde en plus la correspondance attendue, rôle par rôle.
    for (final role in RoleType.values) {
      expect(attendu.containsKey(role), isTrue,
          reason: '$role n\'a pas de profil attendu dans ce test');
      expect(role.profil, attendu[role], reason: '$role');
    }
  });

  group('la Réception n\'hérite d\'aucun droit du responsable', () {
    test('isResponsable est faux pour la Réception', () {
      expect(RoleType.reception.isResponsable, isFalse);
      expect(RoleType.reception.isReception, isTrue);
    });

    test('isResponsable reste vrai pour Admin, Direction et SuperviseurMenage',
        () {
      expect(RoleType.admin.isResponsable, isTrue);
      expect(RoleType.direction.isResponsable, isTrue);
      expect(RoleType.superviseurMenage.isResponsable, isTrue);
    });

    test('isResponsable reste faux pour la préposée et le résident', () {
      expect(RoleType.employe.isResponsable, isFalse);
      expect(RoleType.resident.isResponsable, isFalse);
    });

    test('un seul profil est vrai à la fois pour chaque rôle', () {
      for (final role in RoleType.values) {
        final vrais = [
          role.profil == ProfilAcces.preposee,
          role.isResponsable,
          role.isReception,
          role.profil == ProfilAcces.resident,
        ].where((b) => b).length;
        expect(vrais, 1, reason: '$role');
      }
    });
  });

  group('destinataires des notifications « responsables »', () {
    // Même calcul que demande_equipe_datasource (demandes d'équipe) et
    // resident_espace_datasource (demandes de résidents) : les rôles
    // « responsables » sont ceux qui reçoivent ces notifications.
    final destinataires = RoleType.values
        .where((role) => role.isResponsable)
        .map((role) => role.label)
        .toList();

    test('la Réception n\'en fait pas partie', () {
      expect(destinataires, isNot(contains('Reception')));
    });

    test('Admin, Direction et SuperviseurMenage en font toujours partie', () {
      expect(destinataires,
          containsAll(['Admin', 'Direction', 'SuperviseurMenage']));
    });

    test('ni la préposée ni le résident n\'en font partie', () {
      expect(destinataires, isNot(contains('Employé')));
      expect(destinataires, isNot(contains('Résident')));
    });
  });

  group('Employee', () {
    Employee avec(RoleType role) => Employee(
          id: 'id',
          nom: 'N',
          prenom: 'P',
          slug: 's',
          role: role,
          isActif: true,
        );

    test('expose le profil et isReception', () {
      final reception = avec(RoleType.reception);
      expect(reception.profil, ProfilAcces.reception);
      expect(reception.isReception, isTrue);
      expect(reception.isResponsable, isFalse);
      expect(avec(RoleType.admin).isReception, isFalse);
      expect(avec(RoleType.admin).isResponsable, isTrue);
    });
  });
}
