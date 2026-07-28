import 'package:intl/intl.dart';

class SemaineHelper {
  SemaineHelper._();

  // ── Date de référence fixe ───────────────────────────────
  // Lundi 4 mai 2026 = Semaine 4
  static final DateTime _dateRef = DateTime(2026, 5, 4);
  static const List<int> _cycle = [4, 1, 2, 3];

  // ── Semaine courante (1, 2, 3 ou 4) ─────────────────────
  static int get semaineCourante {
    final diff = _lundiDe(DateTime.now()).difference(_dateRef).inDays;
    final index = (diff / 7).floor();
    final mod = index % 4;
    return _cycle[mod < 0 ? mod + 4 : mod];
  }

  // ── Lundi de la semaine en cours ─────────────────────────
  static DateTime get lundiCourant => _lundiDe(DateTime.now());

  // ── Lundi d'une date quelconque ──────────────────────────
  static DateTime _lundiDe(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // ── Vendredi de la semaine en cours ─────────────────────
  static DateTime get vendrediCourant =>
      lundiCourant.add(const Duration(days: 4));

  // ── Date du lundi pour une semaine donnée ────────────────
  static DateTime lundiPourSemaine(int numeroSemaine) {
    DateTime date = _dateRef;
    while (semainePourDate(date) != numeroSemaine) {
      date = date.add(const Duration(days: 7));
      if (date.difference(DateTime.now()).inDays > 365) break;
    }
    return date;
  }

  // ── Numéro de semaine pour une date donnée ───────────────
  static int semainePourDate(DateTime date) {
    final lundi = _lundiDe(date);
    final diff = lundi.difference(_dateRef).inDays;
    final index = (diff / 7).floor();
    final mod = index % 4;
    return _cycle[mod < 0 ? mod + 4 : mod];
  }

  // ── Libellé affiché : "Semaine 1 — du 11 au 15 mai 2026" ─
  static String get libelleSemaineCourante {
    return _libelle(lundiCourant, semaineCourante);
  }

  static String libellePourDate(DateTime date) {
    final lundi = _lundiDe(date);
    return _libelle(lundi, semainePourDate(date));
  }

  static String _libelle(DateTime lundi, int numeroSemaine) {
    final vendredi = lundi.add(const Duration(days: 4));
    final mois = DateFormat('MMMM', 'fr_FR').format(vendredi);
    return 'Semaine $numeroSemaine — du ${lundi.day} au ${vendredi.day} $mois ${vendredi.year}';
  }

  // ── Liste des 5 jours de la semaine courante ─────────────
  static List<DateTime> get joursDeLaSemaine {
    return List.generate(5, (i) => lundiCourant.add(Duration(days: i)));
  }

  // ── Nom du jour en français ──────────────────────────────
  static String nomJour(DateTime date) {
    return DateFormat('EEEE', 'fr_FR').format(date);
  }

  // ── Format court : "Lun 11" ──────────────────────────────
  static String nomJourCourt(DateTime date) {
    return DateFormat('EEE d', 'fr_FR').format(date);
  }

  // ── Est-ce aujourd'hui ? ─────────────────────────────────
  static bool estAujourdhui(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
