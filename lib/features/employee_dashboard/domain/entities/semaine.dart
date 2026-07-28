import 'package:equatable/equatable.dart';

enum StatutJour { nonCommence, enCours, complete }

class JourSemaine extends Equatable {
  final DateTime date;
  final String nom;
  final int numeroTaches;
  final int tachesConfirmees;
  final int totalMinutes;
  final StatutJour statut;

  const JourSemaine({
    required this.date,
    required this.nom,
    required this.numeroTaches,
    required this.tachesConfirmees,
    required this.totalMinutes,
    required this.statut,
  });

  bool get estAujourdhui {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  List<Object?> get props => [date, statut];
}

class Semaine extends Equatable {
  final int numeroSemaine;
  final DateTime lundiDate;
  final List<JourSemaine> jours;
  final String? messageSemaine;

  const Semaine({
    required this.numeroSemaine,
    required this.lundiDate,
    required this.jours,
    this.messageSemaine,
  });

  DateTime get vendrediDate => lundiDate.add(const Duration(days: 4));

  int get totalTachesJour {
    final today = jours.where((j) => j.estAujourdhui).firstOrNull;
    return today?.numeroTaches ?? 0;
  }

  int get totalMinutesJour {
    final today = jours.where((j) => j.estAujourdhui).firstOrNull;
    return today?.totalMinutes ?? 0;
  }

  JourSemaine? get jourAujourdhui {
    return jours.where((j) => j.estAujourdhui).firstOrNull;
  }

  @override
  List<Object?> get props => [numeroSemaine, lundiDate];
}