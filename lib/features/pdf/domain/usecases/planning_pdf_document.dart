import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../auth/domain/entities/employee.dart';
import '../../../planning/domain/entities/planning_template.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

class PlanningPdfDocument {
  PlanningPdfDocument._();

  static const _jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
  ];

  static final _primary = PdfColor.fromHex('#3732C9');
  static final _primaryLight = PdfColor.fromHex('#EEF0FF');
  static final _border = PdfColor.fromHex('#D9DDE7');
  static final _muted = PdfColor.fromHex('#667085');
  static final _background = PdfColor.fromHex('#F7F8FA');

  static Future<Uint8List> buildTeam({
    required List<Employee> employees,
    required List<PlanningTemplate> templates,
    required int numeroSemaine,
    required String generatedBy,
  }) async {
    final document = pw.Document(
      title: 'Planning équipe - Semaine $numeroSemaine',
      author: generatedBy,
      creator: 'CleanOps',
    );
    final activeEmployees = employees.where((employee) => employee.isActif).toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));
    final weekTemplates = templates
        .where((template) => template.numeroSemaine == numeroSemaine)
        .toList();
    final totalMinutes = weekTemplates.fold<int>(
      0,
      (total, template) => total + template.minutesEstimees,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 34),
        header: (context) => _header(
          title: 'Planning de l’équipe',
          subtitle: 'Semaine $numeroSemaine · cycle de 4 semaines',
        ),
        footer: _footer,
        build: (context) => [
          _summary([
            ('Employés', '${activeEmployees.length}'),
            ('Interventions', '${weekTemplates.length}'),
            ('Temps planifié', _duration(totalMinutes)),
          ]),
          pw.SizedBox(height: 18),
          if (activeEmployees.isEmpty)
            _emptyState('Aucun employé actif à afficher.')
          else
            _teamTable(activeEmployees, weekTemplates),
          pw.SizedBox(height: 16),
          _legend(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(DateTime.now())}'
            ' par $generatedBy',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
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
    final document = pw.Document(
      title: 'Planning - ${employee.nomComplet}',
      author: generatedBy,
      creator: 'CleanOps',
    );
    final employeeTemplates = templates
        .where(
          (template) =>
              template.employeeId == employee.id &&
              (numeroSemaine == null ||
                  template.numeroSemaine == numeroSemaine),
        )
        .toList();
    final weeks = numeroSemaine == null
        ? const [1, 2, 3, 4]
        : <int>[numeroSemaine];
    final totalMinutes = employeeTemplates.fold<int>(
      0,
      (total, template) => total + template.minutesEstimees,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 34),
        header: (context) => _header(
          title: 'Planning personnel',
          subtitle: employee.nomComplet,
        ),
        footer: _footer,
        build: (context) => [
          _employeeIdentity(employee),
          pw.SizedBox(height: 14),
          _summary([
            ('Semaines', numeroSemaine?.toString() ?? '1 à 4'),
            ('Interventions', '${employeeTemplates.length}'),
            ('Temps planifié', _duration(totalMinutes)),
          ]),
          pw.SizedBox(height: 18),
          ...weeks.expand((week) {
            final items = employeeTemplates
                .where((template) => template.numeroSemaine == week)
                .toList();
            return [
              _sectionTitle('Semaine $week'),
              pw.SizedBox(height: 7),
              _employeeWeekTable(items),
              pw.SizedBox(height: 18),
            ];
          }),
          _legend(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(DateTime.now())}'
            ' par $generatedBy',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header({
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 34,
            height: 34,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _primary,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Text(
              'C',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
          pw.Text(
            'CLEANOPS',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} / ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: _muted),
      ),
    );
  }

  static pw.Widget _summary(List<(String, String)> values) {
    return pw.Row(
      children: values.map((value) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: pw.BoxDecoration(
              color: _background,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  value.$1,
                  style: pw.TextStyle(fontSize: 8, color: _muted),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  value.$2,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _teamTable(
    List<Employee> employees,
    List<PlanningTemplate> templates,
  ) {
    final rows = employees.map((employee) {
      final employeeTemplates = templates
          .where((template) => template.employeeId == employee.id)
          .toList();
      return <pw.Widget>[
        _cell(
          employee.nomComplet,
          bold: true,
          color: _primary,
        ),
        ..._jours.map(
          (jour) => _cell(_compactDay(employeeTemplates, jour)),
        ),
        _cell(
          _duration(
            employeeTemplates.fold<int>(
              0,
              (total, template) => total + template.minutesEstimees,
            ),
          ),
          bold: true,
          align: pw.TextAlign.center,
        ),
      ];
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.35),
        1: pw.FlexColumnWidth(1.45),
        2: pw.FlexColumnWidth(1.45),
        3: pw.FlexColumnWidth(1.45),
        4: pw.FlexColumnWidth(1.45),
        5: pw.FlexColumnWidth(1.45),
        6: pw.FlexColumnWidth(0.7),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primary),
          children: [
            _headerCell('Employé'),
            ..._jours.map(_headerCell),
            _headerCell('Total'),
          ],
        ),
        ...rows.asMap().entries.map(
              (entry) => pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: entry.key.isOdd ? _background : PdfColors.white,
                ),
                children: entry.value,
              ),
            ),
      ],
    );
  }

  static pw.Widget _employeeWeekTable(List<PlanningTemplate> templates) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(2.6),
        3: pw.FlexColumnWidth(0.75),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primary),
          children: [
            _headerCell('Jour'),
            _headerCell('Matin'),
            _headerCell('Après-midi'),
            _headerCell('Total'),
          ],
        ),
        ..._jours.asMap().entries.map((entry) {
          final dayItems = templates
              .where((template) => template.jour == entry.value)
              .toList();
          final morning = dayItems
              .where((template) => template.periode == PeriodeType.am)
              .toList()
            ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
          final afternoon = dayItems
              .where((template) => template.periode == PeriodeType.pm)
              .toList()
            ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
          final minutes = dayItems.fold<int>(
            0,
            (total, template) => total + template.minutesEstimees,
          );

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: entry.key.isOdd ? _background : PdfColors.white,
            ),
            children: [
              _cell(entry.value, bold: true, color: _primary),
              _cell(_detailedTasks(morning)),
              _cell(_detailedTasks(afternoon)),
              _cell(
                _duration(minutes),
                bold: true,
                align: pw.TextAlign.center,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _employeeIdentity(Employee employee) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _primaryLight,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  employee.nomComplet,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  employee.role.label,
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
          if (employee.numeroPointeuse?.isNotEmpty ?? false)
            pw.Text(
              'N° ${employee.numeroPointeuse}',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String value) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 16, color: _primary),
        pw.SizedBox(width: 7),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _legend() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _background,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'AM : matin · PM : après-midi · Les durées affichées sont les durées '
        'de référence des appartements.',
        style: pw.TextStyle(fontSize: 8, color: _muted),
      ),
    );
  }

  static pw.Widget _emptyState(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(24),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _background,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(fontSize: 10, color: _muted),
      ),
    );
  }

  static pw.Widget _headerCell(String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      alignment: pw.Alignment.center,
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String value, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          lineSpacing: 1.5,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _compactDay(
    List<PlanningTemplate> templates,
    String jour,
  ) {
    final morning = templates
        .where(
          (template) =>
              template.jour == jour && template.periode == PeriodeType.am,
        )
        .toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
    final afternoon = templates
        .where(
          (template) =>
              template.jour == jour && template.periode == PeriodeType.pm,
        )
        .toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
    if (morning.isEmpty && afternoon.isEmpty) return '—';

    final lines = <String>[];
    if (morning.isNotEmpty) {
      lines.add('AM  ${morning.map(_apartmentNumber).join(', ')}');
    }
    if (afternoon.isNotEmpty) {
      lines.add('PM  ${afternoon.map(_apartmentNumber).join(', ')}');
    }
    return lines.join('\n');
  }

  static String _detailedTasks(List<PlanningTemplate> templates) {
    if (templates.isEmpty) return '—';
    return templates.map((template) {
      final size = template.appartement?.taille;
      final details = [
        if (size != null && size.isNotEmpty) size,
        '${template.minutesEstimees} min',
      ].join(' · ');
      return '${template.numeroTache}. App. ${_apartmentNumber(template)} · $details';
    }).join('\n');
  }

  static String _apartmentNumber(PlanningTemplate template) {
    return template.appartement?.numero ?? 'Non renseigné';
  }

  static String _duration(int minutes) {
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '$remaining min';
    if (remaining == 0) return '${hours}h';
    return '${hours}h${remaining.toString().padLeft(2, '0')}';
  }
}
