import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/helpers/semaine_helper.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/memo.dart';
import '../models/memo_model.dart';

abstract class MemoDatasource {
  Future<List<MemoModel>> getConversation(String preposeeId);
  Future<MemoModel> getMemoById(String id);
  Future<List<PreposeeResume>> getPreposeeesAvecDernierMemo();
  Future<MemoModel> envoyerMemo({
    required String preposeeId,
    required String auteurId,
    required AuteurType auteur,
    required String message,
  });
  Future<void> marquerCommeLu(String preposeeId, AuteurType auteurCourant);
  RealtimeChannel subscriberConversation(
      String preposeeId, void Function(String memoId) onNewMessage);
}

class MemoDatasourceImpl implements MemoDatasource {
  static String get _dateAujourdhui =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Future<List<MemoModel>> getConversation(String preposeeId) async {
    try {
      final data = await SupabaseService.client
          .from('memos')
          .select(
              'id, employee_id, message, auteur, auteur_id, is_lu, date_lu, '
              'date_envoi, tache_jour_date, numero_semaine, '
              'auteur_employe:auteur_id(prenom)')
          .eq('employee_id', preposeeId)
          .order('date_envoi', ascending: true);
      return (data as List)
          .map((j) => MemoModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException('Erreur chargement conversation : $e');
    }
  }

  @override
  Future<List<PreposeeResume>> getPreposeeesAvecDernierMemo() async {
    try {
      // Les deux requêtes partent en parallèle — réduit d'un roundtrip réseau
      final results = await Future.wait([
        SupabaseService.table(SupabaseService.employees)
            .select('id, prenom')
            .eq('role', 'Employé')
            .eq('is_actif', true)
            .order('prenom'),
        SupabaseService.table(SupabaseService.memos)
            .select('employee_id, message, auteur, is_lu, date_envoi')
            .order('date_envoi', ascending: false)
            .limit(500),
      ]);
      final employeesData = results[0];
      final memosData = results[1];

      // 3. Grouper par employee_id en Dart
      final Map<String, List<Map<String, dynamic>>> memosByEmp = {};
      for (final m in memosData) {
        final eid = m['employee_id'] as String;
        (memosByEmp[eid] ??= []).add(m);
      }

      return employeesData.map((emp) {
        final empMemos = memosByEmp[emp['id']] ?? [];
        final lastMemo = empMemos.isNotEmpty ? empMemos.first : null;
        final nonLus = empMemos
            .where((m) =>
                m['auteur'] == 'Employé' &&
                (m['is_lu'] as bool? ?? false) == false)
            .length;
        return PreposeeResume(
          employeeId: emp['id'] as String,
          prenom: emp['prenom'] as String,
          dernierMessage: lastMemo?['message'] as String?,
          dernierEnvoi: lastMemo?['date_envoi'] != null
              ? DateTime.parse(lastMemo!['date_envoi'] as String)
              : null,
          nonLusCount: nonLus,
        );
      }).toList();
    } catch (e) {
      throw ServerException('Erreur liste préposées : $e');
    }
  }

  @override
  Future<MemoModel> envoyerMemo({
    required String preposeeId,
    required String auteurId,
    required AuteurType auteur,
    required String message,
  }) async {
    try {
      final data = await SupabaseService.client
          .from('memos')
          .insert({
            'employee_id': preposeeId,
            'auteur_id': auteurId,
            'auteur': auteur == AuteurType.employeur ? 'Employeur' : 'Employé',
            'message': message,
            'tache_jour_date': _dateAujourdhui,
            'numero_semaine': SemaineHelper.semaineCourante,
            'is_lu': false,
          })
          .select('*, auteur_employe:auteur_id(prenom)')
          .single();
      return MemoModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur envoi mémo : $e');
    }
  }

  @override
  Future<void> marquerCommeLu(
      String preposeeId, AuteurType auteurCourant) async {
    try {
      // On marque comme lus les messages envoyés par l'AUTRE côté
      final auteurAMarquer =
          auteurCourant == AuteurType.employeur ? 'Employé' : 'Employeur';
      await SupabaseService.client
          .from('memos')
          .update({
            'is_lu': true,
            'date_lu': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('employee_id', preposeeId)
          .eq('auteur', auteurAMarquer)
          .eq('is_lu', false);
    } catch (_) {}
  }

  @override
  Future<MemoModel> getMemoById(String id) async {
    try {
      final data = await SupabaseService.client
          .from('memos')
          .select(
              'id, employee_id, message, auteur, auteur_id, is_lu, date_lu, '
              'date_envoi, tache_jour_date, numero_semaine, '
              'auteur_employe:auteur_id(prenom)')
          .eq('id', id)
          .single();
      return MemoModel.fromJson(data);
    } catch (e) {
      throw ServerException('Erreur récupération mémo : $e');
    }
  }

  @override
  RealtimeChannel subscriberConversation(
      String preposeeId, void Function(String memoId) onNewMessage) {
    return SupabaseService.channel('memos_$preposeeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'memos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: preposeeId,
          ),
          callback: (payload) {
            final id = payload.newRecord['id'] as String?;
            if (id != null) onNewMessage(id);
          },
        )
        .subscribe();
  }
}
