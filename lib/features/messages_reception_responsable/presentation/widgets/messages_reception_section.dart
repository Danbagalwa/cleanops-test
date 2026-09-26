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
import '../../../appartements/presentation/widgets/appartement_list_item.dart'
    show comparerNumeros;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../pdf/domain/usecases/generate_messages_reception_export.dart';
import '../../../pdf/presentation/screens/messages_reception_pdf_preview_screen.dart';
import '../../../reception/domain/reception_messages_models.dart';
import '../../../reception/domain/reception_models.dart' show NatureDemande;
import '../../../reception/domain/reception_residents_repository.dart'
    show ReceptionErreur;
import '../providers/messages_reception_responsable_provider.dart';

enum _Filtre { tous, enAttente, repondues, resolues }

enum _Tri { priorite, envoi, appartement, statut }

IconData _iconeNature(NatureDemande n) => switch (n) {
      NatureDemande.annulation => Icons.event_busy_rounded,
      NatureDemande.reprogrammation => Icons.update_rounded,
      NatureDemande.autre => Icons.chat_bubble_outline_rounded,
    };

Color _couleurNature(NatureDemande n) => switch (n) {
      NatureDemande.annulation => AppColors.refus,
      NatureDemande.reprogrammation => AppColors.rouge,
      NatureDemande.autre => AppColors.absent,
    };

Color _couleurStatut(StatutMessage s) => switch (s) {
      StatutMessage.enAttente => AppColors.aVerifier,
      StatutMessage.repondue => AppColors.rouge,
      StatutMessage.resolue => AppColors.fait,
    };

IconData _iconeStatut(StatutMessage s) => switch (s) {
      StatutMessage.enAttente => Icons.hourglass_top_rounded,
      StatutMessage.repondue => Icons.mark_chat_read_outlined,
      StatutMessage.resolue => Icons.task_alt_rounded,
    };

String _titre(MessageTransmis m) => 'Apt ${m.numero} · ${m.nature.libelle}';

String _envoi(MessageTransmis m) => 'Envoyé le ${m.envoyeLe}'
    '${m.auteurPrenom.isEmpty ? '' : ' par ${m.auteurPrenom}'}';

String _employePrevenu(MessageTransmis m) => m.employePrenom == null
    ? "Transmis aussi à l'employé."
    : "Transmis aussi à l'employé : ${m.employePrenom}.";

bool _aReponse(MessageTransmis m) => m.reponse?.trim().isNotEmpty ?? false;

/// Section « Messages de la réception » de l'écran « Demandes résidents » du
/// responsable : les demandes que la Réception lui transmet parce qu'elle ne peut
/// pas toucher au planning (annuler, reprogrammer…).
///
/// Le responsable y voit le message, y répond (« Répondue » : l'horaire n'a pas
/// changé) et le marque « Résolue » une fois l'horaire réellement modifié. Aucun
/// de ces boutons ne modifie un planning : il le fait lui-même avant de
/// confirmer.
class MessagesReceptionSection extends ConsumerStatefulWidget {
  const MessagesReceptionSection({super.key});

  @override
  ConsumerState<MessagesReceptionSection> createState() =>
      _MessagesReceptionSectionState();
}

class _MessagesReceptionSectionState
    extends ConsumerState<MessagesReceptionSection> {
  _Filtre _filtre = _Filtre.tous;
  NatureDemande? _nature;
  String _recherche = '';
  _Tri _tri = _Tri.priorite;
  bool _croissant = false;
  int _page = 0;
  int _parPage = 10;

  /// `null` : choisi selon la largeur (grille sur téléphone, tableau sinon).
  ModeAffichage? _mode;

  void _recharger() => ref.invalidate(messagesReceptionResponsableProvider);

  void _changer(VoidCallback maj) => setState(() {
        maj();
        _page = 0;
      });

  void _trier(_Tri tri) => _changer(() {
        _croissant = _tri == tri ? !_croissant : tri == _Tri.appartement;
        _tri = tri;
      });

  bool _garde(MessageTransmis m) => switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.enAttente => m.statut == StatutMessage.enAttente,
        _Filtre.repondues => m.statut == StatutMessage.repondue,
        _Filtre.resolues => m.statut == StatutMessage.resolue,
      };

  List<MessageTransmis> _lignes(List<MessageTransmis> tous) {
    final q = _recherche.trim().toLowerCase();
    int parEnvoi(MessageTransmis a, MessageTransmis b) =>
        a.dateCreation.compareTo(b.dateCreation);
    int sens(int c) => _croissant ? c : -c;
    return tous.where((m) {
      if (!_garde(m)) return false;
      if (_nature != null && m.nature != _nature) return false;
      if (q.isEmpty) return true;
      return m.numero.toLowerCase().contains(q) ||
          m.message.toLowerCase().contains(q) ||
          m.auteurPrenom.toLowerCase().contains(q) ||
          (m.reponse?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => switch (_tri) {
            // En attente d'abord, puis répondues, puis résolues ; récents
            // en tête dans chaque groupe.
            _Tri.priorite => a.statut != b.statut
                ? a.statut.index.compareTo(b.statut.index)
                : -parEnvoi(a, b),
            _Tri.envoi => sens(parEnvoi(a, b)),
            _Tri.appartement => sens(comparerNumeros(a.numero, b.numero)),
            _Tri.statut => sens(a.statut.index.compareTo(b.statut.index)),
          });
  }

  String _descriptionFiltres() {
    final f = <String>[
      if (_filtre == _Filtre.enAttente) 'En attente',
      if (_filtre == _Filtre.repondues) 'Répondues',
      if (_filtre == _Filtre.resolues) 'Résolues',
      if (_nature != null) _nature!.libelle,
      if (_recherche.trim().isNotEmpty) '« ${_recherche.trim()} »',
    ];
    return f.isEmpty ? 'Tous les messages' : f.join(' · ');
  }

  // ── Actions ────────────────────────────────────────────

  void _ouvrir(MessageTransmis m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DetailMessage(
        message: m,
        onRepondre: () {
          Navigator.of(ctx).pop();
          _repondre(m);
        },
        onResoudre: () {
          Navigator.of(ctx).pop();
          _resoudre(m);
        },
      ),
    );
  }

  void _repondre(MessageTransmis m) => showDialog<void>(
        context: context,
        builder: (_) => _RepondreDialog(message: m),
      );

  void _resoudre(MessageTransmis m) => showDialog<void>(
        context: context,
        builder: (_) => _ResoudreDialog(message: m),
      );

  void _exporterPdf(List<MessageTransmis> lignes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesReceptionPdfPreviewScreen(
          messages: lignes,
          filtres: _descriptionFiltres(),
          generatedBy:
              ref.read(employeeCourantProvider)?.nomComplet ?? 'CleanOps',
        ),
      ),
    );
  }

  void _exporterExcel(List<MessageTransmis> lignes) {
    try {
      const GenerateMessagesReceptionExcel()(
        messages: lignes,
        filtres: _descriptionFiltres(),
      );
      showExportSuccess(
          context, 'Le suivi Excel des messages a été téléchargé.');
    } catch (error) {
      AppFeedback.showError(context, error);
    }
  }

  // ── Construction ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(messagesReceptionResponsableProvider);
    final compact = estCompact(context);
    final mode =
        compact ? ModeAffichage.grille : (_mode ?? ModeAffichage.tableau);
    final marge = compact ? 12.0 : 24.0;

    final tous = liste.valueOrNull ?? const <MessageTransmis>[];
    final lignes = _lignes(tous);
    final nbPages = lignes.isEmpty ? 1 : ((lignes.length - 1) ~/ _parPage) + 1;
    final page = _page.clamp(0, nbPages - 1);
    final visibles = lignes.skip(page * _parPage).take(_parPage).toList();
    final enAttente =
        tous.where((m) => m.statut == StatutMessage.enAttente).length;
    final chargement = liste.isLoading;

    FiltreSection filtre(_Filtre f, IconData icone, String info,
            {bool pastille = false}) =>
        FiltreSection(
          icone: icone,
          infoBulle: info,
          actif: _filtre == f,
          pastille: pastille,
          onTap: () => _changer(() => _filtre = f),
        );

    final recherche = ChampRecherche(
      indice: 'Rechercher un appartement, un message ou une réponse',
      onChanged: (v) => _changer(() => _recherche = v),
    );

    Widget corps;
    if (liste.hasError && !liste.hasValue) {
      corps = CarteContenu(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: AppErrorNotice(
          error: liste.error.toString(),
          onRetry: _recharger,
        ),
      );
    } else if (!liste.hasValue) {
      corps = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.rouge)),
      );
    } else if (tous.isEmpty) {
      corps = const _EtatVide(
        icone: Icons.forward_to_inbox_outlined,
        titre: 'Aucun message de la réception',
        texte: 'Les demandes que la Réception vous transmet apparaîtront ici.',
      );
    } else if (lignes.isEmpty) {
      corps = _EtatVide(
        icone: Icons.filter_list_off_rounded,
        titre: 'Aucun message ne correspond à ce filtre',
        texte: 'Modifiez les filtres ou la recherche.',
        onToutAfficher: () => _changer(() {
          _filtre = _Filtre.tous;
          _nature = null;
        }),
      );
    } else {
      corps = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == ModeAffichage.tableau)
            _TableauMessages(
              lignes: visibles,
              premierNumero: page * _parPage + 1,
              tri: _tri,
              croissant: _croissant,
              onTrier: _trier,
              onOuvrir: _ouvrir,
              onRepondre: _repondre,
              onResoudre: _resoudre,
            )
          else
            _GrilleMessages(
              lignes: visibles,
              onOuvrir: _ouvrir,
              onRepondre: _repondre,
              onResoudre: _resoudre,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hauteur réservée : l'apparition de la barre ne décale rien.
        SizedBox(
          height: 2,
          child: chargement && liste.hasValue
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.rouge,
                  backgroundColor: Colors.transparent,
                )
              : null,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.rouge,
            onRefresh: () async {
              _recharger();
              await ref.read(messagesReceptionResponsableProvider.future);
            },
            child: ListView(
              padding:
                  EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.lg)
                      .plusBarre(context),
              children: [
                BarreSection(
                  titre: 'Messages (${lignes.length})',
                  onRetour: () =>
                      context.backOrHome(AppRoutes.employerDashboard),
                  filtres: [
                    filtre(_Filtre.tous, Icons.list_alt_rounded,
                        'Tous les messages'),
                    filtre(_Filtre.enAttente, Icons.hourglass_top_rounded,
                        'En attente',
                        pastille: enAttente > 0),
                    filtre(_Filtre.repondues, Icons.mark_chat_read_outlined,
                        'Répondues'),
                    filtre(
                        _Filtre.resolues, Icons.task_alt_rounded, 'Résolues'),
                  ],
                  actions: [
                    ActionSection(
                      icone: Icons.print_rounded,
                      infoBulle: 'Imprimer ou exporter en PDF',
                      onPressed: lignes.isEmpty || chargement
                          ? null
                          : () => _exporterPdf(lignes),
                    ),
                    ActionSection(
                      icone: Icons.download_rounded,
                      infoBulle: 'Télécharger en Excel',
                      onPressed: lignes.isEmpty || chargement
                          ? null
                          : () => _exporterExcel(lignes),
                    ),
                    ActionSection(
                      icone: Icons.refresh_rounded,
                      infoBulle: 'Actualiser',
                      onPressed: chargement ? null : _recharger,
                    ),
                  ],
                ),
                if (tous.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  _FiltreNatures(
                    messages: tous.where(_garde).toList(),
                    selection: _nature,
                    onChanged: (n) => _changer(() => _nature = n),
                  ),
                  const SizedBox(height: AppSizes.md),
                  if (compact)
                    recherche
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
                      ],
                    ),
                ],
                const SizedBox(height: AppSizes.md),
                corps,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filtre par nature (avec effectifs) ─────────────────────

class _FiltreNatures extends StatelessWidget {
  final List<MessageTransmis> messages;
  final NatureDemande? selection;
  final ValueChanged<NatureDemande?> onChanged;

  const _FiltreNatures({
    required this.messages,
    required this.selection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    _TuileNature tuile(NatureDemande? n) {
      final dans =
          n == null ? messages : messages.where((m) => m.nature == n).toList();
      return _TuileNature(
        icone: n == null ? Icons.apps_rounded : _iconeNature(n),
        couleur: n == null ? AppColors.rouge : _couleurNature(n),
        libelle: n == null ? 'Toutes les natures' : n.libelle,
        nombre: dans.length,
        enAttente:
            dans.where((m) => m.statut == StatutMessage.enAttente).length,
        actif: selection == n,
        onTap: () => onChanged(selection == n ? null : n),
      );
    }

    final tuiles = [
      tuile(null),
      for (final n in NatureDemande.values) tuile(n),
    ];

    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      const minimum = 170.0;
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

class _TuileNature extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String libelle;
  final int nombre;
  final int enAttente;
  final bool actif;
  final VoidCallback onTap;

  const _TuileNature({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.nombre,
    required this.enAttente,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 17, color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        if (enAttente > 0) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.aVerifier.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$enAttente en attente',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.aVerifier,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      libelle,
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

// ── Éléments communs ───────────────────────────────────────

class _Pastille extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  const _Pastille(this.icone, this.texte, this.couleur);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                texte,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: couleur),
              ),
            ),
          ],
        ),
      );
}

class _BadgeStatut extends StatelessWidget {
  final StatutMessage statut;
  const _BadgeStatut(this.statut);

  @override
  Widget build(BuildContext context) =>
      _Pastille(_iconeStatut(statut), statut.libelle, _couleurStatut(statut));
}

class _BadgeNature extends StatelessWidget {
  final NatureDemande nature;
  const _BadgeNature(this.nature);

  @override
  Widget build(BuildContext context) =>
      _Pastille(_iconeNature(nature), nature.libelle, _couleurNature(nature));
}

/// Pastille ronde de la nature, en tête des cartes et des dialogues.
class _IconeNature extends StatelessWidget {
  final NatureDemande nature;
  const _IconeNature(this.nature);

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurNature(nature);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconeNature(nature), size: 18, color: couleur),
    );
  }
}

/// « Apt 101 · Annulation » et « Envoyé le … par … ».
class _EnTeteMessage extends StatelessWidget {
  final MessageTransmis message;
  const _EnTeteMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconeNature(message.nature),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _titre(message),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.noir,
                ),
              ),
              Text(
                _envoi(message),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.grisDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Employé prévenu, réponse donnée et résolution.
class _Suivi extends StatelessWidget {
  final MessageTransmis message;
  const _Suivi(this.message);

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.transmisEmploye) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 15, color: AppColors.grisDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _employePrevenu(m),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisDark),
                ),
              ),
            ],
          ),
        ],
        if (_aReponse(m)) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.rouge.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre réponse'
                  '${m.dateReponse == null ? '' : ' · ${MessageTransmis.formater(m.dateReponse!)}'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rouge,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  m.reponse!,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppColors.noir),
                ),
              ],
            ),
          ),
        ],
        if (m.statut == StatutMessage.resolue && m.dateResolution != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.task_alt_rounded,
                  size: 15, color: AppColors.fait),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Résolue le ${MessageTransmis.formater(m.dateResolution!)} : '
                  "l'horaire a été modifié.",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fait,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Boutons « Répondre » / « Modifier la réponse » et « Horaire modifié ».
/// Rien pour un message résolu.
class _Boutons extends StatelessWidget {
  final MessageTransmis message;
  final VoidCallback onRepondre;
  final VoidCallback onResoudre;

  const _Boutons({
    required this.message,
    required this.onRepondre,
    required this.onResoudre,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    const forme = StadiumBorder();
    final repondre = OutlinedButton.icon(
      onPressed: onRepondre,
      icon: const Icon(Icons.reply_rounded, size: 17),
      label: Text(m.statut == StatutMessage.enAttente
          ? 'Répondre'
          : 'Modifier la réponse'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.rouge,
        side: const BorderSide(color: AppColors.rouge),
        shape: forme,
        minimumSize: const Size(0, 42),
      ),
    );
    // « Horaire modifié » n'existe que pour une annulation ou une
    // reprogrammation : une « Autre demande » n'a pas d'horaire.
    if (!m.concerneHoraire) {
      return SizedBox(width: double.infinity, child: repondre);
    }
    return Row(
      children: [
        Expanded(child: repondre),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: onResoudre,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
            label: const Text('Horaire modifié'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.fait,
              shape: forme,
              minimumSize: const Size(0, 42),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tableau ────────────────────────────────────────────────

const _styleEnTete = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.grisDark,
);

class _TableauMessages extends StatelessWidget {
  final List<MessageTransmis> lignes;
  final int premierNumero;
  final _Tri tri;
  final bool croissant;
  final ValueChanged<_Tri> onTrier;
  final ValueChanged<MessageTransmis> onOuvrir;
  final ValueChanged<MessageTransmis> onRepondre;
  final ValueChanged<MessageTransmis> onResoudre;

  const _TableauMessages({
    required this.lignes,
    required this.premierNumero,
    required this.tri,
    required this.croissant,
    required this.onTrier,
    required this.onOuvrir,
    required this.onRepondre,
    required this.onResoudre,
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
                    width: 36, child: Text('N°', style: _styleEnTete)),
                Expanded(flex: 1, child: entete('Apt', _Tri.appartement)),
                const Expanded(
                    flex: 2, child: Text('Nature', style: _styleEnTete)),
                const Expanded(
                    flex: 4, child: Text('Message', style: _styleEnTete)),
                Expanded(flex: 2, child: entete('Envoyé le', _Tri.envoi)),
                Expanded(flex: 2, child: entete('Statut', _Tri.statut)),
                const Expanded(
                    flex: 3, child: Text('Réponse', style: _styleEnTete)),
                const SizedBox(
                  width: 104,
                  child: Text('Actions',
                      textAlign: TextAlign.center, style: _styleEnTete),
                ),
              ],
            ),
          ),
          for (final (i, m) in lignes.indexed) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.grisMedium),
            _LigneMessage(
              message: m,
              numero: premierNumero + i,
              onOuvrir: () => onOuvrir(m),
              onRepondre: () => onRepondre(m),
              onResoudre: () => onResoudre(m),
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
              Flexible(
                child: Text(libelle,
                    overflow: TextOverflow.ellipsis,
                    style: _styleEnTete.copyWith(color: couleur)),
              ),
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

class _LigneMessage extends StatelessWidget {
  final MessageTransmis message;
  final int numero;
  final VoidCallback onOuvrir;
  final VoidCallback onRepondre;
  final VoidCallback onResoudre;

  const _LigneMessage({
    required this.message,
    required this.numero,
    required this.onOuvrir,
    required this.onRepondre,
    required this.onResoudre,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    const style = TextStyle(fontSize: 13, color: AppColors.grisDark);
    final enAttente = m.statut == StatutMessage.enAttente;
    final resolue = m.statut == StatutMessage.resolue;
    return Material(
      color: enAttente
          ? AppColors.aVerifier.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                  width: 36,
                  child: Text('$numero',
                      style: style.copyWith(color: AppColors.noir))),
              Expanded(
                flex: 1,
                child: Text(
                  m.numero,
                  style: style.copyWith(
                      color: AppColors.noir, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeNature(m.nature),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(color: AppColors.noir),
                        ),
                      ),
                      if (m.transmisEmploye)
                        Tooltip(
                          message: _employePrevenu(m),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.badge_outlined,
                                size: 16, color: AppColors.grisDark),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.envoyeLe, style: style),
                    if (m.auteurPrenom.isNotEmpty)
                      Text('par ${m.auteurPrenom}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.grisText)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeStatut(m.statut),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _aReponse(m)
                      ? Text(
                          m.reponse!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        )
                      : const Text('—',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.grisText)),
                ),
              ),
              SizedBox(
                width: 104,
                child: Center(
                  child: resolue
                      ? IconButton(
                          tooltip: 'Voir le détail',
                          onPressed: onOuvrir,
                          icon: const Icon(Icons.visibility_outlined,
                              color: AppColors.rouge),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: enAttente
                                  ? 'Répondre'
                                  : 'Modifier la réponse',
                              onPressed: onRepondre,
                              icon: const Icon(Icons.reply_rounded,
                                  color: AppColors.rouge),
                            ),
                            if (m.concerneHoraire)
                              IconButton(
                                tooltip: 'Horaire modifié',
                                onPressed: onResoudre,
                                icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.fait),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille ─────────────────────────────────────────────────

class _GrilleMessages extends StatelessWidget {
  final List<MessageTransmis> lignes;
  final ValueChanged<MessageTransmis> onOuvrir;
  final ValueChanged<MessageTransmis> onRepondre;
  final ValueChanged<MessageTransmis> onResoudre;

  const _GrilleMessages({
    required this.lignes,
    required this.onOuvrir,
    required this.onRepondre,
    required this.onResoudre,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ecart = AppSizes.sm;
      final colonnes = math.max(1, (c.maxWidth + ecart) ~/ (340 + ecart));
      final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
      return Wrap(
        spacing: ecart,
        runSpacing: ecart,
        children: [
          for (final m in lignes)
            SizedBox(
              width: largeur,
              child: MessageReceptionCard(
                message: m,
                onOuvrir: () => onOuvrir(m),
                onRepondre: () => onRepondre(m),
                onResoudre: () => onResoudre(m),
              ),
            ),
        ],
      );
    });
  }
}

/// Un message de la Réception, avec ses actions pour le responsable.
class MessageReceptionCard extends StatelessWidget {
  final MessageTransmis message;
  final VoidCallback onOuvrir;
  final VoidCallback onRepondre;
  final VoidCallback onResoudre;

  const MessageReceptionCard({
    super.key,
    required this.message,
    required this.onOuvrir,
    required this.onRepondre,
    required this.onResoudre,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final enAttente = m.statut == StatutMessage.enAttente;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enAttente
              ? AppColors.aVerifier.withValues(alpha: 0.6)
              : AppColors.grisMedium,
          width: enAttente ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOuvrir,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _EnTeteMessage(m)),
                    const SizedBox(width: 8),
                    _BadgeStatut(m.statut),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  m.message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppColors.noir),
                ),
                _Suivi(m),
                if (m.statut != StatutMessage.resolue) ...[
                  const SizedBox(height: AppSizes.md),
                  _Boutons(
                    message: m,
                    onRepondre: onRepondre,
                    onResoudre: onResoudre,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Détail d'un message ────────────────────────────────────

class _DetailMessage extends StatelessWidget {
  final MessageTransmis message;
  final VoidCallback onRepondre;
  final VoidCallback onResoudre;

  const _DetailMessage({
    required this.message,
    required this.onRepondre,
    required this.onResoudre,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    return DialogueApp(
      titre: 'Message de la réception',
      largeur: 540,
      libelleAction: 'Fermer',
      onAction: () => Navigator.of(context).pop(),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _EnTeteMessage(m),
          const SizedBox(height: 12),
          Row(
            children: [
              _BadgeStatut(m.statut),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.signification,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grisDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grisLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grisMedium),
            ),
            child: SelectableText(
              m.message,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.4, color: AppColors.noir),
            ),
          ),
          _Suivi(m),
          if (m.statut != StatutMessage.resolue) ...[
            const SizedBox(height: 18),
            _Boutons(
              message: m,
              onRepondre: onRepondre,
              onResoudre: onResoudre,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Rappel du message dans les dialogues d'action ──────────

class _Rappel extends StatelessWidget {
  final MessageTransmis message;
  const _Rappel(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grisLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grisMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnTeteMessage(message),
          const SizedBox(height: 8),
          Text(
            message.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: AppColors.noir),
          ),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  const _Erreur(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.refus.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.refus.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.refus),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.refus,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Répondre ──────────────────────────────────────────────

class _RepondreDialog extends ConsumerStatefulWidget {
  final MessageTransmis message;

  const _RepondreDialog({required this.message});

  @override
  ConsumerState<_RepondreDialog> createState() => _RepondreDialogState();
}

class _RepondreDialogState extends ConsumerState<_RepondreDialog> {
  static const _longueurMax = 2000;

  late final TextEditingController _ctrl =
      TextEditingController(text: widget.message.reponse ?? '');
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valide => _ctrl.text.trim().isNotEmpty && !_envoi;

  Future<void> _envoyer() async {
    final auteur = ref.read(employeeCourantProvider);
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await ref.read(messagesReceptionResponsableRepositoryProvider).repondre(
            messageId: widget.message.id,
            auteurId: auteur.id,
            reponse: _ctrl.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(messagesReceptionResponsableProvider);
      Navigator.of(context).pop();
      NotificationApp.succes(context, 'Réponse enregistrée.');
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final modification = m.statut == StatutMessage.repondue;

    return DialogueApp(
      titre: modification ? 'Modifier la réponse' : 'Répondre',
      largeur: 500,
      libelleAction: 'Envoyer la réponse',
      libelleSecondaire: 'Annuler',
      enCours: _envoi,
      onAction: _valide ? _envoyer : null,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rappel(m),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            enabled: !_envoi,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: _longueurMax,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Votre réponse',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.grisDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.concerneHoraire
                      ? 'La Réception verra cette réponse. Le message passe à '
                          "« Répondue » (l'horaire n'a pas changé). Utilisez "
                          '« Horaire modifié » une fois le planning changé.'
                      : 'La Réception verra cette réponse. Le message passe à '
                          '« Répondue ».',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grisDark, height: 1.4),
                ),
              ),
            ],
          ),
          if (_erreur != null) _Erreur(_erreur!),
        ],
      ),
    );
  }
}

// ── Résoudre ──────────────────────────────────────────────

class _ResoudreDialog extends ConsumerStatefulWidget {
  final MessageTransmis message;

  const _ResoudreDialog({required this.message});

  @override
  ConsumerState<_ResoudreDialog> createState() => _ResoudreDialogState();
}

class _ResoudreDialogState extends ConsumerState<_ResoudreDialog> {
  bool _envoi = false;
  String? _erreur;

  Future<void> _confirmer() async {
    final auteur = ref.read(employeeCourantProvider);
    if (auteur == null) {
      setState(() => _erreur = 'Votre session a expiré. Reconnectez-vous.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await ref.read(messagesReceptionResponsableRepositoryProvider).resoudre(
            messageId: widget.message.id,
            auteurId: auteur.id,
          );
      if (!mounted) return;
      ref.invalidate(messagesReceptionResponsableProvider);
      Navigator.of(context).pop();
      NotificationApp.succes(context, 'Message marqué comme résolu.');
    } on ReceptionErreur catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogueApp(
      titre: 'Horaire modifié ?',
      largeur: 460,
      libelleAction: 'Confirmer',
      libelleSecondaire: 'Annuler',
      enCours: _envoi,
      onAction: _confirmer,
      contenu: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rappel(widget.message),
          const SizedBox(height: 14),
          const Text(
            'Confirmez que le planning a bien été modifié. Le message passera '
            "à « Résolue » et la Réception verra que l'horaire a changé.",
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.noir),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.aVerifier.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border:
                  Border.all(color: AppColors.aVerifier.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.aVerifier),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cette action ne modifie pas le planning : faites-le avant.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.35, color: AppColors.noir),
                  ),
                ),
              ],
            ),
          ),
          if (_erreur != null) _Erreur(_erreur!),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String texte;
  final VoidCallback? onToutAfficher;

  const _EtatVide({
    required this.icone,
    required this.titre,
    required this.texte,
    this.onToutAfficher,
  });

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
            child: Icon(icone, size: 44, color: AppColors.rouge),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.noir),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grisText, fontSize: 13),
          ),
          if (onToutAfficher != null) ...[
            const SizedBox(height: AppSizes.md),
            OutlinedButton.icon(
              onPressed: onToutAfficher,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Tout afficher'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rouge,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
