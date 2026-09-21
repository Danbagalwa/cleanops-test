import 'dart:convert';
import 'dart:typed_data';

import '../../auth/domain/entities/employee.dart';

/// Type d'utilisateur qui possède une photo de profil. Les employés (de tout
/// rôle) et les résidents n'ont pas la même table en base : l'identifiant seul
/// ne suffit pas à les distinguer.
enum TypeProprietairePhoto {
  employe,
  resident;

  /// Valeur attendue par le serveur.
  String get code => switch (this) {
        TypeProprietairePhoto.employe => 'employe',
        TypeProprietairePhoto.resident => 'resident',
      };
}

/// À qui appartient une photo de profil.
class ProprietairePhoto {
  final TypeProprietairePhoto type;
  final String id;

  const ProprietairePhoto(this.type, this.id);

  /// Le propriétaire d'une session : un résident se connecte lui aussi comme un
  /// `Employee`, avec le rôle « résident » et son propre identifiant.
  factory ProprietairePhoto.de(Employee utilisateur) => ProprietairePhoto(
        utilisateur.role == RoleType.resident
            ? TypeProprietairePhoto.resident
            : TypeProprietairePhoto.employe,
        utilisateur.id,
      );

  // Égalité par valeur : clé d'un fournisseur `family`.
  @override
  bool operator ==(Object other) =>
      other is ProprietairePhoto && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Décode la photo renvoyée par le serveur : du base64, éventuellement coupé en
/// lignes. `null` s'il n'y a rien (pas de photo). Lève une [FormatException] si
/// le contenu n'est pas du base64 valide.
Uint8List? octetsDepuisBase64(String? base64) {
  if (base64 == null) return null;
  final propre = base64.replaceAll(RegExp(r'\s'), '');
  if (propre.isEmpty) return null;
  return base64Decode(propre);
}
