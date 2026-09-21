import 'package:equatable/equatable.dart';

enum RoleType { employe, superviseurMenage, direction, reception, admin, resident }

/// Profil d'accès : ce qu'un rôle a le droit de faire dans l'application.
///
/// Déduit du rôle par un `switch` EXHAUSTIF ([RoleTypeExtension.profil]) :
/// ajouter un rôle sans décider de son profil est une erreur de compilation,
/// jamais un repli silencieux vers un autre profil.
enum ProfilAcces { preposee, responsable, reception, resident }

extension RoleTypeExtension on RoleType {
  String get label {
    switch (this) {
      case RoleType.employe:
        return 'Employé';
      case RoleType.superviseurMenage:
        return 'SuperviseurMenage';
      case RoleType.direction:
        return 'Direction';
      case RoleType.reception:
        return 'Reception';
      case RoleType.admin:
        return 'Admin';
      case RoleType.resident:
        return 'Résident';
    }
  }

  /// Libellé à AFFICHER. `label` sert aussi de valeur en base (« Reception »,
  /// sans accent) : on ne le modifie pas, on affiche celui-ci.
  String get libelleAffiche => this == RoleType.reception ? 'Réception' : label;

  /// Profil d'accès du rôle.
  ///
  /// Admin, Direction et SuperviseurMenage restent dans « responsable » : leur
  /// fusion en un seul rôle est un chantier séparé. La Réception a son propre
  /// profil et n'hérite d'AUCUN droit du responsable.
  ProfilAcces get profil => switch (this) {
        RoleType.employe => ProfilAcces.preposee,
        RoleType.superviseurMenage ||
        RoleType.direction ||
        RoleType.admin =>
          ProfilAcces.responsable,
        RoleType.reception => ProfilAcces.reception,
        RoleType.resident => ProfilAcces.resident,
      };

  /// Vrai pour les seuls profils « responsable » (Réception exclue).
  bool get isResponsable => profil == ProfilAcces.responsable;

  bool get isReception => profil == ProfilAcces.reception;

  static RoleType fromString(String value) {
    switch (value) {
      case 'SuperviseurMenage':
        return RoleType.superviseurMenage;
      case 'Direction':
        return RoleType.direction;
      case 'Reception':
        return RoleType.reception;
      case 'Admin':
        return RoleType.admin;
      case 'Résident':
      case 'Resident':
        return RoleType.resident;
      default:
        return RoleType.employe;
    }
  }
}

class Employee extends Equatable {
  final String id;
  final String nom;
  final String prenom;
  final String slug;
  final RoleType role;
  final bool isActif;
  final String? numeroPointeuse; // 6 chiffres — préposée seulement
  final String? nomResidence; // ex: "jazzteasdale" — responsable seulement
  final DateTime? dateCreation;
  final DateTime? dateMiseAJour;

  const Employee({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.slug,
    required this.role,
    required this.isActif,
    this.numeroPointeuse,
    this.nomResidence,
    this.dateCreation,
    this.dateMiseAJour,
  });

  String get nomComplet => '$prenom $nom';

  bool get isPreposee => role == RoleType.employe;

  bool get isResponsable => role.isResponsable;

  bool get isReception => role.isReception;

  ProfilAcces get profil => role.profil;

  bool get isResident => role == RoleType.resident;

  @override
  List<Object?> get props => [
    id,
    nom,
    prenom,
    slug,
    role,
    isActif,
    numeroPointeuse,
    nomResidence,
  ];
}
