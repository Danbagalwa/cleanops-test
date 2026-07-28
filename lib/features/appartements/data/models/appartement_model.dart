import '../../domain/entities/appartement.dart';

class AppartementModel extends Appartement {
  const AppartementModel({
    required super.id,
    required super.numero,
    required super.taille,
    required super.minutesBase,
  });

  factory AppartementModel.fromJson(Map<String, dynamic> json) {
    return AppartementModel(
      id: json['id'] as String,
      numero: json['numero'] as String? ?? '',
      taille: json['taille'] as String? ?? '3 1/2',
      minutesBase: (json['minutes_base'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'taille': taille,
      'minutes_base': minutesBase,
    };
  }
}
