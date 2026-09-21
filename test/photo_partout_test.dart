import 'dart:convert';
import 'dart:typed_data';

import 'package:cleanops/core/services/compression_photo.dart';
import 'package:cleanops/features/auth/domain/entities/employee.dart';
import 'package:cleanops/features/chat_groupe/domain/entities/chat_message.dart';
import 'package:cleanops/features/chat_groupe/presentation/widgets/chat_bubble.dart';
import 'package:cleanops/features/employes/presentation/widgets/employe_list_item.dart';
import 'package:cleanops/features/photo_profil/domain/photo_profil_models.dart';
import 'package:cleanops/features/photo_profil/domain/photo_profil_repository.dart';
import 'package:cleanops/features/photo_profil/presentation/providers/photo_profil_provider.dart';
import 'package:cleanops/features/photo_profil/presentation/widgets/avatar_profil.dart';
import 'package:cleanops/features/residents/domain/entities/resident.dart';
import 'package:cleanops/features/residents/presentation/widgets/resident_card.dart';
import 'package:cleanops/features/residents/presentation/widgets/resident_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un PNG 1×1 valide (une vraie image, pour que MemoryImage la décode).
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Ne donne une photo qu'à certains propriétaires, et note les lectures.
class _RepoParProprietaire implements PhotoProfilRepository {
  final Map<ProprietairePhoto, Uint8List> photos;
  final lectures = <ProprietairePhoto>[];
  Object? erreurAuPremierAppel;

  _RepoParProprietaire(this.photos);

  @override
  Future<Uint8List?> lire(ProprietairePhoto proprietaire) async {
    lectures.add(proprietaire);
    if (erreurAuPremierAppel != null) {
      final e = erreurAuPremierAppel!;
      erreurAuPremierAppel = null;
      throw e;
    }
    return photos[proprietaire];
  }

  @override
  Future<void> definir(ProprietairePhoto p, PhotoCompressee c) async {}

  @override
  Future<void> supprimer(ProprietairePhoto p) async {}
}

Future<ProviderContainer> _afficher(
  WidgetTester tester,
  Widget enfant,
  _RepoParProprietaire repo,
) async {
  final container = ProviderContainer(
    overrides: [photoProfilRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: enfant))),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

ImageProvider? _image(WidgetTester tester, {int index = 0}) =>
    tester.widgetList<CircleAvatar>(find.byType(CircleAvatar)).elementAt(index).foregroundImage;

Resident _resident(String id, {String nom = 'Tremblay'}) => Resident(
      id: id,
      appartementId: 'a1',
      nom: nom,
      prenom: 'Jeanne',
      aApplication: false,
      isActif: true,
      dateCreation: DateTime(2026, 1, 1),
      dateMiseAJour: DateTime(2026, 1, 1),
    );

Employee _employe(String id, RoleType role) => Employee(
      id: id,
      nom: 'Dab',
      prenom: 'Nadine',
      slug: 'n$id',
      role: role,
      isActif: true,
    );

void main() {
  group('AvatarProfil (généralisé)', () {
    testWidgets('sans propriétaire : initiales, aucune lecture', (tester) async {
      final repo = _RepoParProprietaire({});
      await _afficher(
        tester,
        const AvatarProfil(
            proprietaire: null, initiales: 'AB', couleurFond: Colors.red),
        repo,
      );
      expect(find.text('AB'), findsOneWidget);
      expect(repo.lectures, isEmpty);
    });

    testWidgets('icône par défaut quand il n\'y a pas de photo', (tester) async {
      await _afficher(
        tester,
        const AvatarProfil(
          proprietaire: ProprietairePhoto(TypeProprietairePhoto.employe, 'e1'),
          initiales: '',
          icone: Icons.person_outline_rounded,
          couleurFond: Colors.red,
        ),
        _RepoParProprietaire({}),
      );
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('taille et graisse du texte respectées', (tester) async {
      await _afficher(
        tester,
        const AvatarProfil(
          proprietaire: null,
          initiales: 'AB',
          couleurFond: Colors.red,
          tailleTexte: 11,
          poidsTexte: FontWeight.w600,
        ),
        _RepoParProprietaire({}),
      );
      final style = tester.widget<Text>(find.text('AB')).style!;
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('la photo d\'un même utilisateur n\'est lue qu\'UNE fois',
        (tester) async {
      const moi = ProprietairePhoto(TypeProprietairePhoto.employe, 'e1');
      final repo = _RepoParProprietaire({moi: _pixel});
      await _afficher(
        tester,
        const Column(children: [
          AvatarProfil(proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
          AvatarProfil(proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
        ]),
        repo,
      );
      expect(repo.lectures.length, 1);
      expect(_image(tester, index: 0), isA<MemoryImage>());
      expect(_image(tester, index: 1), isA<MemoryImage>());
    });

    testWidgets('la photo reste en mémoire quand l\'avatar disparaît puis revient',
        (tester) async {
      const moi = ProprietairePhoto(TypeProprietairePhoto.employe, 'e1');
      final repo = _RepoParProprietaire({moi: _pixel});
      final container = await _afficher(
        tester,
        const AvatarProfil(proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
        repo,
      );
      // Sort de l'écran (défilement d'une liste), puis revient.
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MaterialApp(home: SizedBox())));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AvatarProfil(
                proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
          ),
        ),
      ));
      await tester.pump();
      expect(repo.lectures.length, 1);
    });

    testWidgets('un échec n\'est PAS gardé : il est retenté', (tester) async {
      const moi = ProprietairePhoto(TypeProprietairePhoto.employe, 'e1');
      final repo = _RepoParProprietaire({moi: _pixel})
        ..erreurAuPremierAppel = const ErreurPhoto('Réseau coupé');
      final container = await _afficher(
        tester,
        const AvatarProfil(proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
        repo,
      );
      expect(_image(tester), isNull, reason: 'initiales pendant l\'échec');

      // L'avatar sort de l'écran puis revient : la lecture est refaite.
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MaterialApp(home: SizedBox())));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: AvatarProfil(
                proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(repo.lectures.length, 2);
      expect(_image(tester), isA<MemoryImage>());
    });

    testWidgets('changer de photo (invalidate) recharge la nouvelle',
        (tester) async {
      const moi = ProprietairePhoto(TypeProprietairePhoto.employe, 'e1');
      final repo = _RepoParProprietaire({moi: _pixel});
      final container = await _afficher(
        tester,
        const AvatarProfil(proprietaire: moi, initiales: 'A', couleurFond: Colors.red),
        repo,
      );
      repo.photos.remove(moi);
      container.invalidate(photoProfilProvider(moi));
      await tester.pumpAndSettle();
      expect(repo.lectures.length, 2);
      expect(_image(tester), isNull);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('La photo est utilisée partout où il y avait des initiales', () {
    testWidgets('bulle du chat : photo de l\'auteur du message', (tester) async {
      const auteur = ProprietairePhoto(TypeProprietairePhoto.employe, 'e7');
      final repo = _RepoParProprietaire({auteur: _pixel});
      await _afficher(
        tester,
        ChatBubble(
          message: ChatMessage(
            id: 'm1',
            auteurId: 'e7',
            prenomAuteur: 'Marie',
            message: 'Bonjour',
            dateEnvoi: DateTime(2026, 9, 21, 10),
            isEpingle: false,
            isSupprime: false,
          ),
          isMine: false,
        ),
        repo,
      );
      expect(repo.lectures, [auteur]);
      expect(_image(tester), isA<MemoryImage>());
    });

    testWidgets('liste des employés : un employé, propriétaire « employe »',
        (tester) async {
      const p = ProprietairePhoto(TypeProprietairePhoto.employe, 'e1');
      final repo = _RepoParProprietaire({p: _pixel});
      await _afficher(
        tester,
        EmployeListItem(
          employe: _employe('e1', RoleType.employe),
          onEdit: () {},
          onToggleActif: () {},
        ),
        repo,
      );
      expect(repo.lectures, contains(p));
      expect(_image(tester), isA<MemoryImage>());
    });

    testWidgets('liste des résidents : propriétaire « resident »', (tester) async {
      const p = ProprietairePhoto(TypeProprietairePhoto.resident, 'r1');
      final repo = _RepoParProprietaire({p: _pixel});
      await _afficher(
        tester,
        ResidentListItem(
          resident: _resident('r1'),
          onPin: () {},
          onDesactiver: () {},
          onActiver: () {},
        ),
        repo,
      );
      expect(repo.lectures, contains(p));
      expect(_image(tester), isA<MemoryImage>());
    });

    testWidgets('carte résident : propriétaire « resident »', (tester) async {
      const p = ProprietairePhoto(TypeProprietairePhoto.resident, 'r2');
      final repo = _RepoParProprietaire({p: _pixel});
      await _afficher(
        tester,
        ResidentCard(
          resident: _resident('r2'),
          onAttribuerPin: (_) async => true,
          onDesactiver: () async => true,
          onActiver: () async => true,
        ),
        repo,
      );
      expect(repo.lectures, contains(p));
      expect(_image(tester), isA<MemoryImage>());
    });

    testWidgets('un résident sans photo garde ses initiales', (tester) async {
      final repo = _RepoParProprietaire({});
      await _afficher(
        tester,
        ResidentListItem(
          resident: _resident('r3', nom: 'Gagnon'),
          onPin: () {},
          onDesactiver: () {},
          onActiver: () {},
        ),
        repo,
      );
      expect(find.text('GA'), findsOneWidget);
      expect(_image(tester), isNull);
    });
  });
}
