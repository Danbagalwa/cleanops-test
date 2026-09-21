import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/photo_profil_models.dart';
import '../providers/photo_profil_provider.dart';

/// Pastille ronde d'un utilisateur : sa photo de profil s'il en a une, sinon ses
/// initiales. Tant que la photo charge, ou si elle échoue, les initiales restent
/// affichées (jamais de trou ni d'erreur à l'écran).
class AvatarProfil extends ConsumerWidget {
  final ProprietairePhoto proprietaire;
  final String initiales;
  final double rayon;
  final Color couleurFond;
  final Color couleurTexte;

  const AvatarProfil({
    super.key,
    required this.proprietaire,
    required this.initiales,
    this.rayon = 36,
    required this.couleurFond,
    this.couleurTexte = Colors.white,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final octets = ref.watch(photoProfilProvider(proprietaire)).valueOrNull;

    return Semantics(
      label: octets == null ? 'Initiales' : 'Photo de profil',
      child: CircleAvatar(
        radius: rayon,
        backgroundColor: couleurFond,
        foregroundImage: octets == null ? null : MemoryImage(octets),
        child: Text(
          initiales.isEmpty ? '?' : initiales,
          style: TextStyle(
            color: couleurTexte,
            fontSize: rayon * 0.6,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
