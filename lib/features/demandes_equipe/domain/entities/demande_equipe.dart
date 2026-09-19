import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/employee.dart';

enum TypeDemandeEquipe {
  conge,
  absencePlanifiee;

  String get label => switch (this) {
        TypeDemandeEquipe.conge => 'Conge',
        TypeDemandeEquipe.absencePlanifiee => 'AbsencePlanifiee',
      };

  String get libelle => switch (this) {
        TypeDemandeEquipe.conge => 'Congé',
        TypeDemandeEquipe.absencePlanifiee => 'Absence planifiée',
      };

  static TypeDemandeEquipe fromString(String v) => switch (v) {
        'AbsencePlanifiee' => TypeDemandeEquipe.absencePlanifiee,
        _ => TypeDemandeEquipe.conge,
      };
}

enum StatutDemandeEquipe {
  enAttente,
  repondue,
  resolue;

  String get label => switch (this) {
        StatutDemandeEquipe.enAttente => 'EnAttente',
        StatutDemandeEquipe.repondue => 'Repondue',
        StatutDemandeEquipe.resolue => 'Resolue',
      };

  static StatutDemandeEquipe fromString(String v) => switch (v) {
        'Repondue' => StatutDemandeEquipe.repondue,
        'Resolue' => StatutDemandeEquipe.resolue,
        _ => StatutDemandeEquipe.enAttente,
      };
}

class DemandeEquipe extends Equatable {
  final String id;
  final String employeeId;
  final TypeDemandeEquipe type;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String motif;
  final StatutDemandeEquipe statut;
  final bool? approuve;
  final String? traiteParId;
  final String? noteResponsable;
  final DateTime createdAt;
  final DateTime? dateTraitement;

  // Relations (chargées via JOIN)
  final Employee? employee;
  final Employee? traitePar;

  const DemandeEquipe({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.dateDebut,
    this.dateFin,
    required this.motif,
    required this.statut,
    this.approuve,
    this.traiteParId,
    this.noteResponsable,
    required this.createdAt,
    this.dateTraitement,
    this.employee,
    this.traitePar,
  });

  bool get enAttente => statut == StatutDemandeEquipe.enAttente;
  bool get resolue => statut == StatutDemandeEquipe.resolue;
  bool get estApprouvee => resolue && approuve == true;
  bool get estRefusee => resolue && approuve == false;

  @override
  List<Object?> get props => [id, statut, approuve, noteResponsable];
}
