import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/espace_barre_mobile.dart';
import '../../../../core/widgets/lecteur_pdf.dart';
import '../../../../core/widgets/mise_en_page.dart';
import '../../domain/entities/demande_equipe.dart';
import '../providers/demande_equipe_provider.dart';

const _sousTitreDocument = 'Document joint à la demande';
const _sousTitrePreuve = 'Preuve de traitement jointe par le responsable';

/// Affiche le document joint à une demande : lecteur PDF de l'app
/// (impression et téléchargement inclus) ou image zoomable. Avec [preuve],
/// affiche la preuve de traitement de cette demande plutôt que son document.
class DocumentDemandeScreen extends ConsumerWidget {
  final String demandeId;
  final String nom;
  final DemandeEquipe? preuve;

  const DocumentDemandeScreen({
    super.key,
    required this.demandeId,
    required this.nom,
    this.preuve,
  });

  static Future<Uint8List> _rien() async => Uint8List(0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = preuve == null
        ? ref.watch(documentDemandeProvider(demandeId))
        : ref.watch(preuveDemandeProvider(preuve!));
    final sousTitre = preuve == null ? _sousTitreDocument : _sousTitrePreuve;

    return async.when(
      loading: () => LecteurPdf(
        titre: nom,
        sousTitre: sousTitre,
        nomFichier: nom,
        chargement: true,
        generer: _rien,
      ),
      error: (e, _) => LecteurPdf(
        titre: nom,
        sousTitre: sousTitre,
        nomFichier: nom,
        erreur: e,
        onReessayer: () => preuve == null
            ? ref.invalidate(documentDemandeProvider(demandeId))
            : ref.invalidate(preuveDemandeProvider(preuve!)),
        generer: _rien,
      ),
      data: (doc) => doc.estPdf
          ? LecteurPdf(
              titre: nom,
              sousTitre: sousTitre,
              nomFichier: doc.nom,
              generer: () async => doc.octets,
            )
          : _VisionneuseImage(
              nom: nom, octets: doc.octets, sousTitre: sousTitre),
    );
  }
}

class _VisionneuseImage extends StatelessWidget {
  final String nom;
  final Uint8List octets;
  final String sousTitre;

  const _VisionneuseImage({
    required this.nom,
    required this.octets,
    required this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final marge = estCompact(context) ? 12.0 : 24.0;
    return PageAvecEnTete(
      enTete: EnTetePage(
        icone: Icons.image_rounded,
        titre: nom,
        sousTitre: sousTitre,
      ),
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(marge, AppSizes.lg, marge, AppSizes.md),
            child: BarreSection(
              titre: 'Image jointe',
              onRetour: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(marge, 0, marge, AppSizes.lg)
                  .plusBarre(context),
              child: CarteContenu(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image.memory(octets)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
