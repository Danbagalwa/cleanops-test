import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/helpers/date_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employes/presentation/providers/employes_provider.dart';
import '../../domain/entities/presence.dart';
import '../providers/presence_provider.dart';

// ── Helpers ────────────────────────────────────────────────

const _joursNoms = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche'
];
String _nomJour(DateTime date) => _joursNoms[date.weekday - 1];

String _vendrediStr(DateTime date) {
  final daysToFriday = (DateTime.friday - date.weekday + 7) % 7;
  final friday = date.add(Duration(days: daysToFriday));
  return '${friday.year}-${friday.month.toString().padLeft(2, '0')}-${friday.day.toString().padLeft(2, '0')}';
}

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Tâches du jour pour un employé (toutes périodes)
Future<List<Map<String, dynamic>>> _getTachesAbsent(
    String employeeId, DateTime date) async {
  try {
    final data = await SupabaseService.table(SupabaseService.tachesJour)
        .select('id, appartement_id, periode, statut, appartements(numero)')
        .eq('employee_id', employeeId)
        .eq('semaine_reelle', _dateStr(date))
        .eq('jour', _nomJour(date));
    return (data as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

// Filtre les tâches selon la période d'absence
List<Map<String, dynamic>> _filtrerParPeriode(
    List<Map<String, dynamic>> taches, StatutPresence statut) {
  return switch (statut) {
    StatutPresence.absentMatin =>
      taches.where((t) => (t['periode'] as String?) == 'AM').toList(),
    StatutPresence.absentApresMidi =>
      taches.where((t) => (t['periode'] as String?) == 'PM').toList(),
    _ => taches, // absent toute la journée → toutes les tâches
  };
}

Future<void> _notifierResidents({
  required String appartementId,
  required String? tacheJourId,
  required String type,
  required String message,
}) async {
  try {
    final residents = await SupabaseService.table(SupabaseService.residents)
        .select('id')
        .eq('appartement_id', appartementId)
        .eq('is_actif', true)
        .eq('a_application', true);

    if ((residents as List).isEmpty) return;
    final rows = residents
        .map((r) => {
              'resident_id': r['id'],
              if (tacheJourId != null) 'tache_jour_id': tacheJourId,
              'type': type,
              'message': message,
            })
        .toList();
    await SupabaseService.table(SupabaseService.notificationsResidents)
        .insert(rows);
  } catch (_) {}
}

Future<void> _notifierEmployes({
  required List<String> employeeIds,
  required String type,
  required String message,
  required String entityId,
}) async {
  try {
    if (employeeIds.isEmpty) return;
    final rows = employeeIds
        .map((id) => {
              'destinataire_id': id,
              'type': type,
              'message': message,
              'entity_id': entityId,
              'entity_type': 'Tache',
            })
        .toList();
    await SupabaseService.table(SupabaseService.notifications).insert(rows);
  } catch (_) {}
}

Future<void> _insererHistorique({
  required String type,
  required String entityId,
  required String employeurId,
  required String note,
  required Map<String, dynamic> donneeAvant,
  required Map<String, dynamic> donneeApres,
  bool canUndo = false,
}) async {
  try {
    await SupabaseService.table(SupabaseService.historiqueActions).insert({
      'type': type,
      'entity_id': entityId,
      'entity_type': 'Tache',
      'employeur_id': employeurId,
      'note': note,
      'can_undo': canUndo,
      'donnees_avant': donneeAvant,
      'donnees_apres': donneeApres,
    });
  } catch (_) {}
}

// ── Écran principal ────────────────────────────────────────

class AbsencesScreen extends ConsumerStatefulWidget {
  const AbsencesScreen({super.key});

  @override
  ConsumerState<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends ConsumerState<AbsencesScreen> {
  final DateTime _date = DateTime.now();

  Future<void> _charger() async {
    await ref.read(absencesNotifierProvider.notifier).charger(_date);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _charger();
      ref.read(employesNotifierProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(absencesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.grisLight,
      appBar: AppBar(
        backgroundColor: AppColors.rouge,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOrHome(AppRoutes.employerDashboard),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Absences du jour',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              DateHelper.formatDate(_date),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (state.absences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.sm),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.absences.length} absence${state.absences.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _charger,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.rouge))
            : state.error != null
                ? _ErrorBody(message: state.error!, onRetry: _charger)
                : state.absences.isEmpty
                    ? const _EmptyState()
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.md, vertical: AppSizes.lg),
                            itemCount: state.absences.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSizes.md),
                            itemBuilder: (context, i) => _AbsenceCard(
                              presence: state.absences[i],
                              date: _date,
                            ),
                          ),
                        ),
                      ),
      ),
    );
  }
}

// ── Carte absence — affiche l'employée + ses tâches ────────

class _AbsenceCard extends ConsumerStatefulWidget {
  final Presence presence;
  final DateTime date;
  const _AbsenceCard({required this.presence, required this.date});

  @override
  ConsumerState<_AbsenceCard> createState() => _AbsenceCardState();
}

class _AbsenceCardState extends ConsumerState<_AbsenceCard> {
  List<Map<String, dynamic>> _taches = [];
  bool _loadingTaches = true;

  // État par tâche : tacheId → 'A' | 'B' | 'C' | 'D' | null
  final Map<String, String?> _tacheDone = {};
  // tacheId → prénom préposée cible (pour transfert)
  final Map<String, String?> _tacheTransfertPrenom = {};
  final Map<String, bool> _tacheLoading = {};

  Presence get p => widget.presence;
  DateTime get d => widget.date;

  (Color, String, IconData) get _statutStyle => switch (p.statut) {
        StatutPresence.absent => (
            AppColors.rouge,
            'Absente — toute la journée',
            Icons.person_off_outlined
          ),
        StatutPresence.absentMatin => (
            AppColors.aVerifier,
            'Absente — matin (AM)',
            Icons.wb_twilight_outlined
          ),
        StatutPresence.absentApresMidi => (
            AppColors.aVerifier,
            'Absente — après-midi (PM)',
            Icons.nights_stay_outlined
          ),
        StatutPresence.present => (
            AppColors.fait,
            'Présente',
            Icons.check_circle_outline
          ),
      };

  @override
  void initState() {
    super.initState();
    _chargerTaches();
  }

  Future<void> _chargerTaches() async {
    final toutes = await _getTachesAbsent(p.employeeId, d);
    final filtrees = _filtrerParPeriode(toutes, p.statut);
    if (mounted) {
      setState(() {
        _taches = filtrees;
        _loadingTaches = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, statusLabel, statusIcon) = _statutStyle;
    final prenom = p.employee?.prenom ?? '';
    final nom = p.employee?.nom ?? '';
    final initiale = prenom.isNotEmpty ? prenom[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête employée ─────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(initiale,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom'.trim().isEmpty
                            ? 'Préposée inconnue'
                            : '$prenom $nom',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.noir),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (p.confirmedLe != null)
                  Text(
                    _heure(p.confirmedLe!),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grisText),
                  ),
              ],
            ),

            // ── Liste des tâches concernées ───────────────
            const SizedBox(height: AppSizes.md),
            const Divider(height: 1),
            const SizedBox(height: AppSizes.sm),

            if (_loadingTaches)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.rouge, strokeWidth: 2)),
              )
            else if (_taches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15, color: AppColors.fait),
                    SizedBox(width: 6),
                    Text(
                      'Aucune tâche pour cette période.',
                      style: TextStyle(fontSize: 13, color: AppColors.grisDark),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_taches.length} tâche${_taches.length > 1 ? 's' : ''} concernée${_taches.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grisText,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...List.generate(_taches.length, (i) {
                    final tache = _taches[i];
                    final tacheId = tache['id'] as String;
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i < _taches.length - 1 ? AppSizes.sm : 0),
                      child: _TacheItem(
                        tache: tache,
                        presence: p,
                        date: d,
                        done: _tacheDone[tacheId],
                        transfertPrenom: _tacheTransfertPrenom[tacheId],
                        isLoading: _tacheLoading[tacheId] ?? false,
                        onDone: (action, {String? prenom}) {
                          setState(() {
                            _tacheDone[tacheId] = action;
                            if (prenom != null) {
                              _tacheTransfertPrenom[tacheId] = prenom;
                            }
                          });
                        },
                        onLoading: (v) =>
                            setState(() => _tacheLoading[tacheId] = v),
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _heure(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

// ── Carte d'une tâche individuelle ─────────────────────────

class _TacheItem extends ConsumerWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final String? done;
  final String? transfertPrenom;
  final bool isLoading;
  final void Function(String action, {String? prenom}) onDone;
  final void Function(bool) onLoading;

  const _TacheItem({
    required this.tache,
    required this.presence,
    required this.date,
    required this.done,
    required this.transfertPrenom,
    required this.isLoading,
    required this.onDone,
    required this.onLoading,
  });

  String get _numAppart =>
      (tache['appartements'] as Map?)?['numero'] as String? ??
      (tache['appartement_id'] as String? ?? '?');

  String get _periode => tache['periode'] as String? ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne infos tâche
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.rouge.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_work_outlined,
                      size: 14, color: AppColors.rouge),
                ),
                const SizedBox(width: 8),
                Text(
                  'Apt $_numAppart',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.noir),
                ),
                const SizedBox(width: 8),
                _PeriodeBadge(periode: _periode),
                const Spacer(),
                _StatutTacheBadge(statut: tache['statut'] as String? ?? ''),
              ],
            ),

            const SizedBox(height: AppSizes.sm),

            // Actions ou état "fait"
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.rouge),
                  ),
                ),
              )
            else if (done != null)
              _DoneChip(action: done!, prenom: transfertPrenom)
            else
              _ActionRow(
                tache: tache,
                presence: presence,
                date: date,
                onDone: onDone,
                onLoading: onLoading,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Boutons d'action (inline) ──────────────────────────────

class _ActionRow extends ConsumerWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final void Function(String action, {String? prenom}) onDone;
  final void Function(bool) onLoading;

  const _ActionRow({
    required this.tache,
    required this.presence,
    required this.date,
    required this.onDone,
    required this.onLoading,
  });

  String get _tacheId => tache['id'] as String;
  String get _appartementId => tache['appartement_id'] as String;
  String get _numAppart =>
      (tache['appartements'] as Map?)?['numero'] as String? ?? _appartementId;
  String get _periode => tache['periode'] as String? ?? '';

  void _transferer(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _TransfertTacheDialog(
        tache: tache,
        presence: presence,
        date: date,
        onDone: ({String? prenom}) => onDone('A', prenom: prenom),
      ),
    );
  }

  Future<void> _liberer(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    final confirme = await _confirmerDialog(
      context,
      titre: 'Libérer à l\'équipe',
      message:
          'La tâche Apt $_numAppart ($_periode) sera visible par toute l\'équipe.',
      couleur: AppColors.aVerifier,
    );
    if (!confirme || !context.mounted) return;

    onLoading(true);
    final toutesPreposees = ref
        .read(employesNotifierProvider)
        .employes
        .where((e) => e.isActif && e.isPreposee && e.id != presence.employeeId)
        .map((e) => e.id)
        .toList();

    try {
      await SupabaseService.table(SupabaseService.tachesDisponibles).insert({
        'tache_jour_id': _tacheId,
        'motif': 'Absence',
        'libere_par': currentUser.id,
        'date_liberation': DateTime.now().toIso8601String(),
        'statut': 'Disponible',
        'visibilite': 'TouteEquipe',
        'date_expiration': _vendrediStr(date),
      });

      await _insererHistorique(
        type: 'LiberationTaches',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note:
            'Libération suite à absence de ${presence.employee?.prenom ?? 'la préposée'}',
        donneeAvant: {
          'employee_id': presence.employeeId,
          'statut': tache['statut']
        },
        donneeApres: {'statut': 'Disponible', 'visibilite': 'TouteEquipe'},
      );

      await _notifierEmployes(
        employeeIds: toutesPreposees,
        type: 'TacheDisponible',
        message:
            'Tâche disponible — Apt $_numAppart ${_nomJour(date)} $_periode',
        entityId: _tacheId,
      );

      onLoading(false);
      onDone('B');
    } catch (e) {
      onLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ));
      }
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    final note = await _noteDialog(
      context,
      titre: 'Annuler le ménage',
      message:
          'La tâche Apt $_numAppart ($_periode) sera annulée. Le résident sera notifié.',
      couleur: AppColors.rouge,
    );
    if (note == null || !context.mounted) return;

    onLoading(true);
    try {
      final maintenant = DateTime.now().toIso8601String();
      await SupabaseService.table(SupabaseService.tachesJour).update({
        'statut': 'Annulé',
        'confirme_par': currentUser.id,
        'confirme_le': maintenant,
      }).eq('id', _tacheId);

      await _insererHistorique(
        type: 'Annulation',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note: note,
        donneeAvant: {
          'employee_id': presence.employeeId,
          'statut': tache['statut']
        },
        donneeApres: {'statut': 'Annulé', 'confirme_par': currentUser.id},
      );

      await _notifierResidents(
        appartementId: _appartementId,
        tacheJourId: _tacheId,
        type: 'MenageEnAttente',
        message: 'Votre ménage est momentanément en attente. '
            'Vous serez informé(e) dès qu\'une date est confirmée.',
      );

      onLoading(false);
      onDone('C');
    } catch (e) {
      onLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        _ActionChip(
          icon: Icons.swap_horiz_rounded,
          label: 'Transférer',
          color: AppColors.absent,
          onTap: () => _transferer(context, ref),
        ),
        _ActionChip(
          icon: Icons.lock_open_rounded,
          label: 'Libérer',
          color: AppColors.aVerifier,
          onTap: () => _liberer(context, ref),
        ),
        _ActionChip(
          icon: Icons.cancel_outlined,
          label: 'Annuler',
          color: AppColors.rouge,
          onTap: () => _annuler(context, ref),
        ),
        _ActionChip(
          icon: Icons.hourglass_empty_rounded,
          label: 'Laisser',
          color: AppColors.grisText,
          onTap: () => onDone('D'),
        ),
      ],
    );
  }
}

// ── Dialog transfert d'une tâche ──────────────────────────

class _TransfertTacheDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> tache;
  final Presence presence;
  final DateTime date;
  final void Function({String? prenom}) onDone;

  const _TransfertTacheDialog({
    required this.tache,
    required this.presence,
    required this.date,
    required this.onDone,
  });

  @override
  ConsumerState<_TransfertTacheDialog> createState() =>
      _TransfertTacheDialogState();
}

class _TransfertTacheDialogState extends ConsumerState<_TransfertTacheDialog> {
  String? _selectedId;
  String? _selectedPrenom;
  bool _loading = false;

  String get _tacheId => widget.tache['id'] as String;
  String get _appartementId => widget.tache['appartement_id'] as String;
  String get _numAppart =>
      (widget.tache['appartements'] as Map?)?['numero'] as String? ??
      _appartementId;
  String get _periode => widget.tache['periode'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final employes = ref.watch(employesNotifierProvider);
    final currentUser = ref.read(employeeCourantProvider);

    final cibles = employes.employes
        .where((e) =>
            e.id != widget.presence.employeeId &&
            e.id != currentUser?.id &&
            e.isActif &&
            e.isPreposee)
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.absent),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Transférer — Apt $_numAppart ($_periode)',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Réassigner cette tâche à une préposée disponible. '
              'Le résident sera notifié.',
              style: TextStyle(fontSize: 13, color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.md),
            if (cibles.isEmpty)
              const Text('Aucune préposée disponible.',
                  style: TextStyle(color: AppColors.grisText))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedId,
                decoration: const InputDecoration(
                  labelText: 'Préposée destinataire',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: cibles
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text('${e.prenom} ${e.nom}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  final emp = cibles.where((e) => e.id == v).firstOrNull;
                  setState(() {
                    _selectedId = v;
                    _selectedPrenom = emp?.prenom;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _selectedId == null || _loading
              ? null
              : () => _confirmer(context),
          style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Confirmer'),
        ),
      ],
    );
  }

  Future<void> _confirmer(BuildContext context) async {
    if (_selectedId == null) return;
    final currentUser = ref.read(employeeCourantProvider);
    if (currentUser == null) return;

    setState(() => _loading = true);

    try {
      // 1. Réassigner la tâche
      await SupabaseService.table(SupabaseService.tachesJour).update({
        'employee_id': _selectedId,
        'is_transfert_temp': true,
      }).eq('id', _tacheId);

      // 2. Enregistrer le transfert
      await SupabaseService.table(SupabaseService.transferts).insert({
        'tache_jour_id': _tacheId,
        'employee_source_id': widget.presence.employeeId,
        'employee_dest_id': _selectedId,
        'type': 'Temporaire',
        'date_debut': _dateStr(widget.date),
        'date_fin': _dateStr(widget.date),
        'effectué_par': currentUser.id,
        'note': 'Transfert suite à absence',
      });

      // 3. Historique
      await _insererHistorique(
        type: 'Transfert',
        entityId: _tacheId,
        employeurId: currentUser.id,
        note:
            'Transfert suite à absence de ${widget.presence.employee?.prenom ?? 'la préposée'}',
        donneeAvant: {
          'employee_id': widget.presence.employeeId,
          'statut': widget.tache['statut'],
        },
        donneeApres: {'employee_id': _selectedId, 'is_transfert_temp': true},
        canUndo: true,
      );

      // 4. Notifier la préposée cible
      await _notifierEmployes(
        employeeIds: [_selectedId!],
        type: 'Transfert',
        message:
            'Apt $_numAppart vous a été transféré — ${_nomJour(widget.date)} $_periode',
        entityId: _tacheId,
      );

      // 5. Notifier le résident
      await _notifierResidents(
        appartementId: _appartementId,
        tacheJourId: _tacheId,
        type: 'Remplacement',
        message:
            'Votre ménage est confirmé — Préposée : ${_selectedPrenom ?? 'une préposée'}',
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      widget.onDone(prenom: _selectedPrenom);
    } catch (e) {
      setState(() => _loading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.rouge,
        ));
      }
    }
  }
}

// ── Helpers dialogs ────────────────────────────────────────

Future<bool> _confirmerDialog(
  BuildContext context, {
  required String titre,
  required String message,
  required Color couleur,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      title: Text(titre),
      content: Text(message,
          style: const TextStyle(fontSize: 13, color: AppColors.grisDark)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: couleur),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> _noteDialog(
  BuildContext context, {
  required String titre,
  required String message,
  required Color couleur,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
          title: Text(titre),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.grisDark)),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Note *',
                    border: OutlineInputBorder(),
                    hintText: 'Raison de l\'annulation...',
                  ),
                  onChanged: (_) => setS(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: couleur),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PeriodeBadge extends StatelessWidget {
  final String periode;
  const _PeriodeBadge({required this.periode});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (periode) {
      'AM' => (AppColors.aVerifier, 'Matin'),
      'PM' => (AppColors.absent, 'Après-midi'),
      _ => (AppColors.grisDark, periode),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatutTacheBadge extends StatelessWidget {
  final String statut;
  const _StatutTacheBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = switch (statut) {
      'Fait' => AppColors.fait,
      'Annulé' => AppColors.grisDark,
      _ => AppColors.nonCommence,
    };
    return Text(statut,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500));
  }
}

class _DoneChip extends StatelessWidget {
  final String action;
  final String? prenom;
  const _DoneChip({required this.action, this.prenom});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (action) {
      'A' => (
          AppColors.absent,
          Icons.swap_horiz_rounded,
          prenom != null ? 'Transférée à $prenom' : 'Transférée',
        ),
      'B' => (
          AppColors.aVerifier,
          Icons.lock_open_rounded,
          'Libérée à l\'équipe'
        ),
      'C' => (AppColors.rouge, Icons.cancel_outlined, 'Ménage annulé'),
      _ => (
          AppColors.grisText,
          Icons.hourglass_empty_rounded,
          'Laissée en attente'
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── États vides / erreur ───────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.xl),
                decoration: BoxDecoration(
                    color: AppColors.fait.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline,
                    size: 56, color: AppColors.fait),
              ),
              const SizedBox(height: AppSizes.lg),
              const Text('Aucune absence signalée',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.noir)),
              const SizedBox(height: AppSizes.sm),
              const Text('Toute l\'équipe est présente aujourd\'hui.',
                  style: TextStyle(color: AppColors.grisText, fontSize: 14)),
            ],
          ),
        ),
      ]);
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 100),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.xl),
                  decoration: BoxDecoration(
                      color: AppColors.rouge.withValues(alpha: 0.08),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline,
                      size: 48, color: AppColors.rouge),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.grisDark, fontSize: 14)),
                const SizedBox(height: AppSizes.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.rouge),
                ),
              ],
            ),
          ),
        ),
      ]);
}
