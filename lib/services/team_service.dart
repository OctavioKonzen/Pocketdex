// lib/services/team_service.dart
//
// Times ficam em UserData (mesmo formato do site) e são sincronizados com a
// conta: um time criado no celular aparece no site, e vice-versa.

import 'package:uuid/uuid.dart';
import '../models/team.dart';
import 'account_format.dart';
import 'user_data.dart';

class TeamService {
  final _uuid = const Uuid();
  UserData get _data => UserData.instance;

  Future<List<Team>> getTeams() async =>
      _data.teams.map(AccountFormat.teamFromAccount).toList();

  Future<void> createTeam(String name) async {
    final team = Team(id: _uuid.v4(), name: name, pokemons: []);
    _data.update({
      'teams': [..._data.teams, AccountFormat.teamToAccount(team)],
    });
  }

  Future<void> updateTeam(Team updatedTeam) async {
    final teams = _data.teams;
    final index = teams.indexWhere((t) => t['id'] == updatedTeam.id);
    if (index == -1) return;
    teams[index] = AccountFormat.teamToAccount(updatedTeam, teams[index]);
    _data.update({'teams': teams});
  }

  Future<void> deleteTeam(String teamId) async {
    _data.update({
      'teams': _data.teams.where((t) => t['id'] != teamId).toList(),
    });
  }
}
