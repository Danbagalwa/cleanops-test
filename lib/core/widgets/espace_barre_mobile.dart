import 'package:flutter/widgets.dart';

/// Les pages défilent SOUS un élément en verre fixé en bas (barre d'onglets
/// sur mobile, pied de page sur bureau) pour son effet de réfraction :
/// l'enveloppe de l'app déclare la hauteur de cet élément dans
/// `MediaQuery.padding.bottom`.
///
/// Une zone de défilement dont la marge est fixe ignore cette valeur : son
/// dernier élément resterait caché dessous. Ajouter [plusBarre] à sa marge le
/// rend atteignable.
extension EspaceBarreMobile on EdgeInsets {
  EdgeInsets plusBarre(BuildContext context) =>
      copyWith(bottom: bottom + MediaQuery.paddingOf(context).bottom);
}

/// Élément fixé en bas de page (pagination, zone de saisie) : il se place
/// au-dessus de l'élément en verre au lieu d'être caché dessous.
class AuDessusDeLaBarre extends StatelessWidget {
  final Widget child;

  const AuDessusDeLaBarre({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: child,
      );
}
