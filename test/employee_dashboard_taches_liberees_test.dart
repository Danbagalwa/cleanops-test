import 'package:flutter_test/flutter_test.dart';
import 'package:cleanops/features/employee_dashboard/data/datasources/employee_dashboard_datasource.dart';

void main() {
  List<Map<String, dynamic>> taches() => [
        {'id': 'a', 'numero_tache': 1},
        {'id': 'b', 'numero_tache': 2},
        {'id': 'c', 'numero_tache': 3},
      ];

  List<Object?> ids(List<Map<String, dynamic>> l) =>
      l.map((t) => t['id']).toList();

  test('retire une tâche libérée à l\'équipe et garde les autres', () {
    final r = EmployeeDashboardDatasourceImpl.sansTachesLiberees(
        taches(), {'b'});

    expect(ids(r), ['a', 'c']);
  });

  test('retire plusieurs tâches libérées en conservant l\'ordre', () {
    final r = EmployeeDashboardDatasourceImpl.sansTachesLiberees(
        taches(), {'a', 'c'});

    expect(ids(r), ['b']);
  });

  test('sans tâche libérée, rien n\'est retiré', () {
    final r =
        EmployeeDashboardDatasourceImpl.sansTachesLiberees(taches(), {});

    expect(ids(r), ['a', 'b', 'c']);
  });

  test('une tâche libérée qui n\'est pas dans la liste est sans effet', () {
    final r = EmployeeDashboardDatasourceImpl.sansTachesLiberees(
        taches(), {'inconnue'});

    expect(ids(r), ['a', 'b', 'c']);
  });

  test('toutes libérées : liste vide', () {
    final r = EmployeeDashboardDatasourceImpl.sansTachesLiberees(
        taches(), {'a', 'b', 'c'});

    expect(r, isEmpty);
  });
}
