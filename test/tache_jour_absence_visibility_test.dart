import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cleanops/features/appartements/domain/entities/appartement.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/auth/presentation/providers/auth_provider.dart';
import 'package:cleanops/features/presences/domain/entities/presence.dart';
import 'package:cleanops/features/presences/domain/repositories/presence_repository.dart';
import 'package:cleanops/features/presences/presentation/providers/presence_provider.dart';
import 'package:cleanops/features/tache_jour/domain/entities/tache_jour.dart';
import 'package:cleanops/features/tache_jour/domain/repositories/tache_jour_repository.dart';
import 'package:cleanops/features/tache_jour/domain/usecases/get_taches_du_jour.dart';
import 'package:cleanops/features/tache_jour/domain/usecases/update_statut_tache.dart';
import 'package:cleanops/features/tache_jour/presentation/providers/tache_jour_provider.dart';
import 'package:cleanops/features/tache_jour/presentation/screens/tache_jour_screen.dart';
import 'package:cleanops/features/tache_jour/presentation/widgets/tache_card_widget.dart';

// ── Doublures : aucun accès réseau ni Supabase ─────────────
class _RepoTaches implements TacheJourRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RepoPresence implements PresenceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTacheJourNotifier extends TacheJourNotifier {
  _FakeTacheJourNotifier(List<TacheJour> taches, String dateStr)
      : super(
          getTaches: GetTachesDuJour(_RepoTaches()),
          updateStatut: UpdateStatutTache(_RepoTaches()),
          dateStr: dateStr,
        ) {
    state = TacheJourState(taches: taches);
  }

  @override
  Future<void> charger({required String employeeId}) async {}
}

class _FakeMaPresenceNotifier extends MaPresenceNotifier {
  _FakeMaPresenceNotifier(Presence? presence)
      : super(_RepoPresence(), _employeeId) {
    state = PresenceState(maPresence: presence);
  }

  @override
  Future<void> charger(DateTime date) async {}
}

// ── Données ────────────────────────────────────────────────
const _employeeId = 'emp-1';

const _preposee = Employee(
  id: _employeeId,
  nom: 'Test',
  prenom: 'Préposée',
  slug: 'test',
  role: RoleType.employe,
  isActif: true,
);

TacheJour _tache(String id, PeriodeType periode, int numero) => TacheJour(
      id: id,
      employeeId: _employeeId,
      appartementId: 'apt-$numero',
      numeroSemaine: 4,
      semaineReelle: DateTime(2026, 9, 21),
      jour: 'Lundi',
      periode: periode,
      numeroTache: numero,
      statut: StatutTache.nonCommence,
      appartement: Appartement(
        id: 'apt-$numero',
        numero: '30$numero',
        taille: '3½',
        minutesBase: 45,
      ),
    );

final _taches = [
  _tache('am1', PeriodeType.am, 1),
  _tache('am2', PeriodeType.am, 2),
  _tache('pm1', PeriodeType.pm, 3),
  _tache('pm2', PeriodeType.pm, 4),
];

Presence _presence(StatutPresence statut) => Presence(
      id: 'p1',
      employeeId: _employeeId,
      date: DateTime(2026, 9, 21),
      statut: statut,
    );

Future<void> _afficher(
  WidgetTester tester, {
  required Presence? presence,
  required Size taille,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = taille;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        employeeCourantProvider.overrideWithValue(_preposee),
        tacheJourNotifierProvider.overrideWith(
          (ref, dateStr) => _FakeTacheJourNotifier(_taches, dateStr),
        ),
        maPresenceNotifierProvider.overrideWith(
          (ref, employeeId) => _FakeMaPresenceNotifier(presence),
        ),
      ],
      child: const MaterialApp(home: TacheJourScreen(date: '2026-09-21')),
    ),
  );
  // Laisse passer la micro-tâche d'initialisation (chargement du pool, qui
  // échoue sans Supabase et est volontairement ignoré par l'écran).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  const mobile = Size(390, 1200);
  const bureau = Size(1200, 900);

  final absences = <String, StatutPresence>{
    'absente toute la journée': StatutPresence.absent,
    'absente le matin': StatutPresence.absentMatin,
    'absente l\'après-midi': StatutPresence.absentApresMidi,
  };

  for (final entree in absences.entries) {
    for (final layout in {'mobile': mobile, 'bureau': bureau}.entries) {
      testWidgets(
        '${entree.key} (${layout.key}) : toutes ses tâches restent visibles',
        (tester) async {
          await _afficher(
            tester,
            presence: _presence(entree.value),
            taille: layout.value,
          );

          // Les 4 tâches (2 du matin, 2 de l'après-midi) restent affichées.
          expect(find.byType(TacheCardWidget), findsNWidgets(4));
          expect(find.textContaining('Tâches masquées'), findsNothing);
          // Le bandeau explique jusqu'à quand elles restent visibles.
          expect(find.textContaining('restent visibles'), findsOneWidget);
          expect(find.textContaining('Aucune tâche à effectuer'), findsNothing);
        },
      );
    }
  }

  testWidgets('présente : toutes les tâches, sans bandeau d\'absence',
      (tester) async {
    await _afficher(
      tester,
      presence: _presence(StatutPresence.present),
      taille: mobile,
    );

    expect(find.byType(TacheCardWidget), findsNWidgets(4));
    expect(find.textContaining('restent visibles'), findsNothing);
  });

  testWidgets('présence non encore déclarée : toutes les tâches',
      (tester) async {
    await _afficher(tester, presence: null, taille: mobile);

    expect(find.byType(TacheCardWidget), findsNWidgets(4));
    expect(find.textContaining('restent visibles'), findsNothing);
  });
}
