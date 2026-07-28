import '../../domain/entities/employee.dart';

class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.id,
    required super.nom,
    required super.prenom,
    required super.slug,
    required super.role,
    required super.isActif,
    super.numeroPointeuse,
    super.nomResidence,
    super.dateCreation,
    super.dateMiseAJour,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      slug: json['slug'] as String,
      role: RoleTypeExtension.fromString(json['role'] as String),
      isActif: json['is_actif'] as bool? ?? true,
      numeroPointeuse: json['numero_pointeuse'] as String?,
      nomResidence: json['nom_residence'] as String?,
      dateCreation: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : null,
      dateMiseAJour: json['date_mise_a_jour'] != null
          ? DateTime.parse(json['date_mise_a_jour'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'slug': slug,
      'role': role.label,
      'is_actif': isActif,
      if (numeroPointeuse != null) 'numero_pointeuse': numeroPointeuse,
      if (nomResidence != null) 'nom_residence': nomResidence,
    };
  }
}
