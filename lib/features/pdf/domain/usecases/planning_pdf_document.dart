import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../auth/domain/entities/employee.dart';
import '../../../planning/domain/entities/planning_template.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';
import '../modele_pdf.dart';

class PlanningPdfDocument {
  PlanningPdfDocument._();

  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

  static const _legende =
      'AM : matin · PM : après-midi · Les durées sont les durées de référence '
      'des appartements.';

  static Future<Uint8List> buildTeam({
    required List<Employee> employees,
    required List<PlanningTemplate> templates,
    required int numeroSemaine,
    required String generatedBy,
  }) async {
    final document = await ModelePdf.document(
      titre: 'Planning de l’équipe — Semaine $numeroSemaine',
      auteur: generatedBy,
    );
    // Comme l'écran Planning : seules les préposées ont un planning. Les
    // autres rôles (admin, réception…) donnaient des lignes entièrement vides.
    final preposees = employees
        .where((e) => e.isActif && e.role == RoleType.employe)
        .toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final weekTemplates =
        templates.where((t) => t.numeroSemaine == numeroSemaine).toList();
    final totalMinutes =
        weekTemplates.fold<int>(0, (total, t) => total + t.minutesEstimees);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        header: (context) => ModelePdf.enTete(
          context,
          titre: 'Planning de l’équipe',
          sousTitre: 'Semaine $numeroSemaine · cycle de 4 semaines',
          infos: ModelePdf.infosGeneration(
            generatedBy,
            [('Semaine du cycle', '$numeroSemaine / 4')],
          ),
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Préposées', '${preposees.length}'),
            ('Interventions', '${weekTemplates.length}'),
            ('Temps planifié', ModelePdf.duree(totalMinutes) ?? ModelePdf.vide),
          ]),
          pw.SizedBox(height: 16),
          if (preposees.isEmpty)
            ModelePdf.etatVide('Aucune préposée active à afficher.')
          else
            ModelePdf.tableau(
              entetes: const ['Préposée', ..._jours, 'Total'],
              largeurs: const {
                0: pw.FlexColumnWidth(1.35),
                1: pw.FlexColumnWidth(1.45),
                2: pw.FlexColumnWidth(1.45),
                3: pw.FlexColumnWidth(1.45),
                4: pw.FlexColumnWidth(1.45),
                5: pw.FlexColumnWidth(1.45),
                6: pw.FlexColumnWidth(0.75),
              },
              accentuees: const {0},
              grasses: const {6},
              centrees: const {6},
              taille: 7.5,
              lignes: [
                for (final employee in preposees)
                  () {
                    final siens = weekTemplates
                        .where((t) => t.employeeId == employee.id)
                        .toList();
                    return [
                      employee.nomComplet,
                      for (final jour in _jours) _journeeCompacte(siens, jour),
                      ModelePdf.duree(siens.fold<int>(
                          0, (total, t) => total + t.minutesEstimees)),
                    ];
                  }(),
              ],
            ),
          pw.SizedBox(height: 12),
          ModelePdf.note(_legende),
        ],
      ),
    );

    return document.save();
  }

  static Future<Uint8List> buildEmployee({
    required Employee employee,
    required List<PlanningTemplate> templates,
    int? numeroSemaine,
    required String generatedBy,
  }) async {
    final document = await ModelePdf.document(
      titre: 'Planning — ${employee.nomComplet}',
      auteur: generatedBy,
    );
    final siens = templates
        .where((t) =>
            t.employeeId == employee.id &&
            (numeroSemaine == null || t.numeroSemaine == numeroSemaine))
        .toList();
    final semaines =
        numeroSemaine == null ? const [1, 2, 3, 4] : [numeroSemaine];
    final totalMinutes =
        siens.fold<int>(0, (total, t) => total + t.minutesEstimees);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => ModelePdf.enTete(
          context,
          titre: 'Planning personnel',
          sousTitre: employee.nomComplet,
          infos: [
            ('Préposée', employee.nomComplet),
            ('Poste', employee.role.intitule),
            ('Pointeuse', employee.numeroPointeuse ?? ''),
            ('Édité le', ModelePdf.dateGeneration()),
          ],
        ),
        footer: ModelePdf.piedDePage,
        build: (context) => [
          ModelePdf.chiffresCles([
            ('Semaines', numeroSemaine?.toString() ?? '1 à 4'),
            ('Interventions', '${siens.length}'),
            ('Temps planifié', ModelePdf.duree(totalMinutes) ?? ModelePdf.vide),
          ]),
          pw.SizedBox(height: 16),
          for (final semaine in semaines) ...[
            ModelePdf.titreSection('Semaine $semaine'),
            pw.SizedBox(height: 7),
            _semaineEmploye(
                siens.where((t) => t.numeroSemaine == semaine).toList()),
            pw.SizedBox(height: 16),
          ],
          ModelePdf.note(_legende),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _semaineEmploye(List<PlanningTemplate> templates) {
    if (templates.isEmpty) {
      return ModelePdf.etatVide('Aucune intervention prévue cette semaine.');
    }
    return ModelePdf.tableau(
      entetes: const ['Jour', 'Matin', 'Après-midi', 'Total'],
      largeurs: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(2.6),
        3: pw.FlexColumnWidth(0.75),
      },
      accentuees: const {0},
      grasses: const {3},
      centrees: const {3},
      taille: 8,
      lignes: [
        for (final jour in _jours)
          () {
            final duJour = templates.where((t) => t.jour == jour).toList();
            return [
              jour,
              _interventions(_creneaux(duJour, PeriodeType.am)),
              _interventions(_creneaux(duJour, PeriodeType.pm)),
              ModelePdf.duree(
                  duJour.fold<int>(0, (total, t) => total + t.minutesEstimees)),
            ];
          }(),
      ],
    );
  }

  static List<PlanningTemplate> _creneaux(
    List<PlanningTemplate> templates,
    PeriodeType periode,
  ) =>
      templates.where((t) => t.periode == periode).toList()
        ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

  /// « AM  101, 102 » / « PM  203 » ; `null` (case vide) si rien ce jour-là.
  static String? _journeeCompacte(
      List<PlanningTemplate> templates, String jour) {
    final duJour = templates.where((t) => t.jour == jour).toList();
    final matin = _creneaux(duJour, PeriodeType.am);
    final apresMidi = _creneaux(duJour, PeriodeType.pm);
    return [
      if (matin.isNotEmpty) 'AM  ${matin.map(_numero).join(', ')}',
      if (apresMidi.isNotEmpty) 'PM  ${apresMidi.map(_numero).join(', ')}',
    ].join('\n');
  }

  /// Une ligne par appartement : « 1. App. 101 · 3½ · 45 min » ; `null` si
  /// aucun.
  static String? _interventions(List<PlanningTemplate> templates) {
    if (templates.isEmpty) return null;
    return templates.map((t) {
      final taille = t.appartement?.taille;
      return [
        '${t.numeroTache}. App. ${_numero(t)}',
        if (taille != null && taille.trim().isNotEmpty) taille,
        '${t.minutesEstimees} min',
      ].join(' · ');
    }).join('\n');
  }

  static String _numero(PlanningTemplate t) => t.appartement?.numero ?? '?';
}
