// lib/services/team_service.dart
//
// Times ficam em UserData (mesmo formato do site) e são sincronizados com a
// conta: um time criado no celular aparece no site, e vice-versa.

import 'package:uuid/uuid.dart';
import '../models/team.dart';
import 'account_format.dart';
import 'team_share.dart';
import 'user_data.dart';

class TeamService {
  final _uuid = const Uuid();
  UserData get _data => UserData.instance;

  Future<List<Team>> getTeams() async =>
      _data.teams.map(AccountFormat.teamFromAccount).toList();

  Future<Team> createTeam(String name) async {
    final team = Team(id: _uuid.v4(), name: name, pokemons: []);
    _data.update({
      'teams': [..._data.teams, AccountFormat.teamToAccount(team)],
    });
    return team;
  }

  /// Time recebido de outra pessoa (código, link ou Showdown).
  Future<Team> importTeam(SharedTeam shared) async {
    final account = {
      'id': _uuid.v4(),
      'name': shared.name,
      'color': shared.color,
      'pokemon': [for (var i = 0; i < 6; i++) i < shared.pokemon.length ? shared.pokemon[i] : null],
    };
    _data.update({'teams': [..._data.teams, account]});
    return AccountFormat.teamFromAccount(account);
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
