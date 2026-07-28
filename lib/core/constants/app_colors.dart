import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Couleurs principales Jazz Teasdale ──────────────────
  static const Color rouge = Color.fromARGB(255, 55, 50, 201);
  static const Color rougeFonce = Color.fromARGB(255, 72, 67, 224);
  static const Color rougeLight = Color.fromARGB(255, 82, 85, 244);

  // ── Neutres ─────────────────────────────────────────────
  static const Color noir = Color(0xFF1A1A1A);
  static const Color blanc = Color(0xFFFFFFFF);
  static const Color grisLight = Color(0xFFF5F5F5);
  static const Color grisMedium = Color(0xFFE0E0E0);
  static const Color grisDark = Color(0xFF757575);
  static const Color grisText = Color(0xFF9E9E9E);

  // ── Statuts tâches ───────────────────────────────────────
  static const Color fait = Color(0xFF1A7A3C); // ✅ vert
  static const Color absent = Color(0xFF1A4A7A); // 🚪 bleu
  static const Color refus = Color(0xFFE65100); // 🚫 orange
  static const Color annule = Color(0xFF757575); // ❌ gris
  static const Color nonCommence = Color(0xFFBDBDBD); // ⚪ gris clair

  // ── Accès appartement ────────────────────────────────────
  static const Color autorise = Color(0xFF1A7A3C); // 🟢 vert
  static const Color nonAutorise = Color(0xFFC8102E); // 🔴 rouge
  static const Color aVerifier = Color(0xFFF9A825); // 🟡 jaune

  // ── Fond statuts (versions légères) ─────────────────────
  static const Color faitBg = Color(0xFFEAF5EE);
  static const Color absentBg = Color(0xFFEAF0F8);
  static const Color refusBg = Color(0xFFFBEFE8);
  static const Color annuleBg = Color(0xFFF5F5F5);

  // ── Calendrier mini ─────────────────────────────────────
  static const Color jourVert = Color(0xFF1A7A3C);
  static const Color jourJaune = Color(0xFFF9A825);
  static const Color jourBlanc = Color(0xFFE0E0E0);
}
