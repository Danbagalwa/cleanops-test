import 'package:equatable/equatable.dart';

class StatPreposee extends Equatable {
  final String prenom;
  final int total;
  final int fait;
  final int absent;
  final int refus;
  final double pourcentage;

  const StatPreposee({
    required this.prenom,
    required this.total,
    required this.fait,
    required this.absent,
    required this.refus,
    required this.pourcentage,
  });

  @override
  List<Object?> get props => [prenom, total, fait, absent, refus, pourcentage];
}
