import 'package:intl/intl.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart' show StatutTache;
import '../../domain/entities/statistiques_menages.dart';

abstract class StatistiquesDatasource {
  Future<List<MenageStat>> getMenages({
    required DateTime dateDebut,
    required DateTime dateFin,
  });
}

class StatistiquesDatasourceImpl implements StatistiquesDatasource {
  static final _fmt = DateFormat('yyyy-MM-dd');

  /// Taille d'une page : le serveur plafonne chaque réponse à 1000 lignes.
  static const _parPage = 1000;

  static const _kSelect =
      'semaine_reelle, periode, statut, employee_id, appartement_id, '
      'is_ajoutee, appartements(numero, taille), '
      'employees!taches_jour_employee_id_fkey(prenom, nom)';

  @override
  Future<List<MenageStat>> getMenages({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    try {
      final lignes = <Map<String, dynamic>>[];
      for (var debut = 0;; debut += _parPage) {
        final page = await SupabaseService.client
            .from(SupabaseService.tachesJour)
            .select(_kSelect)
            .gte('semaine_reelle', _fmt.format(dateDebut))
            .lte('semaine_reelle', _fmt.format(dateFin))
            .order('semaine_reelle')
            .order('id')
            .range(debut, debut + _parPage - 1);
        final liste = List<Map<String, dynamic>>.from(page as List);
        lignes.addAll(liste);
        if (liste.length < _parPage) break;
      }
      return lignes.map(_menage).toList();
    } catch (e) {
      throw ServerException('Erreur de chargement des statistiques : $e');
    }
  }

  static MenageStat _menage(Map<String, dynamic> j) {
    final appt = j['appartements'] as Map<String, dynamic>?;
    final emp = j['employees'] as Map<String, dynamic>?;
    // `semaine_reelle` porte la date réelle du ménage.
    final d = DateTime.parse(j['semaine_reelle'] as String);
    final nom = [emp?['prenom'], emp?['nom']]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    return MenageStat(
      date: DateTime(d.year, d.month, d.day),
      periode: j['periode'] as String? ?? 'AM',
      statut: StatutTache.fromString(j['statut'] as String? ?? ''),
      employeId: j['employee_id'] as String?,
      employeNom: nom.isEmpty ? 'Sans préposée' : nom,
      appartementId: j['appartement_id'] as String,
      numero: appt?['numero']?.toString() ?? '—',
      taille: appt?['taille']?.toString() ?? '',
      ajoute: j['is_ajoutee'] as bool? ?? false,
    );
  }
}
