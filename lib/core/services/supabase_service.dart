import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class SupabaseService {
  SupabaseService._();

  static final Logger _log = Logger();

  // ── Client global ────────────────────────────────────────
  static SupabaseClient get client => Supabase.instance.client;

  // ── Initialisation (appelée dans main.dart) ───────────────
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey, debug: false);
    _log.i('Supabase initialisé ✅');
  }

  // ── Raccourcis tables ────────────────────────────────────
  static SupabaseQueryBuilder table(String name) => client.from(name);

  // ── Realtime ─────────────────────────────────────────────
  static RealtimeChannel channel(String name) => client.channel(name);

  // ── Noms des tables ──────────────────────────────────────
  static const String employees = 'employees';
  static const String appartements = 'appartements';
  static const String planningTemplates = 'planning_templates';
  static const String tachesJour = 'taches_jour';
  static const String transferts = 'transferts';
  static const String presences = 'presences';
  static const String tachesDisponibles = 'taches_disponibles';
  static const String memos = 'memos';
  static const String chatGroupe = 'chat_groupe';
  static const String messagesSemaine = 'messages_semaine';
  static const String notifications = 'notifications';
  static const String notificationsResidents = 'notifications_residents';
  static const String residents = 'residents';
  static const String historiqueActions = 'historique_actions';
  static const String config = 'config';
  static const String sessions = 'sessions';
  static const String tachesAireCommune = 'taches_aire_commune';
  static const String resetsAireCommune = 'resets_aire_commune';
  static const String demandesResidents = 'demandes_residents';
}
