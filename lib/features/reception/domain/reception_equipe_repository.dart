import 'reception_equipe_models.dart';

/// Accès de la Réception à l'équipe du jour, en lecture seule.
///
/// La lecture passe par une fonction serveur qui ne renvoie que des champs
/// autorisés : aucun accès direct aux tâches, donc aucun moyen d'atteindre le
/// motif d'un non-réalisé.
abstract class ReceptionEquipeRepository {
  Future<EquipeDuJour> equipeDuJour();
}
