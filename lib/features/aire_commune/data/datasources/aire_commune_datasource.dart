import 'package:intl/intl.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/reset_aire_commune.dart';
import '../models/tache_aire_commune_model.dart';

abstract class AireCommuneDatasource {
  Future<List<TacheAireCommuneModel>> getTachesAireCommune();
  Future<TacheAireCommuneModel> confirmerZone(String id, String employeeId);
  Future<List<TacheAireCommuneModel>> getTachesByCategorie(String categorie);
  Future<void> resetSemaineComplete(String responsableId);
  Future<void> annulerConfirmationZone(String zoneId);
  Future<List<ResetAireCommune>> getHistoriqueResets();
  Future<String> getJourResetConfig();
  Future<void> updateJourReset(String jour);
  Future<bool> getResetAutoConfig();
  Future<void> updateResetAuto(bool actif);
}

class AireCommuneDatasourceImpl implements AireCommuneDatasource {
  String get _lundiCourant {
    final now = DateTime.now();
    final lundi = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(lundi);
  }

  static const _kSelectTache =
      'id, categorie, zone, semaine_date, statut, confirme_par, confirme_le, note, '
      'employees(prenom)';

  // ── Tâches ────────────────────────────────────────────────

  @override
  Future<List<TacheAireCommuneModel>> getTachesAireCommune() async {
    try {
      final semaine = _lundiCourant;
      var data = await SupabaseService.table(SupabaseService.tachesAireCommune)
          .select(_kSelectTache)
          .eq('semaine_date', semaine)
          .order('categorie');

      // Première semaine sans zones → copier depuis la semaine précédente
      if ((data as List).isEmpty) {
        await _initialiserSemaineCourante(semaine);
        data = await SupabaseService.table(SupabaseService.tachesAireCommune)
            .select(_kSelectTache)
            .eq('semaine_date', semaine)
            .order('categorie');
      }

      return (data as List)
          .map((j) => TacheAireCommuneModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement aire commune : $e');
    }
  }

  /// Crée les zones de la semaine courante à partir du modèle de la semaine
  /// précédente. Sans effet si aucun modèle n'existe (première utilisation).
  Future<void> _initialiserSemaineCourante(String lundiCourant) async {
    final now = DateTime.now();
    final lundi = now.subtract(Duration(days: now.weekday - 1));
    final lundiPrecStr =
        DateFormat('yyyy-MM-dd').format(lundi.subtract(const Duration(days: 7)));

    final template = await SupabaseService.client
        .from(SupabaseService.tachesAireCommune)
        .select('categorie, zone')
        .eq('semaine_date', lundiPrecStr);

    if ((template as List).isEmpty) return;

    final inserts = template
        .map<Map<String, dynamic>>((z) => {
              'categorie': z['categorie'] as String,
              'zone': z['zone'] as String,
              'semaine_date': lundiCourant,
              // statut par défaut 'AFaire' en BDD — pas besoin de le passer
            })
        .toList();

    await SupabaseService.client
        .from(SupabaseService.tachesAireCommune)
        .upsert(
          inserts,
          onConflict: 'semaine_date,categorie,zone',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<TacheAireCommuneModel> confirmerZone(
      String id, String employeeId) async {
    try {
      final data = await SupabaseService.table(SupabaseService.tachesAireCommune)
          .update({
            'statut': 'Fait',
            'confirme_par': employeeId,
            'confirme_le': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select(_kSelectTache)
          .single();
      return TacheAireCommuneModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur confirmation zone : $e');
    }
  }

  @override
  Future<List<TacheAireCommuneModel>> getTachesByCategorie(
      String categorie) async {
    try {
      final data = await SupabaseService.table(SupabaseService.tachesAireCommune)
          .select(_kSelectTache)
          .eq('semaine_date', _lundiCourant)
          .eq('categorie', categorie)
          .order('zone');
      return (data as List)
          .map((j) => TacheAireCommuneModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement catégorie $categorie : $e');
    }
  }

  // ── Reset ─────────────────────────────────────────────────

  @override
  Future<void> resetSemaineComplete(String responsableId) async {
    try {
      // UPDATE direct via PostgREST — gère la coercition text→aire_statut
      await SupabaseService.client
          .from(SupabaseService.tachesAireCommune)
          .update({
            'statut': 'AFaire',
            'confirme_par': null,
            'confirme_le': null,
          })
          .eq('semaine_date', _lundiCourant);

      await SupabaseService.client
          .from(SupabaseService.resetsAireCommune)
          .insert({
        'semaine_date': _lundiCourant,
        'automatique': false,
        'effectue_par': responsableId,
      });
    } catch (e) {
      throw ServerException('Erreur reset aire commune : $e');
    }
  }

  @override
  Future<void> annulerConfirmationZone(String zoneId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.tachesAireCommune)
          .update({
            'statut': 'AFaire',
            'confirme_par': null,
            'confirme_le': null,
          })
          .eq('id', zoneId);
    } catch (e) {
      throw ServerException('Erreur annulation zone : $e');
    }
  }

  // ── Historique ────────────────────────────────────────────

  @override
  Future<List<ResetAireCommune>> getHistoriqueResets() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.resetsAireCommune)
          .select('*, effectue_par_employe:effectue_par(prenom)')
          .order('date_reset', ascending: false)
          .limit(10);
      return (data as List)
          .map((j) => _parseReset(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement historique resets : $e');
    }
  }

  static ResetAireCommune _parseReset(Map<String, dynamic> j) {
    final employe = j['effectue_par_employe'] as Map<String, dynamic>?;
    return ResetAireCommune(
      id: j['id'] as String,
      semaineDate: DateTime.parse(j['semaine_date'] as String),
      automatique: j['automatique'] as bool? ?? true,
      effectuePar: j['effectue_par'] as String?,
      prenomEffectuePar: employe?['prenom'] as String?,
      dateReset: DateTime.parse(j['date_reset'] as String),
    );
  }

  // ── Config ────────────────────────────────────────────────

  @override
  Future<String> getJourResetConfig() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.config)
          .select()
          .eq('cle', 'reset_aire_commune_jour')
          .single();
      return (data['valeur'] as String?) ?? 'Lundi';
    } catch (_) {
      return 'Lundi';
    }
  }

  @override
  Future<void> updateJourReset(String jour) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.config)
          .upsert(
            {'cle': 'reset_aire_commune_jour', 'valeur': jour},
            onConflict: 'cle',
          );
    } catch (e) {
      throw ServerException('Erreur mise à jour jour reset : $e');
    }
  }

  @override
  Future<bool> getResetAutoConfig() async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.config)
          .select()
          .eq('cle', 'reset_aire_commune_auto')
          .single();
      return (data['valeur'] as String?) == 'true';
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> updateResetAuto(bool actif) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.config)
          .upsert(
            {'cle': 'reset_aire_commune_auto', 'valeur': actif.toString()},
            onConflict: 'cle',
          );
    } catch (e) {
      throw ServerException('Erreur mise à jour reset auto : $e');
    }
  }
}
