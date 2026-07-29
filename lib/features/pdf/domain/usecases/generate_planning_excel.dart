import 'package:excel/excel.dart';

import '../../../auth/domain/entities/employee.dart';
import '../../../planning/domain/entities/planning_template.dart';
import '../../../tache_jour/domain/entities/tache_jour.dart';

class GeneratePlanningExcel {
  const GeneratePlanningExcel();

  static const _jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
  ];

  void team({
    required List<Employee> employees,
    required List<PlanningTemplate> templates,
    required int numeroSemaine,
  }) {
    final excel = Excel.createExcel();
    final sheetName = 'Planning équipe S$numeroSemaine';
    final sheet = excel[sheetName];
    excel.delete('Sheet1');
    excel.setDefaultSheet(sheetName);

    sheet.appendRow([
      TextCellValue('Employé'),
      ..._jours.map(TextCellValue.new),
      TextCellValue('Total minutes'),
    ]);

    final activeEmployees = employees.where((employee) => employee.isActif).toList()
      ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

    for (final employee in activeEmployees) {
      final employeeTemplates = templates
          .where(
            (template) =>
                template.employeeId == employee.id &&
                template.numeroSemaine == numeroSemaine,
          )
          .toList();

      sheet.appendRow([
        TextCellValue(employee.nomComplet),
        ..._jours.map(
          (jour) => TextCellValue(_daySummary(employeeTemplates, jour)),
        ),
        IntCellValue(
          employeeTemplates.fold<int>(
            0,
            (total, template) => total + template.minutesEstimees,
          ),
        ),
      ]);
    }

    _formatSheet(
      sheet,
      columnWidths: const [24, 26, 26, 26, 26, 26, 15],
    );
    excel.save(
      fileName: 'planning-equipe-semaine-$numeroSemaine.xlsx',
    );
  }

  void employee({
    required Employee employee,
    required List<PlanningTemplate> templates,
  }) {
    final excel = Excel.createExcel();
    final employeeTemplates = templates
        .where((template) => template.employeeId == employee.id)
        .toList();

    for (var week = 1; week <= 4; week++) {
      final sheetName = 'Semaine $week';
      final sheet = excel[sheetName];
      final weekTemplates = employeeTemplates
          .where((template) => template.numeroSemaine == week)
          .toList();

      sheet.appendRow([
        TextCellValue('Jour'),
        TextCellValue('Matin'),
        TextCellValue('Après-midi'),
        TextCellValue('Total minutes'),
      ]);

      for (final day in _jours) {
        final dayTemplates = weekTemplates
            .where((template) => template.jour == day)
            .toList();
        final morning = dayTemplates
            .where((template) => template.periode == PeriodeType.am)
            .toList()
          ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
        final afternoon = dayTemplates
            .where((template) => template.periode == PeriodeType.pm)
            .toList()
          ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));

        sheet.appendRow([
          TextCellValue(day),
          TextCellValue(_taskDetails(morning)),
          TextCellValue(_taskDetails(afternoon)),
          IntCellValue(
            dayTemplates.fold<int>(
              0,
              (total, template) => total + template.minutesEstimees,
            ),
          ),
        ]);
      }

      _formatSheet(
        sheet,
        columnWidths: const [18, 42, 42, 15],
      );
    }

    excel.delete('Sheet1');
    excel.setDefaultSheet('Semaine 1');
    excel.save(
      fileName: 'planning-${_safeName(employee.nomComplet)}.xlsx',
    );
  }

  void _formatSheet(
    Sheet sheet, {
    required List<double> columnWidths,
  }) {
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#3732C9'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );

    for (var column = 0; column < columnWidths.length; column++) {
      sheet.setColumnWidth(column, columnWidths[column]);
    }
    for (var row = 0; row < sheet.maxRows; row++) {
      for (var column = 0; column < sheet.maxColumns; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: row,
          ),
        );
        cell.cellStyle = row == 0 ? headerStyle : bodyStyle;
      }
    }
  }

  String _daySummary(
    List<PlanningTemplate> templates,
    String day,
  ) {
    final morning = templates
        .where(
          (template) =>
              template.jour == day && template.periode == PeriodeType.am,
        )
        .toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
    final afternoon = templates
        .where(
          (template) =>
              template.jour == day && template.periode == PeriodeType.pm,
        )
        .toList()
      ..sort((a, b) => a.numeroTache.compareTo(b.numeroTache));
    final lines = <String>[];
    if (morning.isNotEmpty) {
      lines.add('AM : ${morning.map(_apartmentNumber).join(', ')}');
    }
    if (afternoon.isNotEmpty) {
      lines.add('PM : ${afternoon.map(_apartmentNumber).join(', ')}');
    }
    return lines.isEmpty ? '—' : lines.join('\n');
  }

  String _taskDetails(List<PlanningTemplate> templates) {
    if (templates.isEmpty) return '—';
    return templates
        .map(
          (template) =>
              '${template.numeroTache}. Appartement '
              '${_apartmentNumber(template)} '
              '(${template.minutesEstimees} min)',
        )
        .join('\n');
  }

  String _apartmentNumber(PlanningTemplate template) {
    return template.appartement?.numero ?? 'Non renseigné';
  }

  String _safeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
