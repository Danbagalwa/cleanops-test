import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/demande_equipe_datasource.dart';
import '../../data/repositories/demande_equipe_repository_impl.dart';
import '../../data/selecteur_document_file_picker.dart';
import '../../data/transfert_document_demande.dart';
import '../../domain/entities/demande_equipe.dart';
import '../../domain/entities/document_demande.dart';
import '../../domain/repositories/demande_equipe_repository.dart';
import '../../domain/selecteur_document.dart';

// ── Infrastructure ────────────────────────────────────────

final demandeEquipeDatasourceProvider = Provider<DemandeEquipeDatasource>(
  (_) => DemandeEquipeDatasourceImpl(),
);

final demandeEquipeRepositoryProvider = Provider<DemandeEquipeRepository>(
  (ref) =>
      DemandeEquipeRepositoryImpl(ref.watch(demandeEquipeDatasourceProvider)),
);

final selecteurDocumentProvider = Provider<SelecteurDocument>(
  (_) => SelecteurDocumentFilePicker(),
);

// ── Côté employé — mes demandes ────────────────────────────

class MesDemandesEquipeState {
  final List<DemandeEquipe> demandes;
  final bool isLoading;
  final bool isSending;

  /// `true` pendant l'envoi du document joint — phase distincte de
  /// [isSending] (la demande elle-même est déjà créée à ce stade), pour que
  /// l'écran puisse afficher un libellé propre à cette étape.
  final bool isUploadingDocument;

  final String? error;

  /// Un avertissement post-envoi (la demande a été créée, mais le document
  /// joint n'a pas pu l'être) : distinct de [error], qui bloque l'envoi.
  final String? avertissement;

  const MesDemandesEquipeState({
    this.demandes = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isUploadingDocument = false,
    this.error,
    this.avertissement,
  });

  MesDemandesEquipeState copyWith({
    List<DemandeEquipe>? demandes,
    bool? isLoading,
    bool? isSending,
    bool? isUploadingDocument,
    String? error,
    bool clearError = false,
    String? avertissement,
    bool clearAvertissement = false,
  }) =>
      MesDemandesEquipeState(
        demandes: demandes ?? this.demandes,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        isUploadingDocument: isUploadingDocument ?? this.isUploadingDocument,
        error: clearError ? null : error ?? this.error,
        avertissement:
            clearAvertissement ? null : avertissement ?? this.avertissement,
      );
}

class MesDemandesEquipeNotifier extends StateNotifier<MesDemandesEquipeState> {
  final DemandeEquipeRepository _repo;
  final String _employeeId;
  final String _employeePrenom;
  final String _employeeNom;

  MesDemandesEquipeNotifier({
    required DemandeEquipeRepository repo,
    required String employeeId,
    required String employeePrenom,
    required String employeeNom,
  })  : _repo = repo,
        _employeeId = employeeId,
        _employeePrenom = employeePrenom,
        _employeeNom = employeeNom,
        super(const MesDemandesEquipeState()) {
    if (employeeId.isNotEmpty) charger();
  }

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getMesDemandes(_employeeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (list) => state = state.copyWith(isLoading: false, demandes: list),
    );
  }

  Future<bool> creerDemande({
    required TypeDemandeEquipe type,
    required DateTime dateDebut,
    DateTime? dateFin,
    required String motif,
    Uint8List? documentOctets,
    String? documentNom,
    String? documentTypeMime,
  }) async {
    state = state.copyWith(
        isSending: true, clearError: true, clearAvertissement: true);
    final result = await _repo.creerDemande(
      employeeId: _employeeId,
      employeePrenom: _employeePrenom,
      employeeNom: _employeeNom,
      type: type,
      dateDebut: dateDebut,
      dateFin: dateFin,
      motif: motif,
    );
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (demande) async {
        state = state.copyWith(demandes: [demande, ...state.demandes]);
        // La demande est créée : le document, s'il y en a un, est un
        // ajout optionnel — son échec ne remet pas en cause l'envoi. On
        // garde isSending actif (avec isUploadingDocument pour le libellé)
        // le temps de cet envoi, pour que l'écran reste occupé jusqu'à ce
        // que tout soit vraiment terminé.
        if (documentOctets != null) {
          state = state.copyWith(isUploadingDocument: true);
          await _joindreDocument(
            demande,
            octets: documentOctets,
            nom: documentNom!,
            typeMime: documentTypeMime!,
          );
        }
        state = state.copyWith(isSending: false, isUploadingDocument: false);
        return true;
      },
    );
  }

  Future<void> _joindreDocument(
    DemandeEquipe demande, {
    required Uint8List octets,
    required String nom,
    required String typeMime,
  }) async {
    final result = await _repo.joindreDocument(
      demandeId: demande.id,
      employeeId: _employeeId,
      nom: nom,
      typeMime: typeMime,
      octets: octets,
    );
    result.fold(
      (f) => state = state.copyWith(
        avertissement:
            "La demande a été envoyée, mais le document n'a pas pu être "
            'joint : ${f.message}',
      ),
      (_) => state = state.copyWith(
        demandes: state.demandes
            .map((d) => d.id == demande.id
                ? d.avecDocument(
                    nom: nom, typeMime: typeMime, taille: octets.length)
                : d)
            .toList(),
      ),
    );
  }

  void viderAvertissement() {
    if (state.avertissement != null) {
      state = state.copyWith(clearAvertissement: true);
    }
  }
}

final mesDemandesEquipeNotifierProvider = StateNotifierProvider.autoDispose<
    MesDemandesEquipeNotifier, MesDemandesEquipeState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return MesDemandesEquipeNotifier(
    repo: ref.watch(demandeEquipeRepositoryProvider),
    employeeId: employee?.id ?? '',
    employeePrenom: employee?.prenom ?? '',
    employeeNom: employee?.nom ?? '',
  );
});

// ── Côté responsable — toutes les demandes ─────────────────

class DemandesEquipeResponsableState {
  final List<DemandeEquipe> demandes;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const DemandesEquipeResponsableState({
    this.demandes = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  List<DemandeEquipe> get enAttente =>
      demandes.where((d) => d.enAttente).toList();
  List<DemandeEquipe> get resolues => demandes.where((d) => d.resolue).toList();
  int get badgeEnAttente => enAttente.length;

  DemandesEquipeResponsableState copyWith({
    List<DemandeEquipe>? demandes,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) =>
      DemandesEquipeResponsableState(
        demandes: demandes ?? this.demandes,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : error ?? this.error,
      );
}

class DemandesEquipeResponsableNotifier
    extends StateNotifier<DemandesEquipeResponsableState> {
  final DemandeEquipeRepository _repo;
  final String _responsableId;

  DemandesEquipeResponsableNotifier(this._repo, this._responsableId)
      : super(const DemandesEquipeResponsableState()) {
    charger();
  }

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getAllDemandes();
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (demandes) =>
          state = state.copyWith(isLoading: false, demandes: demandes),
    );
  }

  /// `approuve` null : marque seulement la demande comme vue (demandes de
  /// type "Autre", qui ne s'approuvent ni ne se refusent).
  Future<bool> traiter({
    required String demandeId,
    required bool? approuve,
    String? note,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    final result = await _repo.traiterDemande(
      demandeId: demandeId,
      traiteParId: _responsableId,
      approuve: approuve,
      note: note,
    );
    return result.fold(
      (f) {
        state = state.copyWith(isSending: false, error: f.message);
        return false;
      },
      (updated) {
        state = state.copyWith(
          isSending: false,
          demandes: state.demandes
              .map((d) => d.id == updated.id ? updated : d)
              .toList(),
        );
        return true;
      },
    );
  }

  /// Met à jour localement une demande après l'envoi de sa preuve de
  /// traitement (sans recharger toute la liste).
  void marquerPreuve(
    String demandeId, {
    required String nom,
    required String typeMime,
    required int taille,
  }) {
    state = state.copyWith(
      demandes: state.demandes
          .map((d) => d.id == demandeId
              ? d.avecPreuve(nom: nom, typeMime: typeMime, taille: taille)
              : d)
          .toList(),
    );
  }
}

final demandesEquipeResponsableProvider = StateNotifierProvider.autoDispose<
    DemandesEquipeResponsableNotifier, DemandesEquipeResponsableState>((ref) {
  final employee = ref.watch(employeeCourantProvider);
  return DemandesEquipeResponsableNotifier(
    ref.watch(demandeEquipeRepositoryProvider),
    employee?.id ?? '',
  );
});

// ── Document joint — lu à la demande (bouton « voir ») ─────

final documentDemandeProvider = FutureProvider.autoDispose
    .family<DocumentDemande, String>((ref, demandeId) async {
  final result =
      await ref.watch(demandeEquipeRepositoryProvider).lireDocument(demandeId);
  return result.fold((f) => throw Exception(f.message), (doc) => doc);
});

// ── Preuve de traitement — lue à la demande (bouton « voir ») ─
final preuveDemandeProvider = FutureProvider.autoDispose
    .family<DocumentDemande, DemandeEquipe>((ref, demande) =>
        ref.watch(transfertDocumentDemandeProvider).lirePreuve(demande));
