import 'package:equatable/equatable.dart';

class ResetAireCommune extends Equatable {
  final String id;
  final DateTime semaineDate;
  final bool automatique;
  final String? effectuePar;
  final String? prenomEffectuePar;
  final DateTime dateReset;

  const ResetAireCommune({
    required this.id,
    required this.semaineDate,
    required this.automatique,
    this.effectuePar,
    this.prenomEffectuePar,
    required this.dateReset,
  });

  @override
  List<Object?> get props => [id];
}
