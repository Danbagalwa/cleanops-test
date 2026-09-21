/// Ne garde que les ménages effectués À PARTIR de la date d'arrivée du résident.
///
/// Un nouveau résident ne voit jamais les ménages faits avant son arrivée (ceux
/// de l'ancien occupant de l'appartement). `dateArrivee` est au format
/// « AAAA-MM-JJ » ; `null` (résident existant, arrivé avant cette règle) ne
/// restreint rien. Le jour d'arrivée lui-même est inclus.
///
/// Les dates ISO « AAAA-MM-JJ » se comparent correctement comme du texte.
List<Map<String, dynamic>> menagesDepuisArrivee(
  List<Map<String, dynamic>> menages,
  String? dateArrivee,
) {
  if (dateArrivee == null || dateArrivee.isEmpty) return menages;
  final debut = dateArrivee.length >= 10 ? dateArrivee.substring(0, 10) : dateArrivee;
  return [
    for (final m in menages)
      if (((m['semaine_reelle'] as String?) ?? '').compareTo(debut) >= 0) m,
  ];
}
