import 'package:equatable/equatable.dart';

enum AireCategorie { ascenseur, corridor, tapis, chute, salon, wc }

enum AireStatut { aFaire, fait }

class TacheAireCommune extends Equatable {
  final String id;
  final AireCategorie categorie;
  final String zone;
  final DateTime semaineDate;
  final AireStatut statut;
  final String? confirmeParId;
  final String? confirmeParPrenom;
  final DateTime? confirmeLE;
  final String? note;

  const TacheAireCommune({
    required this.id,
    required this.categorie,
    required this.zone,
    required this.semaineDate,
    required this.statut,
    this.confirmeParId,
    this.confirmeParPrenom,
    this.confirmeLE,
    this.note,
  });

  bool get estFait => statut == AireStatut.fait;

  @override
  List<Object?> get props => [id];
}
