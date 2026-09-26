import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/dialogue_app.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/export_menu_button.dart'
    show showExportSuccess;
import '../../../../core/widgets/mise_en_page.dart';
import '../../../../core/widgets/notification_app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_appartements_export.dart';
import '../../../pdf/presentation/screens/appartements_pdf_preview_screen.dart';
import '../../domain/entities/appartement.dart';
import '../providers/appartements_provider.dart';
import '../widgets/appartement_form_widget.dart';
import '../widgets/appartement_list_item.dart';

enum _Filtre { tous, avecAnimal, avecNotes }

enum _Tri { numero, taille, duree }

class AppartementsScreen extends ConsumerStatefulWidget {
  const AppartementsScreen({super.key});

  @override
  ConsumerState<AppartementsScreen> createState() => _AppartementsScreenState();
}

class _AppartementsScreenState extends ConsumerState<AppartementsScreen> {
  final _searchCtrl = TextEditingController();
  String _recherche = '';
  String? _taille;
  _Filtre _filtre = _Filtre.tous;
  _Tri _tri = _Tri.numero;
  bool _croissant = true;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  @override
  void initState() {
    super.initState();
    Future.microtask(_charger);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() =>
      ref.read(appartementsNotifierProvider.notifier).charger();

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : true;
        _tri = tri;
      });

  void _effacerFiltres() {
    _searchCtrl.clear();
    _changer(() {
      _recherche = '';
      _taille = null;
      _filtre = _Filtre.tous;
    });
  }

  bool _duFiltre(Appartement a) => switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.avecAnimal => a.hasAnimal,
        _Filtre.avecNotes => a.notes?.trim().isNotEmpty ?? false,
      };

  List<Appartement> _lignes(List<Appartement> tous) {
    final q = _recherche.trim().toLowerCase();
    int sens(int c) => _croissant ? c : -c;
    return tous.where((a) {
      if (_taille != null && a.taille != _taille) return false;
      if (!_duFiltre(a)) return false;
      return q.isEmpty ||
          a.numero.toLowerCase().contains(q) ||
          (a.notes?.toLowerCase().contains(q) ?? false) ||
          (a.typeAnimal?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) {
        final c = switch (_tri) {
          _Tri.numero => 0,
          _Tri.taille => a.taille.compareTo(b.taille),
          _Tri.duree => a.minutesBase.compareTo(b.minutesBase),
        };
        if (c != 0) return sens(c);
        final n = comparerNumeros(a.numero, b.numero);
        return _tri == _Tri.numero ? sens(n) : n;
      });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_recherche.trim().isNotEmpty) 'Recherche : "${_recherche.trim()}"',
      if (_taille != null) 'Taille : $_taille',
      if (_filtre == _Filtre.avecAnimal) 'Avec animal',
      if (_filtre == _Filtre.avecNotes) 'Avec notes',
    ];
    return f.isEmpty ? 'Tous les appartements' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  void _ouvrirFormulaire({Appartement? appartement}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormDialog(appartement: appartement),
    );
  }

  Future<void> _confirmerSuppression(Appartement appt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogueApp(
        titre: 'Supprimer l’appartement',
        largeur: 440,
        libelleAction: 'Supprimer',
        libelleSecondaire: 'Annuler',
        onFermer: () => Navigator.of(ctx).pop(false),
        onAction: () => Navigator.of(ctx).pop(true),
        contenu: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.aVerifier, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'L’appartement ${appt.numero} sera définitivement supprimé. '
                'Vérifiez qu’il n’est plus utilisé dans le planning.',
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: AppColors.grisDark),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final succes = await ref
        .read(appartementsNotifierProvider.notifier)
        .supprimer(appt.id);
    if (!mounted) return;
    if (succes) {
      NotificationApp.succes(
          context, 'L’appartement ${appt.numero} a été supprimé.');
    } else {
      AppFeedback.showError(
          context, ref.read(appartementsNotifierProvider).error ?? 'Échec.');
    }
  }

  void _exporterPdf(List<Appartement> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppartementsPdfPreviewScreen(
          appartements: lignes,
          filterDescription: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<Appartement> lignes) {
    try {
      const GenerateAppartementsExcel()(
        appartements: lignes,
        filterDescription: _descriptionFiltres(),
      );
      showExportSuccess(
          context, 'La liste Excel des appartements a été téléchargée.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appartementsNotifierProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final tous = state.appartements;
    final avecAnimal = tous.where((a) => a.hasAnimal).length;
    final minutesTotal = tous.fold(0, (s, a) => s + a.minutesBase);
    final lignes = _lignes(tous);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();

    FiltreSection filtre(_Filtre f, IconData icone, String info) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _filtre == f,
          onTap: () => _changer(() => _filtre = f),
        );

    final recherche = ChampRecherche(
      controller: _searchCtrl,
      indice: 'Rechercher un numéro, une note ou un animal',
      onChanged: (v) => _changer(() => _recherche = v),
    );
    final ajouter = FilledButton.icon(
      onPressed: () => _ouvrirFormulaire(),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      icon: const Icon(Icons.add_rounded, size: 19),
      label: Text(compact ? 'Ajouter' : 'Ajouter un appartement'),
    );

    Widget corps;
    if (state.isLoading && tous.isEmpty) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (state.error != null && tous.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(error: state.error!, onRetry: _charger),
      );
    } else if (tous.isEmpty) {
      corps = _EtatVide(onAdd: () => _ouvrirFormulaire());
    } else if (lignes.isEmpty) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          children: [
            const Text(
              'Aucun appartement ne correspond à votre recherche ou filtre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grisDark),
            ),
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: _effacerFiltres,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Effacer les filtres'),
            ),
          ],
        ),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauAppartements(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onModifier: (a) => _ouvrirFormulaire(appartement: a),
              onSupprimer: _confirmerSuppression,
            )
          else
            _GrilleAppartements(
              lignes: visibles,
              onModifier: (a) => _ouvrirFormulaire(appartement: a),
              onSupprimer: _confirmerSuppression,
            ),
          const SizedBox(height: AppSizes.md),
          BarrePagination(
            page: page,
            parPage: _parPage,
            total: lignes.length,
            onPage: (p) => setState(() => _page = p),
            onParPage: (n) => _changer(() => _parPage = n),
          ),
        ],
      );
    }

    return PageAvecEnTete(
      chargement: state.isLoading,
      enTete: EnTetePage(
        icone: Icons.apartment_rounded,
        titre: 'Appartements',
        sousTitre: tous.isEmpty
            ? 'Résidence — logements à entretenir'
            : 'Résidence — ${tous.length} appartements · '
                '${_duree(minutesTotal)} d’entretien au total'
                '${avecAnimal > 0 ? ' · $avecAnimal avec animal' : ''}',
      ),
      contenu: RefreshIndicator(
        color: AppColors.rouge,
        onRefresh: _charger,
        child: ListView(
          padding: EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
              .plusBarre(context),
          children: [
            BarreSection(
              titre: 'Appartements (${lignes.length})',
              onRetour: () => context.backOrHome(AppRoutes.employerDashboard),
              filtres: [
                filtre(_Filtre.tous, Icons.apartment_rounded,
                    'Tous les appartements'),
                filtre(_Filtre.avecAnimal, Icons.pets_rounded, 'Avec animal'),
                filtre(_Filtre.avecNotes, Icons.sticky_note_2_outlined,
                    'Avec notes'),
              ],
              actions: [
                ActionSection(
                  icone: Icons.print_rounded,
                  infoBulle: 'Imprimer ou exporter en PDF',
                  onPressed: lignes.isEmpty || state.isLoading
                      ? null
                      : () => _exporterPdf(lignes),
                ),
                ActionSection(
                  icone: Icons.download_rounded,
                  infoBulle: 'Télécharger en Excel',
                  onPressed: lignes.isEmpty || state.isLoading
                      ? null
                      : () => _exporterExcel(lignes),
                ),
                ActionSection(
                  icone: Icons.refresh_rounded,
                  infoBulle: 'Actualiser',
                  onPressed: state.isLoading ? null : _charger,
                ),
              ],
            ),
            if (tous.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _FiltreTailles(
                appartements: tous.where(_duFiltre).toList(),
                selection: _taille,
                onChanged: (t) => _changer(() => _taille = t),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            if (compact)
              Row(
                children: [
                  Expanded(child: recherche),
                  const SizedBox(width: AppSizes.sm),
                  ajouter,
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: recherche,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  BasculeAffichage(
                    mode: mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(width: AppSizes.md),
                  ajouter,
                ],
              ),
            const SizedBox(height: AppSizes.md),
            corps,
          ],
        ),
      ),
    );
  }
}

/// Durée « 12 h 30 » lisible pour un total de minutes.
String _duree(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

// ── Filtre par taille (avec effectifs) ─────────────────────

class _FiltreTailles extends StatelessWidget {
  final List<Appartement> appartements;
  final String? selection;
  final ValueChanged<String?> onChanged;

  const _FiltreTailles({
    required this.appartements,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _TuileTaille tuile(String? t) {
      final dans = t == null
          ? appartements
          : appartements.where((a) => a.taille == t).toList();
      final minutes = dans.fold(0, (s, a) => s + a.minutesBase);
      return _TuileTaille(
        taille: t,
        nombre: dans.length,
        detail: dans.isEmpty ? '—' : _duree(minutes),
        actif: selection == t,
        onTap: () => onChanged(selection == t ? null : t),
      );
    }

    final tuiles = [tuile(null), for (final t in taillesAppartement) tuile(t)];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 150.0;
      final tiennent =
          c.maxWidth >= tuiles.length * minimum + ecart * (tuiles.length - 1);
      if (tiennent) {
        return Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              Expanded(child: t),
            ],
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in tuiles.indexed) ...[
              if (i > 0) const SizedBox(width: ecart),
              SizedBox(width: minimum, child: t),
            ],
          ],
        ),
      );
    });
  }
}

class _TuileTaille extends StatelessWidget {
  final String? taille;
  final int nombre;
  final String detail;
  final bool actif;
  final VoidCallback onTap;

  const _TuileTaille({
    required this.taille,
    required this.nombre,
    required this.detail,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = taille == null ? AppColors.rouge : couleurTaille(taille!);
    return Material(
      color: actif ? AppColors.rouge.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: actif ? AppColors.rouge : AppColors.grisMedium,
          width: actif ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: taille == null
                    ? Icon(Icons.apartment_rounded, size: 18, color: couleur)
                    : Text(
                        tailleCourte(taille!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: couleur,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$nombre',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.noir,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      taille == null
                          ? 'Toutes · $detail'
                          : '${tailleCourte(taille!)} · $detail',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                        color: actif ? AppColors.rouge : AppColors.grisDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauAppartements extends StatelessWidget {
  final List<Appartement> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<Appartement> onModifier;
  final ValueChanged<Appartement> onSupprimer;

  const _TableauAppartements({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    Widget entete(String libelle, _Tri t) => _EnTeteTri(
          libelle: libelle,
          actif: tri == t,
          croissant: croissant,
          onTap: () => onTrier(t),
        );

    return CarteContenu(
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                    width: 40, child: Text('N°', style: _styleEnTete)),
                Expanded(flex: 3, child: entete('Appartement', _Tri.numero)),
                Expanded(flex: 2, child: entete('Taille', _Tri.taille)),
                Expanded(flex: 2, child: entete('Durée', _Tri.duree)),
                const Expanded(
                    flex: 2, child: Text('Animal', style: _styleEnTete)),
                const Expanded(
                    flex: 4, child: Text('Notes', style: _styleEnTete)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (final (i, a) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneAppartement(
              appartement: a,
              numero: premierNumero + i,
              onModifier: () => onModifier(a),
              onSupprimer: () => onSupprimer(a),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteTri extends StatelessWidget {
  final String libelle;
  final bool actif;
  final bool croissant;
  final VoidCallback onTap;

  const _EnTeteTri({
    required this.libelle,
    required this.actif,
    required this.croissant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? AppColors.rouge : AppColors.grisDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle, style: _styleEnTete.copyWith(color: couleur)),
              const SizedBox(width: 4),
              Icon(
                !actif
                    ? Icons.swap_vert_rounded
                    : croissant
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                size: 14,
                color: couleur,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneAppartement extends StatelessWidget {
  final Appartement appartement;
  final int numero;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  const _LigneAppartement({
    required this.appartement,
    required this.numero,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final a = appartement;
    const style = TextStyle(fontSize: 13, color: AppColors.noir);
    final notes = a.notes?.trim() ?? '';
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onModifier,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text('$numero', style: style)),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    IconeAppartement(taille: a.taille),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.numero,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BadgeTaille(taille: a.taille),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DureeAppartement(minutes: a.minutesBase),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: a.hasAnimal
                      ? AnimalAppartement(appartement: a)
                      : const Text('—',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.grisText)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  notes.isEmpty ? '—' : notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(
                    color:
                        notes.isEmpty ? AppColors.grisText : AppColors.grisDark,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child:
                    MenuAppartement(onEdit: onModifier, onDelete: onSupprimer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleAppartements extends StatelessWidget {
  final List<Appartement> lignes;
  final ValueChanged<Appartement> onModifier;
  final ValueChanged<Appartement> onSupprimer;

  const _GrilleAppartements({
    required this.lignes,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (320 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final a in lignes)
            SizedBox(
              width: largeur,
              child: AppartementListItem(
                appartement: a,
                onEdit: () => onModifier(a),
                onDelete: () => onSupprimer(a),
              ),
            ),
        ],
      );
    });
  }
}

// ── Dialog formulaire ─────────────────────────────────────

class _FormDialog extends ConsumerWidget {
  final Appartement? appartement;
  const _FormDialog({this.appartement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      appartementsNotifierProvider.select((s) => s.isLoading),
    );

    return AppartementFormWidget(
      appartement: appartement,
      isLoading: isLoading,
      onSave: (numero, taille, minutes, notes, hasAnimal, typeAnimal) async {
        final notifier = ref.read(appartementsNotifierProvider.notifier);
        final bool ok;

        if (appartement == null) {
          ok = await notifier.ajouter(
            numero: numero,
            taille: taille,
            minutesBase: minutes,
            notes: notes,
            hasAnimal: hasAnimal,
            typeAnimal: typeAnimal,
          );
        } else {
          ok = await notifier.modifier(
            id: appartement!.id,
            numero: numero,
            taille: taille,
            minutesBase: minutes,
            notes: notes,
            hasAnimal: hasAnimal,
            typeAnimal: typeAnimal,
          );
        }

        if (!context.mounted) return;
        if (ok) {
          Navigator.of(context).pop();
          NotificationApp.succes(
            context,
            appartement == null
                ? 'L’appartement $numero a été ajouté.'
                : 'L’appartement $numero a été modifié.',
          );
        } else {
          final error = ref.read(appartementsNotifierProvider).error;
          if (error != null) AppFeedback.showError(context, error);
        }
      },
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final VoidCallback onAdd;
  const _EtatVide({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.apartment_rounded,
                size: 48, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          const Text(
            'Aucun appartement',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.sm),
          const Text(
            'Ajoutez les appartements de la résidence\npour préparer le planning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisDark, height: 1.5),
          ),
          const SizedBox(height: AppSizes.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un appartement'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rouge,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
