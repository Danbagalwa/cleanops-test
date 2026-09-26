import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/compression_photo.dart';
import '../../domain/photo_profil_models.dart';
import '../../domain/selecteur_image.dart';
import '../providers/photo_profil_provider.dart';
import 'avatar_profil.dart';
import 'package:cleanops/core/widgets/notification_app.dart';

/// Avatar d'un utilisateur avec un bouton pour changer sa photo de profil.
///
/// Parcours : choisir une image (galerie, ou appareil photo sur mobile) → elle est
/// RÉDUITE (carré de 320 px sous 40 Ko) → aperçu avec la taille obtenue →
/// enregistrement. On peut aussi supprimer la photo. L'utilisateur voit ce qui
/// sera enregistré avant de confirmer.
class PhotoProfilEditeur extends ConsumerStatefulWidget {
  final ProprietairePhoto proprietaire;
  final String initiales;
  final double rayon;
  final Color couleurFond;
  final Color couleurTexte;

  const PhotoProfilEditeur({
    super.key,
    required this.proprietaire,
    required this.initiales,
    this.rayon = 36,
    required this.couleurFond,
    this.couleurTexte = Colors.white,
  });

  @override
  ConsumerState<PhotoProfilEditeur> createState() => _PhotoProfilEditeurState();
}

class _PhotoProfilEditeurState extends ConsumerState<PhotoProfilEditeur> {
  bool _occupe = false;

  /// L'appareil photo n'est proposé que sur un téléphone ou une tablette.
  bool get _appareilDisponible =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _aUnePhoto =>
      ref.read(photoProfilProvider(widget.proprietaire)).valueOrNull != null;

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    erreur
        ? NotificationApp.erreur(context, texte)
        : NotificationApp.succes(context, texte);
  }

  Future<void> _ouvrirMenu() async {
    if (_occupe) return;
    final choix = await showModalBottomSheet<_Choix>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, _Choix.galerie),
            ),
            if (_appareilDisponible)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, _Choix.appareil),
              ),
            if (_aUnePhoto)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline_rounded, color: AppColors.refus),
                title: const Text('Supprimer la photo'),
                onTap: () => Navigator.pop(context, _Choix.supprimer),
              ),
          ],
        ),
      ),
    );

    switch (choix) {
      case _Choix.galerie:
        await _choisir(SourcePhoto.galerie);
      case _Choix.appareil:
        await _choisir(SourcePhoto.appareil);
      case _Choix.supprimer:
        await _supprimer();
      case null:
        break;
    }
  }

  Future<void> _choisir(SourcePhoto source) async {
    setState(() => _occupe = true);
    try {
      final octets = await ref.read(selecteurImageProvider).choisir(source);
      if (octets == null) return; // annulé

      final photo = await ref.read(compressionPhotoProvider)(octets);
      if (!mounted) return;
      setState(() => _occupe = false);

      final confirme = await showDialog<bool>(
        context: context,
        builder: (_) => _ApercuDialog(photo: photo, remplace: _aUnePhoto),
      );
      if (confirme != true || !mounted) return;

      setState(() => _occupe = true);
      await ref
          .read(photoProfilRepositoryProvider)
          .definir(widget.proprietaire, photo);
      ref.invalidate(photoProfilProvider(widget.proprietaire));
      _message('Photo de profil mise à jour.');
    } on ErreurPhoto catch (e) {
      _message(e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _supprimer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la photo de profil ?'),
        content: const Text('Vos initiales s\'afficheront à la place.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.refus),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _occupe = true);
    try {
      await ref.read(photoProfilRepositoryProvider).supprimer(widget.proprietaire);
      ref.invalidate(photoProfilProvider(widget.proprietaire));
      _message('Photo supprimée.');
    } on ErreurPhoto catch (e) {
      _message(e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diametre = widget.rayon * 2;

    return SizedBox(
      width: diametre,
      height: diametre,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarProfil(
            proprietaire: widget.proprietaire,
            initiales: widget.initiales,
            rayon: widget.rayon,
            couleurFond: widget.couleurFond,
            couleurTexte: widget.couleurTexte,
          ),
          if (_occupe)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _occupe ? null : _ouvrirMenu,
                child: Tooltip(
                  message: 'Modifier la photo',
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: widget.rayon * 0.45 < 14 ? 14 : widget.rayon * 0.45,
                      color: AppColors.rouge,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Choix { galerie, appareil, supprimer }

/// Aperçu de la photo RÉDUITE, avec la taille obtenue, avant d'enregistrer.
class _ApercuDialog extends StatelessWidget {
  final PhotoCompressee photo;
  final bool remplace;

  const _ApercuDialog({required this.photo, required this.remplace});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Votre nouvelle photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 80,
            backgroundColor: AppColors.grisLight,
            backgroundImage: MemoryImage(photo.octets),
          ),
          const SizedBox(height: 16),
          Text(
            'Photo optimisée : ${photo.resume}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.grisDark),
          ),
          if (remplace) ...[
            const SizedBox(height: 8),
            const Text(
              'Elle remplacera votre photo actuelle.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.rouge),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
