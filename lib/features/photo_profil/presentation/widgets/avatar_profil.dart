import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/photo_profil_models.dart';
import '../providers/photo_profil_provider.dart';

/// Pastille ronde d'un utilisateur : sa photo de profil s'il en a une, sinon ses
/// initiales. Tant que la photo charge, ou si elle échoue, les initiales restent
/// affichées (jamais de trou ni d'erreur à l'écran).
class AvatarProfil extends ConsumerWidget {
  /// À qui est l'avatar. `null` : pas de photo possible, seulement les initiales.
  final ProprietairePhoto? proprietaire;
  final String initiales;
  final double rayon;
  final Color couleurFond;
  final Color couleurTexte;

  /// Taille et graisse du texte des initiales (par défaut selon le rayon).
  final double? tailleTexte;
  final FontWeight poidsTexte;

  /// Icône affichée à la place des initiales quand il n'y a pas de photo.
  final IconData? icone;

  const AvatarProfil({
    super.key,
    required this.proprietaire,
    required this.initiales,
    this.rayon = 36,
    required this.couleurFond,
    this.couleurTexte = Colors.white,
    this.tailleTexte,
    this.poidsTexte = FontWeight.w800,
    this.icone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = proprietaire;
    final octets =
        p == null ? null : ref.watch(photoProfilProvider(p)).valueOrNull;

    return Semantics(
      label: octets == null ? 'Initiales' : 'Photo de profil',
      child: CircleAvatar(
        radius: rayon,
        backgroundColor: couleurFond,
        foregroundImage: octets == null ? null : MemoryImage(octets),
        child: icone != null
            ? Icon(icone, size: rayon * 1.15, color: couleurTexte)
            : Text(
                initiales.isEmpty ? '?' : initiales,
                style: TextStyle(
                  color: couleurTexte,
                  fontSize: tailleTexte ?? rayon * 0.6,
                  fontWeight: poidsTexte,
                ),
              ),
      ),
    );
  }
}
