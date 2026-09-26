import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, PostgrestException;

import '../../../core/services/supabase_service.dart';
import '../domain/entities/demande_equipe.dart';
import '../domain/entities/document_demande.dart';
import '../domain/entities/partage_demande.dart';

/// Rappel de progression : octets reçus et taille totale (si connue).
typedef ProgressionTransfert = void Function(int recus, int? total);

/// Adresse publique de l'app web (GitHub Pages, dans le dossier du dépôt),
/// utilisée dans tous les liens partagés (`--dart-define=APP_URL=https://…`
/// pour une autre adresse).
const _urlApp = String.fromEnvironment(
  'APP_URL',
  defaultValue: 'https://danbagalwa.github.io/cleanops-test/',
);

/// Adresse web de [route] dans l'app servie à [base].
///
/// L'app web utilise des adresses « à dièse » : la route va dans le fragment
/// et le DOSSIER de l'app est gardé (`/cleanops-test/` sur GitHub Pages),
/// sans fichier (`index.html`), requête ni ancienne route.
/// `https://danbagalwa.github.io/cleanops-test` + `/partage/x`
/// → `https://danbagalwa.github.io/cleanops-test/#/partage/x`.
/// `null` si [base] n'est pas une adresse web.
@visibleForTesting
String? adresseDansApp(Uri? base, String route) {
  if (base == null ||
      !(base.isScheme('https') || base.isScheme('http')) ||
      base.host.isEmpty) {
    return null;
  }
  final segments = [...base.pathSegments.where((s) => s.isNotEmpty)];
  // Dernier segment avec un point : un fichier (index.html), pas un dossier.
  if (segments.isNotEmpty && segments.last.contains('.')) segments.removeLast();
  final dossier = segments.isEmpty ? '/' : '/${segments.join('/')}/';
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: dossier,
    fragment: route,
  ).toString();
}

/// Schéma des liens qui ouvrent directement l'application mobile
/// (AndroidManifest : cleanops://app ; iOS : CFBundleURLSchemes).
String lienApplicationPartage(String jeton) => 'cleanops://app/partage/$jeton';

/// Accès direct au fichier d'un document joint, en dehors du dépôt : lien de
/// partage (page de l'app ou fichier), téléchargement suivi octet par octet
/// (le téléchargement Storage classique ne donne aucune progression).
class TransfertDocumentDemande {
  /// Même bucket que le dépôt (voir la migration 202609230033) ; le fichier
  /// est rangé sous l'identifiant de la demande.
  static const bucket = 'documents-demandes-equipe';

  /// Durée de validité d'un partage (voir la migration 202609240037).
  static const dureePartage = Duration(days: 7);

  /// Lien signé, valable [validite], vers le fichier rangé à [chemin] :
  /// l'identifiant de la demande pour le document de l'employé,
  /// « preuves/{id} » pour la preuve de traitement.
  Future<String> lien(
    String chemin, {
    Duration validite = dureePartage,
  }) =>
      SupabaseService.client.storage
          .from(bucket)
          .createSignedUrl(chemin, validite.inSeconds);

  /// Contenu de la preuve de traitement de [demande] (visionneuse).
  Future<DocumentDemande> lirePreuve(DemandeEquipe demande) async {
    final octets = await telecharger(demande.cheminPreuve,
        tailleConnue: demande.preuveTaille);
    return DocumentDemande(
      nom: demande.preuveNom ?? 'preuve',
      typeMime: demande.preuveTypeMime ?? 'application/pdf',
      octets: octets,
    );
  }

  /// Joint (ou remplace) la preuve de traitement de [demandeId]. Le fichier
  /// va dans Storage, puis ses métadonnées sont validées et enregistrées ; en
  /// cas d'échec de cette 2e étape, le fichier envoyé est retiré.
  Future<void> joindrePreuve({
    required String demandeId,
    required String responsableId,
    required String nom,
    required String typeMime,
    required Uint8List octets,
  }) async {
    final chemin = 'preuves/$demandeId';
    final stockage = SupabaseService.client.storage.from(bucket);
    try {
      await stockage.uploadBinary(
        chemin,
        octets,
        fileOptions: FileOptions(contentType: typeMime, upsert: true),
      );
    } catch (_) {
      throw const ErreurTransfert('La preuve n’a pas pu être envoyée.');
    }
    try {
      await SupabaseService.client.rpc('enregistrer_preuve_demande', params: {
        'p_demande_id': demandeId,
        'p_responsable_id': responsableId,
        'p_chemin': chemin,
        'p_nom': nom,
      });
    } on PostgrestException catch (e) {
      await _retirer(chemin);
      throw ErreurTransfert(switch (e.code) {
        'P0001' when e.message.isNotEmpty => e.message,
        'PGRST202' =>
          'La preuve de traitement n’est pas encore activée sur le serveur '
              '(migration 202609240038).',
        _ => 'La preuve n’a pas pu être enregistrée.',
      });
    } catch (_) {
      await _retirer(chemin);
      throw const ErreurTransfert('La preuve n’a pas pu être enregistrée.');
    }
  }

  Future<void> _retirer(String chemin) async {
    try {
      await SupabaseService.client.storage.from(bucket).remove([chemin]);
    } catch (_) {
      // Sans conséquence : fichier orphelin invisible sans métadonnées.
    }
  }

  /// Crée un partage de [demande] et renvoie le lien à envoyer : une page de
  /// l'app (document + état + réponse) quand son adresse est connue, sinon le
  /// lien direct du fichier.
  Future<String> creerLienPartage(
      DemandeEquipe demande, String employeeId) async {
    final urlDocument = demande.aDocument ? await lien(demande.id) : null;
    final String jeton;
    try {
      jeton = await SupabaseService.client.rpc(
        'creer_partage_demande',
        params: {
          'p_demande_id': demande.id,
          'p_employee_id': employeeId,
          'p_url_document': urlDocument,
        },
      ) as String;
    } on PostgrestException catch (e) {
      // Migration de partage pas encore appliquée : on garde le lien direct.
      if (urlDocument != null && e.code == 'PGRST202') return urlDocument;
      throw ErreurTransfert(e.code == 'P0001' && e.message.isNotEmpty
          ? e.message
          : 'Le lien de partage n’a pas pu être créé.');
    }
    return lienPagePartage(jeton) ??
        urlDocument ??
        (throw const ErreurTransfert(
            'L’adresse de l’application n’est pas configurée.'));
  }

  /// Adresse de la page /partage/{jeton} dans l'app web PUBLIÉE (APP_URL),
  /// même depuis un test local : un lien « localhost » ne s'ouvrirait que sur
  /// l'ordinateur qui l'a créé. L'adresse courante ne sert que si APP_URL
  /// est vide. `null` si aucune n'est utilisable.
  static String? lienPagePartage(String jeton) {
    final route = '/partage/$jeton';
    return adresseDansApp(Uri.tryParse(_urlApp), route) ??
        (kIsWeb ? adresseDansApp(Uri.base, route) : null);
  }

  /// Lit un partage ; `null` si le lien est inconnu ou expiré.
  Future<PartageDemande?> lirePartage(String jeton) async {
    try {
      final r = await SupabaseService.client
          .rpc('lire_partage_demande', params: {'p_jeton': jeton});
      if (r == null) return null;
      return PartageDemande.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (_) {
      throw const ErreurTransfert(
          'Impossible d’ouvrir ce partage. Vérifiez votre connexion.');
    }
  }

  /// Télécharge le fichier rangé à [chemin] en signalant l'avancement.
  Future<Uint8List> telecharger(
    String chemin, {
    ProgressionTransfert? onProgression,
    int? tailleConnue,
    AnnulationTransfert? annulation,
  }) async =>
      telechargerUrl(
        await lien(chemin, validite: const Duration(minutes: 10)),
        onProgression: onProgression,
        tailleConnue: tailleConnue,
        annulation: annulation,
      );

  /// Télécharge [url] en signalant l'avancement. [annulation] permet
  /// d'interrompre le transfert (le client HTTP est alors fermé).
  Future<Uint8List> telechargerUrl(
    String url, {
    ProgressionTransfert? onProgression,
    int? tailleConnue,
    AnnulationTransfert? annulation,
  }) async {
    final client = http.Client();
    annulation?._client = client;
    try {
      final reponse = await client.send(http.Request('GET', Uri.parse(url)));
      if (reponse.statusCode != 200) {
        throw const ErreurTransfert(
            'Le document est introuvable ou son lien a expiré.');
      }
      final total = reponse.contentLength ?? tailleConnue;
      final octets = BytesBuilder(copy: false);
      var recus = 0;
      onProgression?.call(0, total);
      await for (final morceau in reponse.stream) {
        if (annulation?.annule ?? false) {
          throw const ErreurTransfert('Téléchargement annulé.');
        }
        octets.add(morceau);
        recus += morceau.length;
        onProgression?.call(recus, total);
      }
      return octets.takeBytes();
    } on ErreurTransfert {
      rethrow;
    } catch (_) {
      if (annulation?.annule ?? false) {
        throw const ErreurTransfert('Téléchargement annulé.');
      }
      throw const ErreurTransfert(
          'Le document n’a pas pu être téléchargé. Vérifiez votre connexion.');
    } finally {
      client.close();
    }
  }
}

/// Jeton d'annulation d'un téléchargement en cours.
class AnnulationTransfert {
  bool annule = false;
  http.Client? _client;

  void annuler() {
    annule = true;
    _client?.close();
  }
}

class ErreurTransfert implements Exception {
  final String message;
  const ErreurTransfert(this.message);

  @override
  String toString() => message;
}

final transfertDocumentDemandeProvider =
    Provider<TransfertDocumentDemande>((_) => TransfertDocumentDemande());
