import 'package:equatable/equatable.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

class TacheResident extends Equatable {
  final String id;
  final String appartementId;
  final DateTime semaineReelle;
  final String jour;
  final PeriodeType periode;
  final StatutTache statut;
  final String? prenomPreposee;

  const TacheResident({
    required this.id,
    required this.appartementId,
    required this.semaineReelle,
    required this.jour,
    required this.periode,
    required this.statut,
    this.prenomPreposee,
  });

  // semaine_reelle stocke la date réelle de la tâche (pas le lundi de la semaine)
  DateTime get dateReelle => semaineReelle;

  bool get estAujourdhui {
    final now = DateTime.now();
    final dr = dateReelle;
    return dr.year == now.year && dr.month == now.month && dr.day == now.day;
  }

  bool get estFait => statut == StatutTache.fait;
  bool get estPrevu => statut == StatutTache.nonCommence;

  String get periodeDisplayLabel =>
      periode == PeriodeType.am ? 'Matin' : 'Après-midi';

  @override
  List<Object?> get props => [id];
}
