import 'package:intl/intl.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/stat_semaine.dart';
import '../../domain/entities/stat_preposee.dart';
import '../../domain/entities/stat_appartement.dart';

abstract class StatistiquesDatasource {
  Future<List<StatSemaine>> getStatSemaine();
  Future<List<StatPreposee>> getStatParPreposee({
    required DateTime dateDebut,
    required DateTime dateFin,
  });
  Future<List<StatAppartement>> getTopAppartementsProblematiques();
}

class StatistiquesDatasourceImpl implements StatistiquesDatasource {
  static final _fmt = DateFormat('yyyy-MM-dd');

  static const _joursOrdre = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
  static const _joursLabels = {'Lundi': 0, 'Mardi': 1, 'Mercredi': 2, 'Jeudi': 3, 'Vendredi': 4};

  String get _premierDuMois {
    final now = DateTime.now();
    return _fmt.format(DateTime(now.year, now.month, 1));
  }

  // ── Section 1 : progression de la semaine ─────────────────

  @override
  Future<List<StatSemaine>> getStatSemaine() async {
    try {
      final now = DateTime.now();
      final lundi = now.subtract(Duration(days: now.weekday - 1));
      final vendredi = lundi.add(const Duration(days: 4));

      final data = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select('jour, statut')
          .gte('semaine_reelle', _fmt.format(lundi))
          .lte('semaine_reelle', _fmt.format(vendredi));

      // Agréger par jour
      final Map<String, _JourAccum> acc = {};
      for (final row in data as List) {
        final jour = row['jour'] as String;
        if (!_joursLabels.containsKey(jour)) continue;
        final a = acc.putIfAbsent(jour, _JourAccum.new);
        a.total++;
        if (row['statut'] == 'Fait') a.fait++;
      }

      return _joursOrdre
          .where(acc.containsKey)
          .map((jour) {
            final a = acc[jour]!;
            return StatSemaine(
              jour: jour,
              jourIndex: _joursLabels[jour]!,
              total: a.total,
              fait: a.fait,
              pourcentage: a.total > 0 ? a.fait * 100.0 / a.total : 0.0,
            );
          })
          .toList();
    } catch (e) {
      throw ServerException('Erreur stats semaine : $e');
    }
  }

  // ── Section 2 : stats par préposée (mois courant) ─────────

  @override
  Future<List<StatPreposee>> getStatParPreposee({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    try {
      // Employées actives
      final emps = await SupabaseService.client
          .from(SupabaseService.employees)
          .select('id, prenom')
          .eq('role', 'Employé')
          .eq('is_actif', true);

      if ((emps as List).isEmpty) return [];

      final ids = emps.map((e) => e['id'] as String).toList();
      final noms = <String, String>{for (final e in emps) e['id'] as String: e['prenom'] as String};

      // Tâches sur la plage de dates
      final taches = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select('employee_id, statut')
          .inFilter('employee_id', ids)
          .gte('semaine_reelle', _fmt.format(dateDebut))
          .lte('semaine_reelle', _fmt.format(dateFin));

      // Agréger par employée
      final Map<String, _EmpAccum> acc = {for (final id in ids) id: _EmpAccum()};
      for (final row in taches as List) {
        final empId = row['employee_id'] as String;
        final statut = row['statut'] as String;
        if (!acc.containsKey(empId)) continue;
        final a = acc[empId]!;
        a.total++;
        if (statut == 'Fait') a.fait++;
        if (statut == 'Absent') a.absent++;
        if (statut == 'Refus') a.refus++;
      }

      final result = ids
          .where((id) => acc[id]!.total > 0)
          .map((id) {
            final a = acc[id]!;
            return StatPreposee(
              prenom: noms[id] ?? '',
              total: a.total,
              fait: a.fait,
              absent: a.absent,
              refus: a.refus,
              pourcentage: a.total > 0 ? a.fait * 100.0 / a.total : 0.0,
            );
          })
          .toList()
        ..sort((a, b) => b.pourcentage.compareTo(a.pourcentage));

      return result;
    } catch (e) {
      throw ServerException('Erreur stats préposées : $e');
    }
  }

  // ── Section 3 : top appartements problématiques ───────────

  @override
  Future<List<StatAppartement>> getTopAppartementsProblematiques() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.tachesJour)
          .select('statut, appartement_id, appartements!inner(numero, taille)')
          .gte('semaine_reelle', _premierDuMois)
          .inFilter('statut', ['Absent', 'Refus']);

      final Map<String, _ApptAccum> acc = {};
      for (final row in data as List) {
        final apptId = row['appartement_id'] as String;
        final statut = row['statut'] as String;
        final appt = row['appartements'] as Map<String, dynamic>;
        final a = acc.putIfAbsent(
          apptId,
          () => _ApptAccum(
            numero: appt['numero'] as String,
            taille: appt['taille'] as String? ?? '',
          ),
        );
        if (statut == 'Absent') a.absences++;
        if (statut == 'Refus') a.refus++;
      }

      final result = acc.values
          .map((a) => StatAppartement(
                numero: a.numero,
                taille: a.taille,
                nbAbsences: a.absences,
                nbRefus: a.refus,
              ))
          .toList()
        ..sort((a, b) => b.totalProblemes.compareTo(a.totalProblemes));

      return result.take(10).toList();
    } catch (e) {
      throw ServerException('Erreur stats appartements : $e');
    }
  }
}

// ── Accumulateurs privés ───────────────────────────────────

class _JourAccum {
  int total = 0;
  int fait = 0;
}

class _EmpAccum {
  int total = 0;
  int fait = 0;
  int absent = 0;
  int refus = 0;
}

class _ApptAccum {
  final String numero;
  final String taille;
  int absences = 0;
  int refus = 0;
  _ApptAccum({required this.numero, required this.taille});
}
