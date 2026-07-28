import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../providers/statistiques_provider.dart';

class PeriodeSelectorWidget extends ConsumerStatefulWidget {
  const PeriodeSelectorWidget({super.key});

  @override
  ConsumerState<PeriodeSelectorWidget> createState() =>
      _PeriodeSelectorWidgetState();
}

class _PeriodeSelectorWidgetState
    extends ConsumerState<PeriodeSelectorWidget> {
  // État local pour la plage personnalisée avant application
  DateTime? _localDebut;
  DateTime? _localFin;

  static final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

  bool get _peutAppliquer =>
      _localDebut != null &&
      _localFin != null &&
      !_localFin!.isBefore(_localDebut!);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statistiquesNotifierProvider);
    final notifier = ref.read(statistiquesNotifierProvider.notifier);
    final periode = state.periodeSelectionnee;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 16, color: AppColors.rouge),
              const SizedBox(width: AppSizes.xs),
              const Text(
                'Période',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grisText,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Label période active
              Text(
                _labelPeriodeActive(state),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grisDark,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),

          // ── Dropdown ───────────────────────────────────────
          _PeriodeDropdown(
            valeur: periode,
            onChanged: (type) {
              if (type == PeriodeType.personnalisee) {
                setState(() {
                  _localDebut = null;
                  _localFin = null;
                });
              }
              notifier.selectionnerPeriode(type);
            },
          ),

          // ── Date pickers (mode personnalisé uniquement) ────
          if (periode == PeriodeType.personnalisee) ...[
            const SizedBox(height: AppSizes.sm),
            const Divider(height: 1, color: AppColors.grisMedium),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Du',
                    date: _localDebut,
                    onTap: () => _choisirDate(
                      context,
                      initial: _localDebut,
                      firstDate: DateTime(2024),
                      lastDate: _localFin ?? DateTime(2099),
                      onChoisie: (d) => setState(() => _localDebut = d),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _DateButton(
                    label: 'Au',
                    date: _localFin,
                    onTap: () => _choisirDate(
                      context,
                      initial: _localFin,
                      firstDate: _localDebut ?? DateTime(2024),
                      lastDate: DateTime(2099),
                      onChoisie: (d) => setState(() => _localFin = d),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                FilledButton(
                  onPressed: _peutAppliquer
                      ? () => notifier.selectionnerPeriodePersonnalisee(
                            _localDebut!,
                            _localFin!,
                          )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rouge,
                    disabledBackgroundColor:
                        AppColors.grisMedium,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: const Text('Appliquer',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_localDebut != null &&
                _localFin != null &&
                _localFin!.isBefore(_localDebut!))
              const Padding(
                padding: EdgeInsets.only(top: AppSizes.xs),
                child: Text(
                  'La date de fin doit être après la date de début.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.refus),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _labelPeriodeActive(StatistiquesState state) {
    final debut = state.dateDebut;
    final fin = state.dateFin;
    switch (state.periodeSelectionnee) {
      case PeriodeType.semaineCourante:
      case PeriodeType.semainePrecedente:
        return 'du ${_fmt.format(debut)} au ${_fmt.format(fin)}';
      case PeriodeType.moisCourant:
        return DateFormat('MMMM yyyy', 'fr_FR').format(debut);
      case PeriodeType.personnalisee:
        if (state.periodeSelectionnee == PeriodeType.personnalisee &&
            _localDebut == null) {
          return 'Choisir une plage';
        }
        return 'du ${_fmt.format(debut)} au ${_fmt.format(fin)}';
    }
  }

  Future<void> _choisirDate(
    BuildContext context, {
    DateTime? initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required void Function(DateTime) onChoisie,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.rouge,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChoisie(picked);
  }
}

// ── Dropdown interne ───────────────────────────────────────

class _PeriodeDropdown extends StatelessWidget {
  final PeriodeType valeur;
  final void Function(PeriodeType) onChanged;
  const _PeriodeDropdown({required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: DropdownButton<PeriodeType>(
        value: valeur,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.grisDark),
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.noir),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        items: PeriodeType.values
            .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label),
                ))
            .toList(),
        onChanged: (t) {
          if (t != null) onChanged(t);
        },
      ),
    );
  }
}

// ── Bouton date ────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  static final _fmt = DateFormat('d MMM yyyy', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.grisLight,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: date != null
                ? AppColors.rouge.withValues(alpha: 0.4)
                : AppColors.grisMedium,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grisText,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null ? _fmt.format(date!) : 'choisir…',
                style: TextStyle(
                  fontSize: 12,
                  color: date != null
                      ? AppColors.noir
                      : AppColors.grisText,
                  fontWeight: date != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 13,
                color: date != null
                    ? AppColors.rouge
                    : AppColors.grisText),
          ],
        ),
      ),
    );
  }
}
