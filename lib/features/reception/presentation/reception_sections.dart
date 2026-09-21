import 'package:flutter/material.dart';

/// Route de l'écran d'accueil (tableau de bord) de la Réception.
const String receptionAccueilRoute = '/reception';

/// Une section de la vue Réception.
///
/// Source UNIQUE des libellés et des routes : le menu, le tableau de bord et
/// le routeur s'en servent, donc ils ne peuvent pas diverger.
class ReceptionSection {
  final String route;
  final String titre;

  /// Libellé court pour la barre du bas (mobile).
  final String libelleCourt;

  /// Ce que la section permettra de faire (description fonctionnelle).
  final String description;

  final IconData icon;
  final IconData iconActive;

  const ReceptionSection({
    required this.route,
    required this.titre,
    required this.libelleCourt,
    required this.description,
    required this.icon,
    required this.iconActive,
  });
}

/// Les 5 sections de la vue Réception, dans l'ordre d'affichage.
const List<ReceptionSection> receptionSections = [
  ReceptionSection(
    route: '/reception/residents',
    titre: 'Résidents',
    libelleCourt: 'Résidents',
    description: 'Rechercher un appartement, consulter le calendrier des '
        'prochains ménages et l\'imprimer.',
    icon: Icons.people_outline_rounded,
    iconActive: Icons.people_rounded,
  ),
  ReceptionSection(
    route: '/reception/equipe',
    titre: 'Équipe',
    libelleCourt: 'Équipe',
    description: 'Voir qui est présent aujourd\'hui et l\'horaire du jour.',
    icon: Icons.group_outlined,
    iconActive: Icons.group_rounded,
  ),
  ReceptionSection(
    route: '/reception/a-aviser',
    titre: 'À aviser',
    libelleCourt: 'À aviser',
    description: 'Les résidents à prévenir : appelé(e), note laissée ou '
        'reporter.',
    icon: Icons.notifications_active_outlined,
    iconActive: Icons.notifications_active_rounded,
  ),
  ReceptionSection(
    route: '/reception/pin',
    titre: 'PIN',
    libelleCourt: 'PIN',
    description: 'Générer ou réinitialiser le PIN d\'un résident.',
    icon: Icons.pin_outlined,
    iconActive: Icons.pin_rounded,
  ),
  ReceptionSection(
    route: '/reception/messages',
    titre: 'Messages transmis',
    libelleCourt: 'Messages',
    description: 'Les messages envoyés à l\'administration et leur statut : '
        'en attente, répondue ou résolue.',
    icon: Icons.forward_to_inbox_outlined,
    iconActive: Icons.forward_to_inbox_rounded,
  ),
];

/// Route de la section Résidents (recherche).
const String receptionResidentsRoute = '/reception/residents';

/// Route de la section Équipe (présence et horaire du jour).
const String receptionEquipeRoute = '/reception/equipe';

/// Route de la section À aviser (résidents sans application à prévenir).
const String receptionAAviserRoute = '/reception/a-aviser';

/// Route de la section PIN (générer ou réinitialiser le PIN d'un résident).
const String receptionPinRoute = '/reception/pin';

/// Modèle de route de la fiche d'un appartement.
const String receptionFichePattern = '/reception/residents/:appartementId';

/// Route de la fiche d'un appartement.
String receptionFicheRoute(String appartementId) =>
    '$receptionResidentsRoute/$appartementId';

/// Vrai pour l'écran d'accueil de la Réception et ses 5 sections, et pour eux
/// seuls. `/receptionniste` ou `/reception-x` ne correspondent pas.
bool estRouteReception(String location) =>
    location == receptionAccueilRoute ||
    location.startsWith('$receptionAccueilRoute/');
