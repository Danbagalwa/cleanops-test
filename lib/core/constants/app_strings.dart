class AppStrings {
  AppStrings._();

  // ── App ─────────────────────────────────────────────────
  static const String appName = 'Lili Connect';
  static const String slogan = 'Pour la gestion efficace de vos equipes.';

  // ── Auth ────────────────────────────────────────────────
  static const String entrerPin = 'Entrez votre code PIN';
  static const String pinInvalide = 'Code PIN incorrect';
  static const String connexion = 'Connexion';
  static const String deconnexion = 'Déconnexion';

  // ── Statuts ─────────────────────────────────────────────
  static const String fait = 'Fait';
  static const String absent = 'Absent';
  static const String refus = 'Refus';
  static const String annule = 'Annulé';
  static const String nonCommence = 'Non commencé';

  // ── Accès ───────────────────────────────────────────────
  static const String autorise = 'Autorisé';
  static const String nonAutorise = 'Non-autorisé';
  static const String aVerifier = 'À vérifier';

  // ── Jours ───────────────────────────────────────────────
  static const List<String> jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
  ];

  // ── Navigation ──────────────────────────────────────────
  static const String maJournee = 'Ma Journée';
  static const String maSemaine = 'Ma Semaine';
  static const String memoPrive = 'Mémo';
  static const String chatGroupe = 'Chat Équipe';
  static const String parametres = 'Paramètres';

  // ── Erreurs ─────────────────────────────────────────────
  static const String erreurReseau = 'Erreur de connexion réseau';
  static const String erreurServeur = 'Erreur serveur — réessayez';
  static const String erreurDoublon = 'Cet appartement est déjà assigné';
  static const String erreurInconnu = 'Une erreur est survenue';

  // ── Messages semaine prédéfinis ──────────────────────────
  static const List<String> messagesPredefinis = [
    'Bonne semaine à toute l\'équipe ! 💪',
    'Merci pour votre travail quotidien 🙏',
    'Bravo pour vos efforts de chaque jour ⭐',
    'Restons motivés et unis ! 🤝',
    'Bonne année à toute l\'équipe ! 🎊',
    'Joyeuses Pâques à tous ! 🐣',
    'Bonne fête nationale du Québec ! 🎉',
    'Bonne fête du Canada à toute l\'équipe ! 🍁',
    'Bonne fête du Travail à tous ! 👷',
    'Joyeux Noël à toute l\'équipe ! 🎄',
    'Félicitations à toute l\'équipe ! 🏆',
    'Bon courage pour cette nouvelle semaine ! ☀️',
  ];
}
