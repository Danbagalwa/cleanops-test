import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static String formatDate(DateTime date) =>
      DateFormat('dd MMMM yyyy', 'fr_FR').format(date);

  static String formatDateCourt(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  static String formatHeure(DateTime date) => DateFormat('HH:mm').format(date);

  static String formatDateHeure(DateTime date) =>
      DateFormat('dd MMM à HH:mm', 'fr_FR').format(date);

  // ── Calcul heure estimée à partir de 08h00 ───────────────
  static String heureEstimee(int minutesDepuis8h) {
    final total = 8 * 60 + minutesDepuis8h;
    final h = total ~/ 60;
    final m = total % 60;
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  // ── Total minutes → "2h30" ───────────────────────────────
  static String minutesEnHeures(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}
