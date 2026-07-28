import 'package:equatable/equatable.dart';

enum TypeNotifResident {
  changementDate,
  annulationConfirmee,
  demandeResolue,
  general;

  static TypeNotifResident fromString(String v) => switch (v) {
        'ChangementDate' => TypeNotifResident.changementDate,
        'AnnulationConfirmee' => TypeNotifResident.annulationConfirmee,
        'DemandeResolue' => TypeNotifResident.demandeResolue,
        _ => TypeNotifResident.general,
      };
}

class NotificationResident extends Equatable {
  final String id;
  final String residentId;
  final String? tacheJourId;
  final TypeNotifResident type;
  final String message;
  final bool isLue;
  final DateTime createdAt;

  const NotificationResident({
    required this.id,
    required this.residentId,
    this.tacheJourId,
    required this.type,
    required this.message,
    required this.isLue,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
