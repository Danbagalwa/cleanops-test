import 'package:equatable/equatable.dart';

enum RoleType { employe, superviseurMenage, direction, reception, admin, resident }

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

  bool get isResponsable =>
      this != RoleType.employe && this != RoleType.resident;

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
