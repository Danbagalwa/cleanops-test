import 'package:equatable/equatable.dart';

class StatSemaine extends Equatable {
  final String jour;
  final int jourIndex; // 0=Lundi … 4=Vendredi
  final int total;
  final int fait;
  final double pourcentage;

  const StatSemaine({
    required this.jour,
    required this.jourIndex,
    required this.total,
    required this.fait,
    required this.pourcentage,
  });

  @override
  List<Object?> get props => [jour, jourIndex, total, fait, pourcentage];
}
